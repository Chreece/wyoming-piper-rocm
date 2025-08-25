FROM ubuntu:22.04

# Install essentials
RUN apt-get update && apt-get install -y \
    curl \
    libvulkan1 \
    ocl-icd-libopencl1 \
    mesa-vulkan-drivers \
    && rm -rf /var/lib/apt/lists/*

# Copy or clone the wyoming-piper code
WORKDIR /opt/wyoming-piper
COPY . /opt/wyoming-piper

# Install Python dependencies
RUN apt-get update && apt-get install -y python3 python3-venv python3-dev && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv venv
RUN venv/bin/pip install --upgrade pip
RUN venv/bin/pip install .

# Download Piper binary (adapt URL for GPU-enabled build if available)
RUN curl -L -s "https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_amd64.tar.gz" \
    | tar -zxvf - -C /usr/share

# Export ROS/Vulkan variables if needed
ENV VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json

# Expose port
EXPOSE 10200

# Set entrypoint
ENTRYPOINT ["venv/bin/python3", "-m", "wyoming_piper", "--voice", "en_US-lessac-medium", "--uri", "tcp://0.0.0.0:10200", "--data-dir", "/data", "--download-dir", "/data"]
