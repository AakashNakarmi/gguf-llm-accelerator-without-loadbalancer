ARG CUDA_IMAGE="13.1.1-cudnn-devel-ubuntu24.04"
FROM nvidia/cuda:${CUDA_IMAGE}

ARG PYTHON_VERSION=3.12.6

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV TZ=UTC

# Pre-configure tzdata to prevent interactive prompts
RUN ln -snf /usr/share/zoneinfo/UTC /etc/localtime && echo UTC > /etc/timezone

# Install Python ${PYTHON_VERSION} (pinned, from source)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg \
    build-essential make \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libffi-dev liblzma-dev tk-dev uuid-dev xz-utils \
    git gcc \
    ocl-icd-opencl-dev opencl-headers clinfo \
    libclblast-dev libopenblas-dev \
    cmake supervisor vim \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    curl -fsSL "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" -o /tmp/Python.tgz; \
    mkdir -p /tmp/python-src; \
    tar -xzf /tmp/Python.tgz -C /tmp/python-src --strip-components=1; \
    cd /tmp/python-src; \
    ./configure --prefix=/usr/local --with-ensurepip=install; \
    make -j"$(nproc)"; \
    make altinstall; \
    cd /; \
    rm -rf /tmp/python-src /tmp/Python.tgz; \
    ln -sf /usr/local/bin/python3.12 /usr/local/bin/python3; \
    ln -sf /usr/local/bin/python3.12 /usr/local/bin/python; \
    /usr/local/bin/python3.12 -m pip --no-cache-dir install --upgrade pip

RUN update-alternatives --install /usr/bin/python python /usr/local/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.12 1

RUN mkdir -p /etc/OpenCL/vendors && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

# Remove the vulnerable Nsight Compute plugin entirely
RUN rm -rf /opt/nvidia/nsight-compute/*/host/target-linux-x64/plugins/efa_metrics/ || true
ENV CUDAToolkit_ROOT=/usr/local/cuda

# Set PATH for CUDA
ENV PATH="${CUDAToolkit_ROOT}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDAToolkit_ROOT}/lib64:${CUDAToolkit_ROOT}/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64"

# setting build related env vars
ENV CUDA_DOCKER_ARCH=all
ENV GGML_CUDA=1

# Create venv and install build dependencies
RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

RUN python -m pip install --upgrade pip cmake wheel==0.46.2 setuptools==78.1.1

# Print Dependency Information Table
RUN bash -c ' \
    PYTHON_VERSION=$(python --version 2>&1 | awk "{print \$2}") && \
    PIP_VERSION=$(pip --version 2>&1 | awk "{print \$2}") && \
    SETUPTOOLS_VERSION=$(pip show setuptools 2>/dev/null | grep Version | awk "{print \$2}") && \
    WHEEL_VERSION=$(pip show wheel 2>/dev/null | grep Version | awk "{print \$2}") && \
    echo "=====================================" && \
    echo "| Dependency    | Fixed Version    |" && \
    echo "=====================================" && \
    echo "| Python        | ${PYTHON_VERSION}           |" && \
    echo "| pip           | ${PIP_VERSION}           |" && \
    echo "| setuptools    | ${SETUPTOOLS_VERSION}           |" && \
    echo "| wheel         | ${WHEEL_VERSION}           |" && \
    echo "====================================="'

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