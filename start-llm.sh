#!/bin/bash

echo "##############################################################"
echo "Virtual environment activated."
echo "Installed packages:"
source venv/bin/activate
pip list
# python3 -m pip install -r requirements.txt

echo "#################### STARTING SERVICES #####################"

if [[ "$RUN_APP" == "true" ]]; then
    echo "#################### RUNNING APP #####################"
    python3 app.py
elif [[ "$USE_SUPERVISOR" == "false" ]]; then
    echo "#################### RUNNING SERVICES MANUALLY #####################"
    
    # Start LLM server in background
    echo "Starting LLM Server on port 8090..."
    python3 -m llama_cpp.server --config_file config-gpt.json &
    LLM_PID=$!
    
    # Wait a bit for LLM server to start
    sleep 60
    echo "LLM Server started with PID: $LLM_PID"
    
    # Start proxy server in background
    echo "Starting Proxy Server on port 8000..."
    python3 llm_proxy_server.py &
    PROXY_PID=$!
    
    echo "Proxy Server started with PID: $PROXY_PID"
    
    # Function to cleanup processes on exit
    cleanup() {
        echo "Stopping services..."
        kill $LLM_PID $PROXY_PID 2>/dev/null
        wait
        echo "Services stopped."
        exit 0
    }
    
    # Trap signals to cleanup
    trap cleanup SIGTERM SIGINT
    
    # Wait for both processes
    wait $LLM_PID $PROXY_PID
else
    echo "#################### USING SUPERVISOR (DEFAULT) #####################"
    echo "Services will be managed by supervisord"
    # exec /usr/bin/supervisord -c supervisord.conf
    exec /usr/bin/supervisord -c /app/supervisord.conf
fi