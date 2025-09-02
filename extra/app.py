from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
from zoneinfo import ZoneInfo
from utils import create_prompt, get_gpu_memory_usage
from init_logger import get_logger
from init_model import start_pipeline, truncate_tokens, generation_args

import torch
import logging
import uvicorn

# Initialize FastAPI app
app = FastAPI()
logger = get_logger()

global pipe

class RequestBody(BaseModel):
    content: str

@app.post("/generate")
def generate_response(prompt: RequestBody):
    logging.info("Request Received to LLM")
    try:
        ### LIMITING THE TOKENS TO 3000 ###
        content = prompt.content
        
        ### STRUCTURING THE PROMPT ###
        prompt = create_prompt(content)
        
        ###GENERATING OUTPUT FROM PIPELINE ###
        output = pipe(prompt, **generation_args)
        generated_text = output[0]["generated_text"]
        logging.info(f"generated_response: {generated_text}")
        
        timestamp = datetime.now(ZoneInfo("Asia/Qatar")).isoformat()
        response = {
            "status": "success",
            "timestamp": timestamp,
            "generated_response": generated_text
        }

        return response

    except Exception as e:
        logging.info(f"Error generating response: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error generating response: {str(e)}")

    finally:
        logging.info("Clearing GPU Memory Load")
        torch.cuda.empty_cache()
        
if __name__ == "__main__":
    logging.info("########## Starting Server for LLM ##########")
    pipe = start_pipeline()
    uvicorn.run(app, host="0.0.0.0", port=8000)
