#!/bin/bash

BROWSER=$1

if [ -z "$BROWSER" ]; then
    echo "Usage: ./benchmark.sh [kameleo|multilogin]"
    exit 1
fi

echo "🚀 Running full benchmark suite for $BROWSER"
echo "=============================================="

# Create results directory
mkdir -p results

# Test 1: Baseline
echo ""
echo "📊 Test 1: Baseline (no profiles)"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" > results/baseline.txt

# Test 2: 5 profiles sequential
echo ""
echo "📊 Test 2: 5 profiles (sequential)"
python3 scripts/test_memory.py --browser $BROWSER --profiles 5 --output results/test_5_sequential.json

# Test 3: 5 profiles concurrent
echo ""
echo "📊 Test 3: 5 profiles (concurrent)"
python3 scripts/test_memory.py --browser $BROWSER --profiles 5 --concurrent --output results/test_5_concurrent.json

# Test 4: 10 profiles concurrent
echo ""
echo "📊 Test 4: 10 profiles (concurrent)"
python3 scripts/test_memory.py --browser $BROWSER --profiles 10 --concurrent --output results/test_10_concurrent.json

echo ""
echo "✅ Benchmark complete! Check results/ directory"