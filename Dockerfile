ARG CUDA_IMAGE="12.8.0-cudnn-devel-ubuntu22.04"

# ============ BUILDER STAGE ============
FROM nvidia/cuda:${CUDA_IMAGE} as builder

ENV DEBIAN_FRONTEND=noninteractive
ENV APT_LISTCHANGES_FRONTEND=none

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y apt-utils && \
    apt-get install -y --only-upgrade gnupg gnupg2 gnupg-utils gpgv dirmngr gpg-agent gpgconf gpgsm && \
    apt-get install -y git build-essential \
    python3 python3-pip python3-venv gcc wget \
    ocl-icd-opencl-dev opencl-headers clinfo \
    libclblast-dev libopenblas-dev \
    cmake curl && \
    dpkg-reconfigure -f noninteractive apt-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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

RUN python3 -m pip install --disable-pip-version-check --upgrade pip==26.0 setuptools>=78.1.1 cmake wheel>=0.46.2 && \
    pip install llama-cpp-python llama-cpp-python[server] fastapi uvicorn httpx starlette>=0.49.1

# ============ RUNTIME STAGE ============
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV APT_LISTCHANGES_FRONTEND=none

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y apt-utils && \
    apt-get install -y --only-upgrade gnupg gnupg2 gnupg-utils gpgv dirmngr gpg-agent gpgconf gpgsm && \
    apt-get install -y python3 python3-pip curl supervisor && \
    dpkg-reconfigure -f noninteractive apt-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the environment variable for CUDA toolkit
ENV CUDAToolkit_ROOT=/usr/local/cuda

# Set PATH for CUDA
ENV PATH="${CUDAToolkit_ROOT}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDAToolkit_ROOT}/lib64:${CUDAToolkit_ROOT}/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64"

# Copy venv and built packages from builder
COPY --from=builder /app/venv /app/venv

ENV PATH="/app/venv/bin:$PATH"

# Remove Python 3.8 related CUDA-GDB binary to avoid conflicts
RUN rm -f /usr/local/cuda*/bin/cuda-gdb-python3.8*

# Remove the vulnerable Nsight Compute plugin entirely
RUN rm -rf /opt/nvidia/nsight-compute/*/host/target-linux-x64/plugins/efa_metrics/ || true

WORKDIR /app

COPY app.py /app/
COPY config.json /app/
COPY start-llm.sh /app/
COPY requirements.txt /app/
COPY Dockerfile /app/

RUN chmod +x /app/start-llm.sh

# Expose ports
EXPOSE 8000

# Use supervisor to manage multiple processes
# CMD ["/usr/bin/supervisord", "-c", "/app/supervisord.conf"]
CMD ["/app/start-llm.sh"]