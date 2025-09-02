#!/bin/bash
# Activate the virtual environment
# python3 -m venv /app/venv
# cp -r /app/.venv/lib/python3.12/site-packages/* /app/venv/lib/python3.12/site-packages/
#rm -rf /app/venv/lib/python3.12/site-packages/pip-24.0*
# rm -rf /app/.venv

# source /app/venv/bin/activate
# Print confirmation of virtual environment activation
echo "##############################################################"
echo "Virtual environment activated."
echo "Installed packages:"
pip list

# echo "##############################################################"
# gcc --version

# cp /usr/local/cuda-12.5/compat/libcuda.so.1 /usr/local/lib/python3.10/dist-packages/llama_cpp/lib/

# echo "##############################################################"
# ls -lrt /usr/local/

# Run the application
# echo "Listing Important files:"
# find / -iname "libgomp.so.1"
# find / -iname "app.py"
# find / -iname "libcuda.so.1"

echo "#################### STARTING THE SERVER #####################"

if [[ "$RUN_APP" == "true" ]]; then
    echo "#################### RUNNING APP #####################"
    python3 app.py
else
    echo "#################### RUNNING LLAMA SERVER #####################"
    python3 -m llama_cpp.server --config_file config.py
fi
