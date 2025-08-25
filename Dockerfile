FROM ubuntu:22.04 AS builder

# Install build deps
RUN apt-get update && apt-get install -y \
    git build-essential cmake python3 python3-venv python3-dev curl \
    libvulkan1 ocl-icd-libopencl1 mesa-vulkan-drivers \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Clone and build Piper (C++ TTS engine)
RUN git clone --recursive https://github.com/rhasspy/piper.git
WORKDIR /opt/piper
RUN mkdir build && cd build && cmake .. && make -j$(nproc)

# Clone Wyoming-Piper server (Python wrapper)
RUN git clone https://github.com/rhasspy/wyoming-piper.git /opt/wyoming-piper

# ---- Final image ----
FROM ubuntu:22.04

# Install runtime deps
RUN apt-get update && apt-get install -y \
    python3 python3-venv python3-dev curl \
    libvulkan1 ocl-icd-libopencl1 mesa-vulkan-drivers \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Copy Wyoming-Piper server
COPY --from=builder /opt/wyoming-piper /opt/wyoming-piper
WORKDIR /opt/wyoming-piper

# Setup Python venv + install Wyoming-Piper
RUN python3 -m venv venv \
 && venv/bin/pip install --upgrade pip \
 && venv/bin/pip install .

# Copy Piper binary (GPU-enabled)
COPY --from=builder /opt/piper/build/piper /usr/local/bin/piper

# Expose port
EXPOSE 10200

# Default entrypoint (voice configurable with env var)
ENV VOICE=en_US-lessac-medium
# Expose port
EXPOSE 10200

# Default entrypoint (voice configurable with env var)
ENV VOICE=en_US-lessac-medium
ENTRYPOINT ["sh", "-c", "venv/bin/python3 -m wyoming_piper \
    --uri tcp://0.0.0.0:10200 \
    --piper /usr/local/bin/piper \
    --voice ${VOICE} \
    --data-dir /data \
    --download-dir /data"]
