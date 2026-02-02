#!/bin/bash

set -e

echo "🐙 Starting Octo Browser in Docker"
echo "===================================="

# Load credentials from environment
if [ -z "$OCTO_EMAIL" ] || [ -z "$OCTO_PASSWORD" ]; then
    echo "⚠️  WARNING: OCTO_EMAIL or OCTO_PASSWORD not set"
    echo "   These will be needed for API authentication"
fi

# Start Xvfb (virtual display)
echo "📺 Starting Xvfb..."
Xvfb :1 -ac -screen 0 "1920x1080x24" -nolisten tcp +extension GLX +render -noreset > /tmp/xvfb.log 2>&1 &
XVFB_PID=$!

sleep 5

if ! ps -p $XVFB_PID > /dev/null; then
    echo "❌ Xvfb failed to start"
    cat /tmp/xvfb.log
    exit 1
fi

echo "✅ Xvfb started (PID: $XVFB_PID)"

# Fix permissions
echo "🔧 Fixing permissions..."
sudo chown -R octo:octo /home/octo

# Start Octo Browser
echo "🐙 Starting Octo Browser in headless mode..."
echo "   DISPLAY: $DISPLAY"
echo "   HEADLESS: $OCTO_HEADLESS"
echo "   API Port: 58888"
echo ""

/home/octo/browser/OctoBrowser.AppImage > /tmp/octo.log 2>&1 &
OCTO_PID=$!

echo "Octo Browser PID: $OCTO_PID"

# Wait for API to be ready
echo "⏳ Waiting for Octo API..."
MAX_WAIT=120
WAIT_COUNT=0

while ! curl -s http://localhost:58888/api/v1/profiles > /dev/null 2>&1; do
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "❌ Octo API failed to start after ${MAX_WAIT}s"
        echo ""
        echo "📋 Xvfb logs:"
        cat /tmp/xvfb.log
        echo ""
        echo "📋 Octo logs:"
        tail -100 /tmp/octo.log
        exit 1
    fi

    if ! ps -p $OCTO_PID > /dev/null; then
        echo "❌ Octo Browser process died"
        echo ""
        echo "📋 Last logs:"
        tail -50 /tmp/octo.log
        exit 1
    fi

    echo "⏳ Waiting... ($WAIT_COUNT/$MAX_WAIT)"
    sleep 3
    WAIT_COUNT=$((WAIT_COUNT + 3))
done

echo "✅ Octo Browser API ready!"
echo ""

# Authenticate with API if credentials provided
if [ -n "$OCTO_EMAIL" ] && [ -n "$OCTO_PASSWORD" ]; then
    echo "🔐 Authenticating with Octo API..."

    AUTH_RESPONSE=$(curl -s -X POST http://localhost:58888/api/auth/login \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$OCTO_EMAIL\",\"password\":\"$OCTO_PASSWORD\"}")

    if echo "$AUTH_RESPONSE" | grep -q "token"; then
        echo "✅ Authentication successful!"
        # Save token for other scripts
        echo "$AUTH_RESPONSE" > /tmp/octo_token.json
    else
        echo "⚠️  Authentication failed (will need manual login)"
        echo "   Response: $AUTH_RESPONSE"
    fi
else
    echo "⚠️  No credentials provided - skipping authentication"
    echo "   Set OCTO_EMAIL and OCTO_PASSWORD in .env"
fi

echo ""
echo "===================================="
echo "📊 Service Status:"
echo "  - Xvfb:       Running (PID: $XVFB_PID)"
echo "  - Octo:       Running (PID: $OCTO_PID)"
echo "  - API:        http://localhost:58888"
echo "===================================="
echo ""
echo "📚 API Docs: https://documenter.getpostman.com/view/1801428/UVC6i6eA"
echo ""
echo "💡 Next steps:"
echo "   1. Get profiles: curl http://localhost:58888/api/v1/profiles"
echo "   2. Start profile: curl -X POST http://localhost:58888/api/profiles/start -d '{\"uuid\":\"...\"}'"
echo ""

# Keep container running and show logs
tail -f /tmp/octo.log