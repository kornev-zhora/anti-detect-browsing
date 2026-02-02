FROM ubuntu:22.04

# Timezone and locale
ARG TZ=Europe/Kiev
ARG DEBIAN_FRONTEND=noninteractive
ENV LANG="C.UTF-8"
ENV TZ=${TZ}

# Install base dependencies
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    unzip \
    libgles2 \
    libegl1 \
    xvfb \
    libgl1 \
    libglib2.0-0 \
    zip \
    --no-install-recommends

# Add Google Chrome repository
RUN curl -sSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

# Install Chrome and fonts
RUN apt-get update && apt-get install -y \
    fontconfig \
    fonts-ipafont-gothic \
    fonts-kacst \
    fonts-noto \
    fonts-symbola \
    fonts-thai-tlwg \
    fonts-wqy-zenhei \
    fonts-freefont-ttf \
    connect-proxy \
    dnsutils \
    iproute2 \
    iptables \
    iputils-ping \
    net-tools \
    openvpn \
    procps \
    socat \
    ssh \
    sshpass \
    sudo \
    tcpdump \
    telnet \
    traceroute \
    tzdata \
    vim-nox \
    --no-install-recommends

# Install Google Chrome
RUN curl -o /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt install -y /tmp/chrome.deb && \
    rm /tmp/chrome.deb

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Create octo user with sudo privileges
RUN groupadd -r octo && \
    useradd -r -g octo -s /bin/bash -m -G audio,video,sudo octo && \
    echo 'octo:octo' | chpasswd && \
    mkdir -p /etc/sudoers.d && \
    echo 'octo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/octo && \
    chmod 0440 /etc/sudoers.d/octo

# Create browser directory
RUN mkdir -p /home/octo/browser && \
    chown -R octo:octo /home/octo

# Switch to octo user
USER octo
WORKDIR /home/octo

# Download and install Octo Browser
RUN curl -o /home/octo/browser/octo-browser.tar.gz \
    https://binaries.octobrowser.net/releases/installer/OctoBrowser.linux.tar.gz && \
    tar -xzf /home/octo/browser/octo-browser.tar.gz -C /home/octo/browser && \
    rm /home/octo/browser/octo-browser.tar.gz

# Make AppImage executable
RUN chmod +x /home/octo/browser/OctoBrowser.AppImage

# Expose API port
EXPOSE 58888

# Set environment variables
ENV DISPLAY=:1
ENV OCTO_HEADLESS=1

# Copy startup script
COPY --chown=octo:octo start.sh /home/octo/start.sh
RUN chmod +x /home/octo/start.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:58888/api/v1/health || exit 1

# Start script
CMD ["/home/octo/start.sh"]