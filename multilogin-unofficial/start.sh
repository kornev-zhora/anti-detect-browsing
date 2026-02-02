#!/bin/bash

set -e

echo "🚀 Starting Multilogin in Docker (Unofficial Setup)"
echo "=================================================="

# Start X virtual display
echo "📺 Starting Xvfb..."
Xvfb :99 -screen 0 1920x1080x24 > /var/log/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 3

if ! ps -p $XVFB_PID > /dev/null; then
    echo "❌ Xvfb failed to start"
    cat /var/log/xvfb.log
    exit 1
fi
echo "✅ Xvfb started (PID: $XVFB_PID)"

# Start window manager
echo "🪟 Starting Fluxbox..."
fluxbox > /var/log/fluxbox.log 2>&1 &
sleep 2
echo "✅ Fluxbox started"

# Start VNC server (optional, for debugging)
echo "🖥️  Starting VNC server on port 5900..."
x11vnc -display :99 -forever -nopw -quiet > /var/log/vnc.log 2>&1 &
echo "✅ VNC server started (connect with VNC client to localhost:5900)"

# Start Multilogin
echo "🌐 Starting Multilogin application..."
/opt/multilogin/multilogin > /var/log/multilogin.log 2>&1 &
MULTILOGIN_PID=$!

# Wait for API to be ready
echo "⏳ Waiting for Multilogin API to be ready..."
MAX_WAIT=60
WAIT_COUNT=0

while ! curl -s http://localhost:35000/api/v1/profile > /dev/null 2>&1; do
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "❌ Multilogin API failed to start after ${MAX_WAIT}s"
        echo "📋 Multilogin logs:"
        cat /var/log/multilogin.log
        exit 1
    fi

    echo "⏳ Waiting... ($WAIT_COUNT/$MAX_WAIT)"
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

echo "✅ Multilogin API is ready at http://localhost:35000"
echo ""
echo "=================================================="
echo "📊 Service Status:"
echo "  - Xvfb:       Running (PID: $XVFB_PID)"
echo "  - Multilogin: Running (PID: $MULTILOGIN_PID)"
echo "  - API:        http://localhost:35000"
echo "  - VNC:        vnc://localhost:5900 (for GUI debugging)"
echo "=================================================="
echo ""
echo "⚠️  IMPORTANT: This is an unofficial setup!"
echo "   - License activation may be required"
echo "   - Not supported by Multilogin team"
echo "   - Use for testing purposes only"
echo ""

# Watchdog loop
while true; do
    # Check if Xvfb is still running
    if ! ps -p $XVFB_PID > /dev/null; then
        echo "❌ Xvfb crashed! Restarting..."
        Xvfb :99 -screen 0 1920x1080x24 &
        XVFB_PID=$!
        sleep 3
    fi

    # Check if Multilogin is still running
    if ! ps -p $MULTILOGIN_PID > /dev/null; then
        echo "❌ Multilogin crashed! Restarting..."
        /opt/multilogin/multilogin &
        MULTILOGIN_PID=$!
        sleep 5
    fi

    sleep 10
done