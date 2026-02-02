FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg \
    ca-certificates \
    xvfb \
    x11vnc \
    fluxbox \
    dbus-x11 \
    fonts-liberation \
    libnss3 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libgbm1 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Create multilogin directory
RUN mkdir -p /opt/multilogin

# ⚠️ NOTE: You must manually download multilogin.deb
# This is a placeholder - replace with actual download
# Visit https://multilogin.com/download for latest version
COPY multilogin.deb /tmp/multilogin.deb

# Install Multilogin
RUN dpkg -i /tmp/multilogin.deb || apt-get install -f -y \
    && rm /tmp/multilogin.deb

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose API port
EXPOSE 35000
EXPOSE 5900

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:35000/api/v1/profile || exit 1

# Start script
CMD ["/start.sh"]