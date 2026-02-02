# Anti-Detect Browser Test - Multilogin (Unofficial)
# Based on: https://multilogin.com/help/en_US/multilogin-in-docker
FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99

# Basic dependencies from Multilogin example
RUN apt-get update && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libcurl4 \
    libdbus-1-3 \
    libdrm2 \
    libexpat1 \
    libgbm1 \
    libglib2.0-0 \
    libgtk-4-1 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libu2f-udev \
    libvulkan1 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    wget \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Dependencies for Multilogin installation and X server
RUN apt-get update && apt-get install -y \
    openjdk-18-jre-headless \
    curl \
    unzip \
    openssh-client \
    xvfb \
    x11vnc \
    fluxbox \
    && rm -rf /var/lib/apt/lists/*

# Create Multilogin directory
RUN mkdir -p /opt/multilogin/

# Download and install Multilogin
# Version: 6.3.6 (update version number if needed)
ARG ML_VERSION=6.3.6
RUN cd /opt/multilogin/ && \
    curl --location --fail --output multilogin.zip \
    "https://cdn-download.multiloginapp.com/multilogin/${ML_VERSION}/multilogin-${ML_VERSION}-1-linux_x86_64.zip" && \
    unzip multilogin.zip && \
    chmod +x multiloginapp-linux-x64-client && \
    rm multilogin.zip && \
    apt-get update && \
    apt-get install -y ./multilogin.deb && \
    rm multilogin.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Multilogin credentials (will be overridden by .env)
ENV ML_USERNAME=""
ENV ML_PASSWORD=""

# Copy startup script
COPY ./run.sh /opt/multilogin/run.sh
RUN chmod +x /opt/multilogin/run.sh

# Expose API and VNC ports
EXPOSE 35000
EXPOSE 5900

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:35000/api/v1/profile || exit 1

# Start script
CMD ["/opt/multilogin/run.sh"]