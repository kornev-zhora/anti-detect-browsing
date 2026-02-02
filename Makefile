# Anti-Detect Browser Testing - Makefile
# ======================================

.PHONY: help install setup test clean

# Default target
.DEFAULT_GOAL := help

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Auto-detect Docker Compose command (v1 vs v2)
ifeq ($(shell docker compose version > /dev/null 2>&1 && echo v2), v2)
    DOCKER_COMPOSE := docker compose
else
    DOCKER_COMPOSE := docker-compose
endif

# Variables
KAMELEO_COMPOSE := kameleo/docker-compose.kameleo.yml
MULTILOGIN_COMPOSE := multilogin-unofficial/docker-compose.multilogin.yml
PYTHON := python3
PIP := pip3

##@ General

help: ## Display this help message
	@echo "$(BLUE)Anti-Detect Browser Testing$(NC)"
	@echo "=============================="
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(CYAN)<target>$(NC)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

version: ## Show versions of installed tools
	@echo "$(BLUE)Installed versions:$(NC)"
	@echo "Docker: $$(docker --version)"
	@echo "Docker Compose: $$($(DOCKER_COMPOSE) version)"
	@echo "Python: $$($(PYTHON) --version)"
	@echo "Pip: $$($(PIP) --version)"
	@echo "Detected compose command: $(DOCKER_COMPOSE)"

##@ Setup

install: ## Install Python dependencies
	@echo "$(GREEN)Installing Python dependencies...$(NC)"
	$(PIP) install --upgrade pip
	$(PIP) install docker requests selenium python-dotenv psutil
	@echo "$(GREEN)✅ Dependencies installed$(NC)"

setup: ## Initial setup - create directories and networks
	@echo "$(GREEN)Setting up project structure...$(NC)"
	mkdir -p results
	mkdir -p monitoring/grafana-dashboards
	touch results/.gitkeep
	@echo "$(GREEN)Creating Docker network...$(NC)"
	docker network create antidetect-test-network 2>/dev/null || true
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Creating .env file from .env.example...$(NC)"; \
		cp .env.example .env; \
		echo "$(RED)⚠️  Please edit .env and add your license keys!$(NC)"; \
	fi
	@echo "$(GREEN)✅ Setup complete!$(NC)"

##@ Kameleo (Official Docker)

kameleo-start: ## Start Kameleo container
	@echo "$(GREEN)Starting Kameleo...$(NC)"
	@if [ -z "$$(grep KAMELEO_LICENSE_KEY .env | grep -v '^#' | cut -d '=' -f2)" ]; then \
		echo "$(RED)❌ ERROR: KAMELEO_LICENSE_KEY not set in .env$(NC)"; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) -f $(KAMELEO_COMPOSE) up -d
	@echo "$(GREEN)⏳ Waiting for Kameleo API to be ready...$(NC)"
	@sleep 10
	@$(MAKE) kameleo-health
	@echo "$(GREEN)✅ Kameleo started at http://localhost:5050$(NC)"

kameleo-stop: ## Stop Kameleo container
	@echo "$(YELLOW)Stopping Kameleo...$(NC)"
	$(DOCKER_COMPOSE) -f $(KAMELEO_COMPOSE) down
	@echo "$(GREEN)✅ Kameleo stopped$(NC)"

kameleo-restart: ## Restart Kameleo container
	@$(MAKE) kameleo-stop
	@sleep 2
	@$(MAKE) kameleo-start

kameleo-logs: ## Show Kameleo logs (follow)
	$(DOCKER_COMPOSE) -f $(KAMELEO_COMPOSE) logs -f

kameleo-health: ## Check Kameleo health
	@echo "$(BLUE)Checking Kameleo API...$(NC)"
	@curl -f http://localhost:5050/v1/health 2>/dev/null && \
		echo "$(GREEN)✅ Kameleo API is healthy$(NC)" || \
		echo "$(RED)❌ Kameleo API is not responding$(NC)"

kameleo-test-api: ## Test Kameleo API with curl
	@echo "$(BLUE)Testing Kameleo API endpoints:$(NC)"
	@echo "GET /v1/profiles:"
	@curl -s http://localhost:5050/v1/profiles | jq . || echo "$(RED)Failed$(NC)"

##@ Multilogin (Unofficial Docker)

multilogin-build: ## Build Multilogin Docker image
	@echo "$(YELLOW)⚠️  WARNING: This is an unofficial Multilogin setup!$(NC)"
	@echo "$(YELLOW)You must download multilogin.deb manually first.$(NC)"
	@if [ ! -f multilogin-unofficial/multilogin.deb ]; then \
		echo "$(RED)❌ ERROR: multilogin.deb not found$(NC)"; \
		echo "$(YELLOW)Download from https://multilogin.com/download$(NC)"; \
		echo "$(YELLOW)Place it in multilogin-unofficial/multilogin.deb$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Building Docker image...$(NC)"
	cd multilogin-unofficial && $(DOCKER_COMPOSE) -f docker-compose.multilogin.yml build
	@echo "$(GREEN)✅ Build complete$(NC)"

multilogin-start: ## Start Multilogin container
	@echo "$(GREEN)Starting Multilogin...$(NC)"
	cd multilogin-unofficial && $(DOCKER_COMPOSE) -f docker-compose.multilogin.yml up -d
	@echo "$(GREEN)⏳ Waiting for Multilogin to start (this may take 60s)...$(NC)"
	@sleep 30
	@$(MAKE) multilogin-health
	@echo "$(GREEN)✅ Multilogin started$(NC)"
	@echo "$(BLUE)API: http://localhost:35000$(NC)"
	@echo "$(BLUE)VNC: vnc://localhost:5900 (for GUI debugging)$(NC)"

multilogin-stop: ## Stop Multilogin container
	@echo "$(YELLOW)Stopping Multilogin...$(NC)"
	cd multilogin-unofficial && $(DOCKER_COMPOSE) -f docker-compose.multilogin.yml down
	@echo "$(GREEN)✅ Multilogin stopped$(NC)"

multilogin-restart: ## Restart Multilogin container
	@$(MAKE) multilogin-stop
	@sleep 2
	@$(MAKE) multilogin-start

multilogin-logs: ## Show Multilogin logs (follow)
	docker logs -f multilogin-unofficial

multilogin-health: ## Check Multilogin health
	@echo "$(BLUE)Checking Multilogin API...$(NC)"
	@curl -f http://localhost:35000/api/v2/profile 2>/dev/null && \
		echo "$(GREEN)✅ Multilogin API is healthy$(NC)" || \
		echo "$(RED)❌ Multilogin API is not responding$(NC)"

multilogin-vnc: ## Show VNC connection info
	@echo "$(BLUE)VNC Server Information:$(NC)"
	@echo "URL: vnc://localhost:5900"
	@echo "Password: (none)"
	@echo ""
	@echo "Connect with VNC client to debug GUI issues"

multilogin-test-api: ## Test Multilogin API with curl
	@echo "$(BLUE)Testing Multilogin API endpoints:$(NC)"
	@echo "GET /api/v2/profile:"
	@curl -s http://localhost:35000/api/v2/profile | jq . || echo "$(RED)Failed$(NC)"

##@ Monitoring

monitoring-start: ## Start Prometheus + Grafana monitoring
	@echo "$(GREEN)Starting monitoring stack...$(NC)"
	$(DOCKER_COMPOSE) up -d prometheus grafana cadvisor
	@sleep 5
	@echo "$(GREEN)✅ Monitoring started$(NC)"
	@echo "$(BLUE)Prometheus: http://localhost:9090$(NC)"
	@echo "$(BLUE)Grafana: http://localhost:3000 (admin/admin)$(NC)"
	@echo "$(BLUE)cAdvisor: http://localhost:8080$(NC)"

monitoring-stop: ## Stop monitoring stack
	@echo "$(YELLOW)Stopping monitoring...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✅ Monitoring stopped$(NC)"

monitoring-logs: ## Show monitoring logs
	$(DOCKER_COMPOSE) logs -f prometheus grafana

##@ Testing

test-kameleo: kameleo-start ## Run full Kameleo benchmark
	@echo "$(GREEN)🧪 Running Kameleo benchmarks...$(NC)"
	@sleep 5
	bash scripts/benchmark.sh kameleo
	@echo "$(GREEN)✅ Kameleo tests complete! Check results/$(NC)"

test-multilogin: multilogin-start ## Run full Multilogin benchmark
	@echo "$(GREEN)🧪 Running Multilogin benchmarks...$(NC)"
	@sleep 5
	bash scripts/benchmark.sh multilogin
	@echo "$(GREEN)✅ Multilogin tests complete! Check results/$(NC)"

test-memory-kameleo: ## Test Kameleo memory (5 profiles, concurrent)
	@echo "$(GREEN)Testing Kameleo memory with 5 concurrent profiles...$(NC)"
	$(PYTHON) scripts/test_memory.py --browser kameleo --profiles 5 --concurrent --output results/kameleo_memory.json
	@cat results/kameleo_memory.json | jq .

test-memory-multilogin: ## Test Multilogin memory (5 profiles, concurrent)
	@echo "$(GREEN)Testing Multilogin memory with 5 concurrent profiles...$(NC)"
	$(PYTHON) scripts/test_memory.py --browser multilogin --profiles 5 --concurrent --output results/multilogin_memory.json
	@cat results/multilogin_memory.json | jq .

test-quick: ## Quick test (baseline only)
	@echo "$(GREEN)Running quick baseline test...$(NC)"
	docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" > results/baseline.txt
	@cat results/baseline.txt
	@echo "$(GREEN)✅ Baseline saved to results/baseline.txt$(NC)"

##@ Docker Management

ps: ## Show running containers
	@docker ps --filter "network=antidetect-test-network" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

stats: ## Show real-time Docker stats
	@docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

stats-export: ## Export Docker stats to CSV
	@echo "$(GREEN)Exporting stats to results/docker_stats.csv...$(NC)"
	@docker stats --no-stream --format "{{.Container}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}}" > results/docker_stats.csv
	@echo "$(GREEN)✅ Stats exported$(NC)"

logs: ## Show all container logs
	$(DOCKER_COMPOSE) logs -f

shell-kameleo: ## Open shell in Kameleo container
	docker exec -it kameleo /bin/bash

shell-multilogin: ## Open shell in Multilogin container
	docker exec -it multilogin-unofficial /bin/bash

##@ Cleanup

clean: ## Stop all containers and remove volumes
	@echo "$(RED)⚠️  This will stop all containers and DELETE all data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(MAKE) clean-force; \
	else \
		echo "$(GREEN)Cancelled$(NC)"; \
	fi

clean-force: ## Force cleanup (no confirmation)
	@echo "$(RED)Stopping and removing all containers...$(NC)"
	-$(DOCKER_COMPOSE) -f $(KAMELEO_COMPOSE) down -v 2>/dev/null
	-cd multilogin-unofficial && $(DOCKER_COMPOSE) -f docker-compose.multilogin.yml down -v 2>/dev/null
	-$(DOCKER_COMPOSE) down -v 2>/dev/null
	@echo "$(YELLOW)Removing Docker network...$(NC)"
	-docker network rm antidetect-test-network 2>/dev/null
	@echo "$(GREEN)✅ Cleanup complete$(NC)"

clean-results: ## Delete test results only
	@echo "$(YELLOW)Deleting test results...$(NC)"
	rm -rf results/*.json results/*.csv results/*.txt results/*.png
	@echo "$(GREEN)✅ Results deleted$(NC)"

prune: ## Prune Docker system (free up space)
	@echo "$(YELLOW)Pruning Docker system...$(NC)"
	docker system prune -f
	@echo "$(GREEN)✅ Prune complete$(NC)"

##@ Quick Start Workflows

start-kameleo-full: setup install kameleo-start monitoring-start ## Full Kameleo setup (setup + install + start)
	@echo ""
	@echo "$(GREEN)✅ Kameleo environment ready!$(NC)"
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  make test-kameleo      # Run benchmarks"
	@echo "  make kameleo-logs      # View logs"
	@echo "  make stats             # Monitor resources"

start-multilogin-full: setup install multilogin-build multilogin-start monitoring-start ## Full Multilogin setup
	@echo ""
	@echo "$(GREEN)✅ Multilogin environment ready!$(NC)"
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  make test-multilogin   # Run benchmarks"
	@echo "  make multilogin-logs   # View logs"
	@echo "  make multilogin-vnc    # VNC debug info"

compare: test-kameleo test-multilogin ## Run tests on both browsers and compare
	@echo ""
	@echo "$(GREEN)🏁 Comparison Results$(NC)"
	@echo "======================"
	@echo ""
	@echo "$(BLUE)Kameleo Results:$(NC)"
	@cat results/kameleo_memory.json | jq '{browser, baseline_memory_mb, profiles_tested}'
	@echo ""
	@echo "$(BLUE)Multilogin Results:$(NC)"
	@cat results/multilogin_memory.json | jq '{browser, baseline_memory_mb, profiles_tested}'
	@echo ""
	@echo "$(YELLOW)Full results in results/ directory$(NC)"

##@ Development

dev-kameleo: ## Development mode - Kameleo with auto-restart
	@echo "$(GREEN)Starting Kameleo in development mode...$(NC)"
	$(DOCKER_COMPOSE) -f $(KAMELEO_COMPOSE) up

dev-multilogin: ## Development mode - Multilogin with auto-restart
	@echo "$(GREEN)Starting Multilogin in development mode...$(NC)"
	cd multilogin-unofficial && $(DOCKER_COMPOSE) -f docker-compose.multilogin.yml up

reload: ## Reload all containers (for config changes)
	@echo "$(YELLOW)Reloading containers...$(NC)"
	$(DOCKER_COMPOSE) restart
	-$(DOCKER_COMPOSE) -f $(KAMELEO_COMPOSE) restart
	@echo "$(GREEN)✅ Reload complete$(NC)"

##@ Documentation

show-env: ## Show current environment variables
	@echo "$(BLUE)Current environment:$(NC)"
	@cat .env | grep -v '^#' | grep -v '^$$'

edit-env: ## Edit .env file
	$${EDITOR:-nano} .env

docs: ## Generate API documentation
	@echo "$(BLUE)API Documentation:$(NC)"
	@echo ""
	@echo "$(YELLOW)Kameleo API:$(NC) https://developer.kameleo.io/"
	@echo "$(YELLOW)Multilogin API:$(NC) https://documenter.getpostman.com/view/28533318/2s946h9Cv9"
	@echo ""
	@echo "$(BLUE)Local API Endpoints:$(NC)"
	@echo "  Kameleo:    http://localhost:5050/v1/"
	@echo "  Multilogin: http://localhost:35000/api/"

##@ CI/CD

ci-test: ## Run CI tests (non-interactive)
	@echo "$(GREEN)Running CI tests...$(NC)"
	$(MAKE) setup
	$(MAKE) install
	$(MAKE) test-quick
	@echo "$(GREEN)✅ CI tests passed$(NC)"

validate: ## Validate configuration files
	@echo "$(BLUE)Validating configuration...$(NC)"
	@$(DOCKER_COMPOSE) config > /dev/null && echo "$(GREEN)✅ docker-compose.yml valid$(NC)" || echo "$(RED)❌ docker-compose.yml invalid$(NC)"
	@$(DOCKER_COMPOSE) -f $(KAMELEO_COMPOSE) config > /dev/null && echo "$(GREEN)✅ kameleo compose valid$(NC)" || echo "$(RED)❌ kameleo compose invalid$(NC)"
	@test -f .env && echo "$(GREEN)✅ .env exists$(NC)" || echo "$(RED)❌ .env missing$(NC)"
	@$(PYTHON) -m py_compile scripts/*.py 2>/dev/null && echo "$(GREEN)✅ Python scripts valid$(NC)" || echo "$(YELLOW)⚠️  Python script validation skipped$(NC)"

##@ Troubleshooting

troubleshoot: ## Run troubleshooting diagnostics
	@echo "$(BLUE)Running diagnostics...$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Docker Status:$(NC)"
	@docker info > /dev/null 2>&1 && echo "$(GREEN)✅ Docker running$(NC)" || echo "$(RED)❌ Docker not running$(NC)"
	@echo ""
	@echo "$(YELLOW)2. Docker Compose:$(NC)"
	@echo "Detected: $(DOCKER_COMPOSE)"
	@$(DOCKER_COMPOSE) version
	@echo ""
	@echo "$(YELLOW)3. Network:$(NC)"
	@docker network ls | grep antidetect-test-network > /dev/null && echo "$(GREEN)✅ Network exists$(NC)" || echo "$(RED)❌ Network missing$(NC)"
	@echo ""
	@echo "$(YELLOW)4. Containers:$(NC)"
	@$(MAKE) ps
	@echo ""
	@echo "$(YELLOW)5. Disk Space:$(NC)"
	@df -h | grep -E 'Filesystem|/$$'
	@echo ""
	@echo "$(YELLOW)6. Environment:$(NC)"
	@$(MAKE) version

debug-kameleo: ## Debug Kameleo issues
	@echo "$(BLUE)Kameleo Debug Info:$(NC)"
	@echo ""
	docker logs kameleo --tail 50
	@echo ""
	@echo "Healthcheck:"
	@$(MAKE) kameleo-health

debug-multilogin: ## Debug Multilogin issues
	@echo "$(BLUE)Multilogin Debug Info:$(NC)"
	@echo ""
	docker logs multilogin-unofficial --tail 50
	@echo ""
	@echo "Xvfb status:"
	@docker exec multilogin-unofficial ps aux | grep Xvfb || echo "Xvfb not running"
	@echo ""
	@echo "Healthcheck:"
	@$(MAKE) multilogin-health

##@ Octo Browser (Docker with Authentication)

octo-build: ## Build Octo Browser Docker image
	@echo "$(GREEN)Building Octo Browser image...$(NC)"
	@if [ -z "$$(grep OCTO_EMAIL .env | grep -v '^#' | cut -d '=' -f2)" ]; then \
		echo "$(YELLOW)⚠️  WARNING: OCTO_EMAIL not set in .env$(NC)"; \
		echo "   API authentication will not work without credentials"; \
	fi
	cd octo && $(DOCKER_COMPOSE) -f docker-compose.octo.yml build
	@echo "$(GREEN)✅ Build complete$(NC)"

octo-start: octo-build ## Start Octo Browser container
	@echo "$(GREEN)Starting Octo Browser...$(NC)"
	cd octo && $(DOCKER_COMPOSE) -f docker-compose.octo.yml up -d
	@echo "$(GREEN)⏳ Waiting for Octo API (this takes ~2 minutes)...$(NC)"
	@sleep 60
	@$(MAKE) octo-health
	@echo "$(GREEN)✅ Octo Browser started at http://localhost:58888$(NC)"

octo-stop: ## Stop Octo Browser
	@echo "$(YELLOW)Stopping Octo Browser...$(NC)"
	cd octo && $(DOCKER_COMPOSE) -f docker-compose.octo.yml down
	@echo "$(GREEN)✅ Stopped$(NC)"

octo-restart: octo-stop ## Restart Octo Browser
	@sleep 2
	@$(MAKE) octo-start

octo-logs: ## Show Octo logs (follow)
	docker logs -f octo-browser

octo-health: ## Check Octo API health
	@echo "$(BLUE)Checking Octo API...$(NC)"
	@curl -s http://localhost:58888/api/v1/profiles > /dev/null && \
		echo "$(GREEN)✅ Octo API is healthy$(NC)" || \
		echo "$(RED)❌ Octo API not responding$(NC)"

octo-test: ## Test Octo with Python (includes auth)
	@echo "$(GREEN)Testing Octo Browser...$(NC)"
	@if [ -z "$$(grep OCTO_EMAIL .env | grep -v '^#' | cut -d '=' -f2)" ]; then \
		echo "$(RED)❌ ERROR: OCTO_EMAIL not set in .env$(NC)"; \
		exit 1; \
	fi
	$(PYTHON) scripts/test_octo.py

octo-login: ## Test login to Octo API
	@echo "$(BLUE)Testing Octo authentication...$(NC)"
	@curl -X POST http://localhost:58888/api/auth/login \
		-H "Content-Type: application/json" \
		-d "{\"email\":\"$$(grep OCTO_EMAIL .env | cut -d '=' -f2)\",\"password\":\"$$(grep OCTO_PASSWORD .env | cut -d '=' -f2)\"}" | jq .

octo-profiles: ## List profiles (requires auth token)
	@echo "$(BLUE)Listing Octo profiles...$(NC)"
	@echo "Use: make octo-test (includes authentication)"

octo-shell: ## Open shell in Octo container
	docker exec -it octo-browser /bin/bash

octo-clean: ## Remove Octo volumes and data
	@echo "$(RED)Removing Octo data...$(NC)"
	cd octo && $(DOCKER_COMPOSE) -f docker-compose.octo.yml down -v
	@echo "$(GREEN)✅ Clean complete$(NC)"