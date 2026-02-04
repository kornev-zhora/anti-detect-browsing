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
    socat \
    && rm -rf /var/lib/apt/lists/*

# Create Multilogin directory
RUN mkdir -p /opt/multilogin/

# Download and install Multilogin
RUN curl --location --fail --output /tmp/multilogin.zip \
      "https://cdn-download.multiloginapp.com/multilogin/6.3.6/multilogin-6.3.6-1-linux_x86_64.zip" && \
    cd /tmp && unzip multilogin.zip && \
    dpkg -i /tmp/*.deb || apt-get install -f -y && \
    rm -rf /tmp/multilogin* /tmp/*.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Find where Multilogin was installed and make scripts executable
RUN find /opt -name "cli.sh" -o -name "headless.sh" | head -5 && \
    chmod +x /opt/Multilogin/headless/cli.sh /opt/Multilogin/headless/headless.sh 2>/dev/null || \
    chmod +x /opt/multilogin/headless/cli.sh /opt/multilogin/headless/headless.sh 2>/dev/null || \
    echo "Scripts will be located at runtime"

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
  CMD curl -f http://localhost:35001/api/v1/profile || exit 1

# Start script
CMD ["/opt/multilogin/run.sh"]