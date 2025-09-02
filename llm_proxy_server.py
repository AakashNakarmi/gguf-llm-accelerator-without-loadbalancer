from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import httpx
import json
import re
import ast
import logging
import time
from typing import Dict, List, Any, Optional

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LLM Proxy Server", version="1.0.0")

class Message(BaseModel):
    role: str
    content: str

class LLMRequest(BaseModel):
    model: str
    messages: List[Message]
    temperature: float = 0.0
    max_tokens: int = 1000

class Choice(BaseModel):
    index: int
    message: Dict[str, str]
    finish_reason: str

class LLMResponse(BaseModel):
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[Choice]
    usage: Optional[Dict[str, int]] = None

# Configuration
LLM_API_URL = "http://localhost:8090/v1/chat/completions"  # Local LLM API
REQUEST_TIMEOUT = 420  # 7 minutes

def clean_and_parse_json_response(raw_response: str, request_id: str = "unknown") -> Optional[Dict[str, Any]]:
    """
    Clean and parse the LLM response to extract valid JSON
    """
    logger.info(f"Request {request_id}: Raw LLM response: {raw_response}")

    try:
        # First, try to extract content after the final assistant message marker
        final_pattern = r'<\|start\|>assistant<\|channel\|>final<\|message\|>(.*?)(?:<\||$)'
        final_match = re.search(final_pattern, raw_response, re.DOTALL)

        if final_match:
            cleaned_json = final_match.group(1).strip()
            logger.info(f"Request {request_id}: Extracted final response: {cleaned_json}")
        else:
            # Fallback: remove all the channel/message tags and extract JSON
            cleaned_json = re.sub(r'<\|[^|]*\|>[^{]*', '', raw_response)
            # Remove everything before the first { and after the last }
            json_match = re.search(r'\{.*\}', cleaned_json, re.DOTALL)
            if json_match:
                cleaned_json = json_match.group(0)
            else:
                # Last resort: remove markdown code blocks
                cleaned_json = re.sub(r"```json\s*([\s\S]*?)\s*```", r"\1", raw_response).strip()

        # Clean up any remaining artifacts
        cleaned_json = re.sub(r'Return that\..*$', '', cleaned_json, flags=re.DOTALL).strip()
        cleaned_json = re.sub(r'<\|.*?\|>', '', cleaned_json).strip()

        # Convert single quotes to double quotes for valid JSON
        # Replace single quotes with double quotes, but be careful with quotes inside strings
        cleaned_json = re.sub(r"'([^']*)':", r'"\1":', cleaned_json)  # Replace keys
        cleaned_json = re.sub(r":\s*'([^']*)'", r': "\1"', cleaned_json)  # Replace string values
        cleaned_json = cleaned_json.replace("'", '"')  # Replace any remaining single quotes
        
        # Handle null values (they should remain as null, not "null")
        cleaned_json = re.sub(r':\s*"null"', ': null', cleaned_json)
        
        logger.info(f"Request {request_id}: Cleaned JSON after quote conversion: {cleaned_json}")
        
        # Try to parse the JSON
        try:
            parsed_json = json.loads(cleaned_json)
            logger.info(f"Request {request_id}: Successfully parsed JSON")
            return parsed_json
            
        except json.JSONDecodeError as json_error:
            logger.error(f"Request {request_id}: JSON still invalid after cleaning: {str(json_error)}")
            logger.error(f"Request {request_id}: Problematic JSON: {cleaned_json}")
            
            # Last resort: try to fix common JSON issues using ast.literal_eval
            try:
                # First restore original for ast parsing
                original_cleaned = re.sub(r'Return that\..*$', '', raw_response, flags=re.DOTALL).strip()
                original_cleaned = re.sub(r'<\|.*?\|>', '', original_cleaned).strip()
                
                # Extract just the dict part
                dict_match = re.search(r'\{.*\}', original_cleaned, re.DOTALL)
                if dict_match:
                    dict_str = dict_match.group(0)
                    parsed_json = ast.literal_eval(dict_str)
                    logger.info(f"Request {request_id}: Successfully parsed using ast.literal_eval")
                    return parsed_json
                else:
                    logger.error(f"Request {request_id}: No dict pattern found in response")
                    return None
                    
            except (ValueError, SyntaxError) as ast_error:
                logger.error(f"Request {request_id}: ast.literal_eval also failed: {str(ast_error)}")
                return None
                
    except Exception as e:
        logger.error(f"Request {request_id}: Unexpected error in JSON parsing: {str(e)}")
        return None

@app.post("/v1/chat/completions", response_model=LLMResponse)
async def proxy_llm_request(request: LLMRequest):
    """
    Proxy endpoint that forwards requests to the local LLM API and returns parsed JSON
    """
    request_id = id(request)  # Simple request ID for logging
    logger.info(f"Request {request_id}: Received LLM request")
    
    try:
        # Convert request to dict for forwarding
        llm_payload = request.dict()
        
        logger.info(f"Request {request_id}: Forwarding to LLM API at {LLM_API_URL}")
        
        # Forward request to local LLM API
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            response = await client.post(
                LLM_API_URL,
                json=llm_payload,
                headers={"Content-Type": "application/json"}
            )
            
            logger.info(f"Request {request_id}: Got response with status {response.status_code}")
            
            if response.status_code != 200:
                error_message = f"LLM API returned status {response.status_code}: {response.text}"
                logger.error(f"Request {request_id}: {error_message}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=error_message
                )
            
            # Parse the LLM API response
            llm_response = response.json()
            raw_content = llm_response['choices'][0]['message']['content']
            
            logger.info(f"Request {request_id}: Extracted raw content from LLM response")
            
            # Clean and parse the response
            parsed_data = clean_and_parse_json_response(raw_content, str(request_id))
            
            if parsed_data and isinstance(parsed_data, dict):
                logger.info(f"Request {request_id}: Successfully parsed response")
                
                # Return OpenAI-compatible format with parsed JSON as content
                return LLMResponse(
                    id=llm_response.get("id", f"chatcmpl-{request_id}"),
                    created=llm_response.get("created", int(time.time())),
                    model=request.model,
                    choices=[
                        Choice(
                            index=0,
                            message={
                                "role": "assistant",
                                "content": json.dumps(parsed_data)  # Return parsed JSON as string
                            },
                            finish_reason=llm_response.get("choices", [{}])[0].get("finish_reason", "stop")
                        )
                    ],
                    usage=llm_response.get("usage")
                )
            else:
                logger.error(f"Request {request_id}: Failed to parse response into valid JSON dict")
                raise HTTPException(
                    status_code=500,
                    detail={
                        "error": "Failed to parse LLM response into valid JSON",
                        "raw_response": raw_content
                    }
                )
                
    except httpx.TimeoutException:
        error_message = f"Request {request_id}: Timeout while calling LLM API"
        logger.error(error_message)
        raise HTTPException(status_code=408, detail="LLM API request timed out")
        
    except httpx.RequestError as e:
        error_message = f"Request {request_id}: HTTP error: {str(e)}"
        logger.error(error_message)
        raise HTTPException(status_code=502, detail=f"Failed to connect to LLM API: {str(e)}")
        
    except Exception as e:
        error_message = f"Request {request_id}: Unexpected error: {str(e)}"
        logger.error(error_message)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "LLM Proxy Server"}

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "service": "LLM Proxy Server",
        "version": "1.0.0",
        "description": "Proxy server that forwards requests to local LLM API and returns parsed JSON responses",
        "endpoints": {
            "POST /v1/chat/completions": "Main proxy endpoint",
            "GET /health": "Health check",
            "GET /docs": "API documentation"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)