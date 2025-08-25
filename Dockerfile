FROM ubuntu:22.04 AS builder

# Install build deps
RUN apt-get update && apt-get install -y \
    git build-essential cmake python3 python3-venv python3-dev curl \
    libvulkan1 ocl-icd-libopencl1 mesa-vulkan-drivers \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Clone ROCm-enabled piper (this repo itself)
RUN git clone https://github.com/Chreece/wyoming-piper-rocm.git
WORKDIR /opt/wyoming-piper-rocm

# Build piper binary
RUN mkdir build && cd build && cmake .. && make -j$(nproc)

# ---- Final image ----
FROM ubuntu:22.04

# Install runtime deps
RUN apt-get update && apt-get install -y \
    python3 python3-venv python3-dev curl \
    libvulkan1 ocl-icd-libopencl1 mesa-vulkan-drivers \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Clone Wyoming Piper server
RUN git clone https://github.com/rhasspy/wyoming-piper.git
WORKDIR /opt/wyoming-piper

# Setup Python venv + install deps
RUN python3 -m venv venv \
 && venv/bin/pip install --upgrade pip \
 && venv/bin/pip install -r requirements.txt

# Copy ROCm-enabled piper binary from builder
COPY --from=builder /opt/wyoming-piper-rocm/build/piper /usr/local/bin/piper

# Expose port
EXPOSE 10200

# Default entrypoint
ENTRYPOINT ["venv/bin/python3", "-m", "wyoming_piper", \
    "--uri", "tcp://0.0.0.0:10200", \
    "--voice", "en_US-lessac-medium", \
    "--data-dir", "/data", \
    "--download-dir", "/data"]
