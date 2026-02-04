#!/bin/bash

set -e

echo "Starting Multilogin in Docker (Based on Official Example)"
echo "============================================================="

# Check credentials
if [ -z "$ML_USERNAME" ] || [ -z "$ML_PASSWORD" ]; then
    echo "WARNING: ML_USERNAME or ML_PASSWORD not set"
    echo "   Set in .env file"
fi

# Find Multilogin install directory (case-sensitive path may vary)
ML_DIR=""
for dir in /opt/Multilogin/headless /opt/multilogin/headless /opt/multiloginapp/headless; do
    if [ -d "$dir" ]; then
        ML_DIR="$dir"
        break
    fi
done

if [ -z "$ML_DIR" ]; then
    echo "ERROR: Could not find Multilogin headless directory"
    echo "Contents of /opt:"
    ls -la /opt/
    find /opt -maxdepth 3 -type f -name "*.sh" 2>/dev/null
    exit 1
fi

echo "Multilogin found at: $ML_DIR"

# Clean up stale Xvfb lock files from previous runs
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

# Start X virtual display
echo "Starting Xvfb..."
Xvfb :99 -screen 0 1920x1080x24 > /var/log/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 3

if ! ps -p $XVFB_PID > /dev/null; then
    echo "Xvfb failed to start"
    cat /var/log/xvfb.log
    exit 1
fi
echo "Xvfb started (PID: $XVFB_PID)"

# Start window manager
echo "Starting Fluxbox..."
fluxbox > /var/log/fluxbox.log 2>&1 &
sleep 2
echo "Fluxbox started"

# Start VNC server (optional, for debugging)
echo "Starting VNC server on port 5900..."
x11vnc -display :99 -forever -nopw -quiet > /var/log/vnc.log 2>&1 &
echo "VNC server started"

# Launch Multilogin application
echo "Starting Multilogin application..."
cd "$ML_DIR"

# Login with credentials via cli.sh
if [ -n "$ML_USERNAME" ] && [ -n "$ML_PASSWORD" ]; then
    echo "Logging in with credentials..."
    bash ./cli.sh -login -u "$ML_USERNAME" -p "$ML_PASSWORD" > /var/log/multilogin-login.log 2>&1
    LOGIN_EXIT=$?
    if [ $LOGIN_EXIT -ne 0 ]; then
        echo "Login failed (exit code: $LOGIN_EXIT)"
        cat /var/log/multilogin-login.log
        echo "Continuing anyway - headless may still work..."
    else
        echo "Login successful"
    fi
else
    echo "Starting without auto-login (credentials not provided)"
fi

# Start headless service on internal port 35001 (binds to 127.0.0.1)
echo "Starting headless service on port 35001 (internal)..."
bash ./headless.sh -port 35001 > /var/log/multilogin.log 2>&1 &
MULTILOGIN_PID=$!

# Wait for internal API to be ready
echo "Waiting for Multilogin API to be ready..."
MAX_WAIT=120
WAIT_COUNT=0

while ! curl -s http://localhost:35001/api/v1/profile > /dev/null 2>&1; do
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "Multilogin API failed to start after ${MAX_WAIT}s"
        echo "Multilogin logs:"
        tail -50 /var/log/multilogin.log
        exit 1
    fi

    if ! ps -p $MULTILOGIN_PID > /dev/null; then
        echo "Multilogin process died!"
        echo "Last logs:"
        tail -50 /var/log/multilogin.log
        exit 1
    fi

    echo "Waiting... ($WAIT_COUNT/$MAX_WAIT)"
    sleep 3
    WAIT_COUNT=$((WAIT_COUNT + 3))
done

# Start socat to proxy 0.0.0.0:35000 -> 127.0.0.1:35001
# This makes the API accessible from outside the container
echo "Starting socat proxy (0.0.0.0:35000 -> localhost:35001)..."
socat TCP-LISTEN:35000,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:35001 &
SOCAT_PID=$!

echo "Multilogin API is ready at http://localhost:35000"
echo ""
echo "============================================================="
echo "Service Status:"
echo "  - Xvfb:       Running (PID: $XVFB_PID)"
echo "  - Multilogin: Running (PID: $MULTILOGIN_PID)"
echo "  - Socat:      Running (PID: $SOCAT_PID)"
echo "  - API:        http://localhost:35000 (proxied)"
echo "  - VNC:        vnc://localhost:5900"
echo "============================================================="

# Watchdog loop - keep container running and restart crashed services
while true; do
    if ! ps -p $XVFB_PID > /dev/null; then
        echo "Xvfb crashed! Restarting..."
        Xvfb :99 -screen 0 1920x1080x24 &
        XVFB_PID=$!
        sleep 3
    fi

    if ! ps -p $MULTILOGIN_PID > /dev/null; then
        echo "Multilogin crashed! Restarting..."
        cd "$ML_DIR"
        bash ./headless.sh -port 35001 > /var/log/multilogin.log 2>&1 &
        MULTILOGIN_PID=$!
    fi

    if ! ps -p $SOCAT_PID > /dev/null; then
        echo "Socat proxy crashed! Restarting..."
        socat TCP-LISTEN:35000,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:35001 &
        SOCAT_PID=$!
    fi

    sleep 10
done
