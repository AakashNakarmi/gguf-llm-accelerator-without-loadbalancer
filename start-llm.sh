#!/bin/bash

# Set default values with environment variable override
HOST=${HOST:-0.0.0.0}
PORT=${PORT:-8000}
MODEL=${MODEL:-phi-4-bf16.gguf}
MODEL_ALIAS=${MODEL_ALIAS:-Phi-4-30B}
N_GPU_LAYERS=${N_GPU_LAYERS:--1}
TENSOR_SPLIT=${TENSOR_SPLIT:-0.5,0.5}
OFFLOAD_KQV=${OFFLOAD_KQV:-true}
USE_MMAP=${USE_MMAP:-false}
USE_MLOCK=${USE_MLOCK:-true}
N_BATCH=${N_BATCH:-4096}
N_UBATCH=${N_UBATCH:-2048}
N_CTX=${N_CTX:-16384}
FLASH_ATTN=${FLASH_ATTN:-true}
N_THREADS=${N_THREADS:-56}
N_THREADS_BATCH=${N_THREADS_BATCH:-64}
SPLIT_MODE=${SPLIT_MODE:-1}
MAIN_GPU=${MAIN_GPU:-0}
MUL_MAT_Q=${MUL_MAT_Q:-true}
CACHE=${CACHE:-true}
NUMA=${NUMA:-true}
LOGITS_ALL=${LOGITS_ALL:-false}
ROPE_FREQ_BASE=${ROPE_FREQ_BASE:-10000}
ROPE_FREQ_SCALE=${ROPE_FREQ_SCALE:-1.0}
YARN_EXT_FACTOR=${YARN_EXT_FACTOR:--1.0}
YARN_ATTN_FACTOR=${YARN_ATTN_FACTOR:-1.0}
LAST_N_TOKENS_SIZE=${LAST_N_TOKENS_SIZE:-128}
SEED=${SEED:--1}

# Convert TENSOR_SPLIT to JSON array format
IFS=',' read -ra TENSOR_ARRAY <<< "$TENSOR_SPLIT"
TENSOR_JSON="["
for i in "${!TENSOR_ARRAY[@]}"; do
    if [ $i -ne 0 ]; then
        TENSOR_JSON+=", "
    fi
    TENSOR_JSON+="${TENSOR_ARRAY[$i]}"
done
TENSOR_JSON+="]"

# Generate config.json
cat > config.json << EOF
{
    "host": "$HOST",
    "port": $PORT,
    "models": [
        {
            "model": "$MODEL",
            "model_alias": "$MODEL_ALIAS",                                                                                                                                         
            "n_gpu_layers": $N_GPU_LAYERS,                                                                                                                                         
            "tensor_split": $TENSOR_JSON,                                                                                                                                          
            "offload_kqv": $OFFLOAD_KQV,                                                                                                                                           
            "n_batch": $N_BATCH,                                                                                                                                                   
            "n_ubatch": $N_UBATCH,                                                                                                                                                 
            "n_ctx": $N_CTX,                                                                                                                                                       
            "flash_attn": $FLASH_ATTN,                                                                                                                                             
            "use_mmap": $USE_MMAP,                                                                                                                                                 
            "use_mlock": $USE_MLOCK,                                                                                                                                               
            "n_threads": $N_THREADS,                                                                                                                                               
            "n_threads_batch": $N_THREADS_BATCH,                                                                                                                                   
            "split_mode": $SPLIT_MODE,                                                                                                                                             
            "main_gpu": $MAIN_GPU,                                                                                                                                                 
            "mul_mat_q": $MUL_MAT_Q,                                                                                                                                               
            "cache": $CACHE,                                                                                                                                                       
            "numa": $NUMA,                                                                                                                                                         
            "logits_all": $LOGITS_ALL,                                                                                                                                             
            "rope_freq_base": $ROPE_FREQ_BASE,                                                                                                                                     
            "rope_freq_scale": $ROPE_FREQ_SCALE,                                                                                                                                   
            "yarn_ext_factor": $YARN_EXT_FACTOR,                                                                                                                                   
            "yarn_attn_factor": $YARN_ATTN_FACTOR,                                                                                                                                 
            "last_n_tokens_size": $LAST_N_TOKENS_SIZE,                                                                                                                             
            "seed": $SEED                                                                                                                                                          
        }                                                                                                                                                                          
    ]                                                                                                                                                                              
}                                                                                                                                                                                  
EOF                                                                                                                                                                                
                                                                                                                                                                                   
echo "#################### STARTING THE SERVER #####################"                                                                                                              
                                                                                                                                                                                   
if [[ "$RUN_APP" == "true" ]]; then                                                                                                                                                
    echo "#################### RUNNING APP #####################"                                                                                                                  
    python3 app.py                                                                                                                                                                 
else                                                                                                                                                                               
    echo "#################### RUNNING LLAMA SERVER #####################"                                                                                                         
    python3 -m llama_cpp.server --config_file config.json                                                                                                                          
fi    