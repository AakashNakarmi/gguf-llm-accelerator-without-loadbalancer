ARG CUDA_IMAGE="13.0.0-cudnn-devel-ubuntu24.04"
FROM nvidia/cuda:${CUDA_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm

RUN apt-get update && apt-get install -y apt-utils \
    && apt-get upgrade -y python3 \
    && apt-get install -y git build-essential \
    python3.12=3.12.6* python3-pip python3.12-venv gcc wget \
    ocl-icd-opencl-dev opencl-headers clinfo \
    libclblast-dev libopenblas-dev \
    cmake curl gnupg supervisor vim \
    && mkdir -p /etc/OpenCL/vendors && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

# Remove Python 3.8 related CUDA-GDB binary to avoid conflicts
RUN rm -f /usr/local/cuda*/bin/cuda-gdb-python3.8*

# Remove the vulnerable Nsight Compute plugin entirely
RUN rm -rf /opt/nvidia/nsight-compute/*/host/target-linux-x64/plugins/efa_metrics/ || true


# Set the environment variable for CUDA toolkit
ENV CUDAToolkit_ROOT=/usr/local/cuda

# Set PATH for CUDA
ENV PATH="${CUDAToolkit_ROOT}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDAToolkit_ROOT}/lib64:${CUDAToolkit_ROOT}/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64"

# setting build related env vars
ENV CUDA_DOCKER_ARCH=all
ENV GGML_CUDA=1

# Create venv and install build dependencies
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

RUN python3 -m pip install --upgrade "pip==24.2" cmake wheel==0.46.2 setuptools==78.1.1

# Install llama-cpp-python (build with cuda)
# RUN CMAKE_ARGS="-DGGML_CUDA=on" pip install llama-cpp-python
RUN CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=86" pip install llama-cpp-python
# RUN pip install llama-cpp-python
RUN pip install llama-cpp-python[server]

# Install proxy server dependencies
# RUN pip install fastapi uvicorn httpx

# Copy and install requirements
COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt

WORKDIR /app

COPY app.py /app/
COPY config.json /app/
COPY phi-4-bf16.gguf /app/
COPY start-llm.sh /app/
COPY requirements.txt /app/
COPY Dockerfile /app/
# COPY supervisord.conf /app/


# Make the script executable
RUN chmod +x /app/start-llm.sh

# Expose ports
EXPOSE 8000

# Use supervisor to manage multiple processes
# CMD ["/usr/bin/supervisord", "-c", "/app/supervisord.conf"]
                                                                                                                   
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/app/start-llm.sh"]