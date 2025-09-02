from transformers import AutoModelForCausalLM, AutoTokenizer, pipeline
from init_logger import get_logger
import logging
import torch

model_id="microsoft/Phi-3-mini-4k-instruct-gguf"
file_name="Phi-3-mini-4k-instruct-q4.gguf"

logger = get_logger()

generation_args = {
    "max_new_tokens": 200,
    "return_full_text": False,
    "temperature": 0.0,
    "do_sample": False,
}

logging.info("Setting Tokenizer")
tokenizer=AutoTokenizer.from_pretrained(model_id, gguf_file=file_name)
logging.info("Setting Tokenizer Completed")

def start_pipeline():
    """
    Start your Transformers Pipeline.
    
    Returns:
    hugging face pipeline that will be used for inferencing purpose
    """
    
    model = AutoModelForCausalLM.from_pretrained(
        model_id,
        device_map= "auto",
        torch_dtype= torch.float16,
        trust_remote_code=False,
        gguf_file=file_name
    )
    
    pipe = pipeline(
        "text-generation",
        model=model,
        tokenizer=tokenizer,
    )
    
    dtype = next(model.parameters()).dtype
    logger.info(f"Torch_dtype : {dtype}")
    logger.info(f"Model : {model_id}")
    logger.info(f"Device map: {model.hf_device_map}")
    
    return pipe

def truncate_tokens(content: str, token_limit: int) -> str:
   """
   Truncates input text to specified token limit.
   
   Args:
       content (str): Input text to truncate
       token_limit (int): Maximum number of tokens to keep
       
   Returns:
       str: Truncated text 
   """
   tokenized_input = tokenizer(content, truncation=True, max_length=token_limit)
   truncated_input = tokenizer.decode(tokenized_input['input_ids'])
   logging.info("Tokenization Complete")
   
   return truncated_input
