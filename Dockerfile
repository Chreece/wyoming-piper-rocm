# -----------------------------
# Builder stage (compile Piper)
# -----------------------------
FROM ubuntu:22.04 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git build-essential cmake python3 python3-venv python3-dev curl \
    libvulkan1 ocl-icd-libopencl1 mesa-vulkan-drivers \
    libespeak-ng1 \
    && rm -rf /var/lib/apt/lists/*

# Clone Piper (with submodules)
WORKDIR /opt
RUN git clone --recursive https://github.com/rhasspy/piper.git

# Build Piper
WORKDIR /opt/piper
RUN mkdir -p build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && make -j$(nproc)

# Clone Wyoming-Piper server
RUN git clone https://github.com/rhasspy/wyoming-piper.git /opt/wyoming-piper

# -----------------------------
# Final image (runtime)
# -----------------------------
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    python3 python3-venv python3-dev curl \
    libvulkan1 ocl-icd-libopencl1 mesa-vulkan-drivers \
    libespeak-ng1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Copy Wyoming-Piper server
COPY --from=builder /opt/wyoming-piper /opt/wyoming-piper
WORKDIR /opt/wyoming-piper

# Create Python venv and install Wyoming-Piper
RUN python3 -m venv venv \
 && venv/bin/pip install --upgrade pip \
 && venv/bin/pip install .

# Copy Piper binary + shared libraries
COPY --from=builder /opt/piper/build/piper /usr/local/bin/piper
COPY --from=builder /opt/piper/build/lib/*.so* /usr/local/lib/piper/
ENV LD_LIBRARY_PATH=/usr/local/lib/piper:$LD_LIBRARY_PATH

# Optional: pre-download default voice
# RUN mkdir -p /data \
#  && curl -L -o /data/en_US-lessac-medium.onnx \
#       https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx \
#  && curl -L -o /data/en_US-lessac-medium.onnx.json \
#       https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json

# Expose Wyoming server port
EXPOSE 10200

# Default entrypoint
ENV VOICE=en_US-lessac-medium
ENTRYPOINT ["sh", "-c", "venv/bin/python3 -m wyoming_piper \
    --uri tcp://0.0.0.0:10200 \
    --piper /usr/local/bin/piper \
    --voice ${VOICE} \
    --update-voices \
    --data-dir /data \
    --download-dir /data \
    --debug"]
