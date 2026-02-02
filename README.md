# Anti-Detect Browser Performance Testing

Local Docker setup to test memory consumption and performance of anti-detect browsers before production deployment.

## Supported Browsers

- ✅ **Kameleo** (Official Docker image)
- ⚠️ **Multilogin** (Unofficial community Docker setup)
- ℹ️ **GoLogin** (Cloud-only, no local Docker available)

## Prerequisites

- Docker 24.0+
- Docker Compose 2.20+
- 16GB RAM minimum (32GB recommended)
- 50GB free disk space
- Python 3.9+ (for testing scripts)

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/anti-detect-browser-test.git
cd anti-detect-browser-test
```


![Make scripts](/docs/MakeFile-commands.png)
![Make scripts](/docs/ram-usage-kameleo.png)
![Make scripts](/docs/ram-usage-multilogin.png)


### 2. Configure Environment
```bash
cp .env.example .env
nano .env  # Add your license keys
```

### 3. Choose Browser to Test

#### Option A: Kameleo (Official, Recommended)
```bash
cd kameleo
docker-compose -f docker-compose.kameleo.yml up -d
```

**Requirements:**
- Kameleo license key (trial available: https://kameleo.io/pricing)
- Plan: Docker Automation ($299/month or trial)

#### Option B: Multilogin (Unofficial, Not Recommended)
```bash
cd multilogin-unofficial
docker-compose -f docker-compose.multilogin.yml up -d
```

**⚠️ Warning:** This is an unofficial setup. Use at your own risk.

### 4. Run Performance Tests
```bash
# Install dependencies
pip install -r requirements.txt

# Test API availability
python scripts/test_api.py --browser kameleo

# Memory benchmark (create 1-10 profiles)
python scripts/test_memory.py --browser kameleo --profiles 5

# Full benchmark suite
bash scripts/benchmark.sh kameleo
```

## Memory Consumption Benchmarks

### Expected Results (per browser profile)

| Browser | RAM (idle) | RAM (active browsing) | CPU (idle) | CPU (active) |
|---------|------------|---------------------|-----------|-------------|
| **Kameleo** | 500-700 MB | 800-1200 MB | 5-10% | 15-25% |
| **Multilogin** | 600-900 MB | 1000-1500 MB | 8-15% | 20-35% |

### Concurrent Profiles Test

Run multiple browser profiles simultaneously to test scalability:
```bash
# Test with 5 concurrent profiles
python scripts/test_memory.py \
  --browser kameleo \
  --profiles 5 \
  --concurrent

# Test with 10 concurrent profiles
python scripts/test_memory.py \
  --browser kameleo \
  --profiles 10 \
  --concurrent
```

**Expected RAM usage:**
- 5 profiles: ~4-6 GB total
- 10 profiles: ~8-12 GB total
- 20 profiles: ~16-24 GB total

## API Testing

### Check API Availability
```bash
# Kameleo
curl http://localhost:5050/v1/profiles

# Multilogin (unofficial)
curl http://localhost:35000/api/v2/profile
```

### Postman Collection

Import `postman/anti-detect-api.json` into Postman for interactive API testing.

**Available endpoints:**

**Kameleo:**
- `GET http://localhost:5050/v1/profiles` - List profiles
- `POST http://localhost:5050/v1/profiles` - Create profile
- `POST http://localhost:5050/v1/profiles/{id}/start` - Start browser
- `POST http://localhost:5050/v1/profiles/{id}/stop` - Stop browser

**Multilogin:**
- `GET http://localhost:35000/api/v2/profile` - List profiles
- `POST http://localhost:35000/api/v1/profile/start` - Start browser
- `POST http://localhost:35000/api/v1/profile/stop` - Stop browser

## Selenium Integration Test

Test browser automation with Selenium:
```bash
python scripts/test_selenium.py \
  --browser kameleo \
  --url https://linkedin.com/login \
  --screenshot results/screenshot.png
```

## Performance Monitoring

### Real-time Docker Stats
```bash
# Monitor resource usage
docker stats

# Export stats to CSV
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" > results/stats.csv
```

### Memory Profiling
```bash
# Profile memory over 5 minutes
python scripts/test_memory.py \
  --browser kameleo \
  --profiles 5 \
  --duration 300 \
  --output results/memory_profile.json
```

## Cost Analysis

### Infrastructure Requirements Based on Tests

After running benchmarks, calculate infrastructure costs:
```bash
python scripts/calculate_cost.py \
  --profiles 50 \
  --concurrent 10 \
  --provider aws  # or hetzner, digitalocean
```

**Example output:**
```
Based on your test results:
- 10 concurrent profiles require: 12GB RAM, 4 vCPU
- Recommended server: AWS t3.xlarge
- Monthly cost: $150/month
```

## Cleanup
```bash
# Stop containers
docker-compose down

# Remove volumes (⚠️ deletes all profiles)
docker-compose down -v

# Remove images
docker rmi kameleo/kameleo-base
```

## Troubleshooting

### Kameleo Issues

**Problem:** Container fails to start
```bash
# Check logs
docker logs kameleo

# Common fix: Invalid license key
# Solution: Verify KAMELEO_LICENSE_KEY in .env
```

**Problem:** API returns 401 Unauthorized
```bash
# Restart container
docker-compose restart kameleo
```

### Multilogin Issues

**Problem:** X server fails to start
```bash
# Check Xvfb logs
docker exec multilogin ps aux | grep Xvfb

# Restart X server
docker exec multilogin killall Xvfb
docker exec multilogin Xvfb :99 -screen 0 1920x1080x24 &
```

**Problem:** License activation required
```bash
# This setup doesn't support automatic activation
# You must:
1. Stop container
2. Use desktop app to activate
3. Copy license files to Docker volume
```

## Results Interpretation

### Memory Test Results

After running `test_memory.py`, check `results/memory_profile.json`:
```json
{
  "browser": "kameleo",
  "profiles_tested": 5,
  "average_memory_per_profile": "650 MB",
  "peak_memory_total": "3.2 GB",
  "recommended_ram_for_production": "16 GB",
  "max_concurrent_profiles_recommended": 12
}
```

### Decision Making

Based on test results:

| RAM per profile | Max concurrent (16GB server) | Max concurrent (32GB server) |
|----------------|------------------------------|------------------------------|
| 500 MB | 20 profiles | 45 profiles |
| 800 MB | 12 profiles | 28 profiles |
| 1200 MB | 8 profiles | 18 profiles |

**Note:** Leave 4-8GB for OS and other processes.

## Production Recommendations

### If Tests Show Good Performance (< 800 MB/profile)
```
✅ Proceed with Kameleo Docker for production
✅ Server specs: 32GB RAM, 8 vCPU
✅ Expected cost: ~$120-150/month (Hetzner/DigitalOcean)
```

### If Tests Show High Memory Usage (> 1200 MB/profile)
```
⚠️ Consider GoLogin Cloud API instead
⚠️ Or upgrade to 64GB+ RAM servers
⚠️ Budget accordingly: ~$240-300/month
```

## Security Notes

- ⚠️ **Never commit `.env` file** (contains license keys)
- ⚠️ **Bind to localhost only** for testing (0.0.0.0 in production with firewall)
- ⚠️ **Encrypt volumes** if storing sensitive credentials
- ⚠️ **Use Docker secrets** in production instead of environment variables

## Support & Documentation

- **Kameleo Docs:** https://developer.kameleo.io/
- **Multilogin Docs:** https://docs.multilogin.com/ (desktop app only)
- **GoLogin Docs:** https://api.gologin.com/docs
- **Issues:** https://github.com/yourusername/anti-detect-browser-test/issues

## License

MIT License - See LICENSE file

## Contributing

Pull requests welcome! Please read CONTRIBUTING.md first.

---

**Last Updated:** 2025-01-15
**Tested With:** Docker 24.0.7, Kameleo 4.2.0, Multilogin 6.1.0