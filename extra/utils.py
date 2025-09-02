import nvidia_smi

def create_prompt(truncated_input: str) -> list:
   """
   Creates a prompt list with system and user messages.
   
   Args:
       truncated_input (str): The truncated user input text
       
   Returns:
       list: List of dictionaries containing system and user messages
   """
   
   
   prompt = [
       {"role": "system", "content": "You are a helpful AI assistant."},
       {"role": "user", "content": truncated_input}
   ]
   
   return prompt

def get_gpu_memory_usage():
    """Get the current GPU memory usage in MB."""
    handle = nvidia_smi.nvmlDeviceGetHandleByIndex(0)  # Assuming first GPU
    info = nvidia_smi.nvmlDeviceGetMemoryInfo(handle)
    return {
        'used_mb': info.used / 1024 / 1024,  # Convert bytes to MB
        'total_mb': info.total / 1024 / 1024,
        'free_mb': info.free / 1024 / 1024
    }

