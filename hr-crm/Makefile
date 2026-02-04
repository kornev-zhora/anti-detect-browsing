# HR CRM - Laravel Sail Makefile
# ================================

.PHONY: help up down restart stop build ps logs shell shell-mysql \
        artisan migrate migrate-fresh migrate-rollback seed \
        composer-install composer-update npm-install npm-dev npm-build \
        test test-filter lint pint tinker queue \
        fresh setup env cache-clear optimize

.DEFAULT_GOAL := help

# Sail binary
SAIL := vendor/bin/sail

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1;33m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Docker / Sail

up: ## Start Sail containers in background
	$(SAIL) up -d

down: ## Stop and remove Sail containers
	$(SAIL) down

stop: ## Stop Sail containers (keep state)
	$(SAIL) stop

restart: ## Restart Sail containers
	$(SAIL) restart

build: ## Build/rebuild Sail containers
	$(SAIL) build --no-cache

ps: ## Show running Sail containers
	$(SAIL) ps

logs: ## Follow Sail container logs
	$(SAIL) logs -f

logs-app: ## Follow only the app container logs
	$(SAIL) logs -f hr.crm

logs-mysql: ## Follow only MySQL container logs
	$(SAIL) logs -f mysql

##@ Shell Access

shell: ## Open shell in the app container
	$(SAIL) shell

root: ## Open root shell in the app container
	$(SAIL) root-shell

shell-mysql: ## Open MySQL CLI
	$(SAIL) mysql

##@ Artisan

artisan: ## Run artisan command (usage: make artisan cmd="migrate:status")
	$(SAIL) artisan $(cmd)

tinker: ## Open Laravel Tinker REPL
	$(SAIL) artisan tinker

migrate: ## Run database migrations
	$(SAIL) artisan migrate

migrate-fresh: ## Drop all tables and re-run migrations
	$(SAIL) artisan migrate:fresh

migrate-rollback: ## Rollback the last migration batch
	$(SAIL) artisan migrate:rollback

migrate-status: ## Show migration status
	$(SAIL) artisan migrate:status

seed: ## Run database seeders
	$(SAIL) artisan db:seed

##@ Composer

composer-install: ## Install Composer dependencies
	$(SAIL) composer install

composer-update: ## Update Composer dependencies
	$(SAIL) composer update

composer-require: ## Require a package (usage: make composer-require pkg="vendor/package")
	$(SAIL) composer require $(pkg)

##@ NPM / Frontend

npm-install: ## Install NPM dependencies
	$(SAIL) npm install

npm-dev: ## Start Vite dev server
	$(SAIL) npm run dev

npm-build: ## Build frontend assets for production
	$(SAIL) npm run build

##@ Testing & Quality

test: ## Run all tests (compact output)
	$(SAIL) artisan test --compact

test-filter: ## Run filtered tests (usage: make test-filter f="LoginTest")
	$(SAIL) artisan test --compact --filter=$(f)

test-coverage: ## Run tests with coverage report
	$(SAIL) artisan test --coverage

lint: ## Run Pint linter (fix mode)
	$(SAIL) bin pint --dirty

pint: ## Run Pint on all files
	$(SAIL) bin pint

##@ Cache & Optimization

cache-clear: ## Clear all caches
	$(SAIL) artisan cache:clear
	$(SAIL) artisan config:clear
	$(SAIL) artisan route:clear
	$(SAIL) artisan view:clear

optimize: ## Cache config, routes, and views
	$(SAIL) artisan optimize

optimize-clear: ## Clear all optimization caches
	$(SAIL) artisan optimize:clear

##@ Queue & Scheduler

queue: ## Start the queue worker
	$(SAIL) artisan queue:work

queue-listen: ## Start queue in listen mode (auto-restart on code changes)
	$(SAIL) artisan queue:listen

queue-restart: ## Restart queue workers
	$(SAIL) artisan queue:restart

schedule: ## Run the scheduler
	$(SAIL) artisan schedule:run

##@ Setup & Fresh Install

env: ## Create .env from .env.example if missing
	@test -f .env || cp .env.example .env && echo ".env ready"

setup: env composer-install npm-install ## First-time project setup
	$(SAIL) up -d
	$(SAIL) artisan key:generate
	$(SAIL) artisan migrate
	$(SAIL) npm run build
	@echo ""
	@echo "Setup complete! App running at http://localhost:$${APP_PORT:-8015}"

fresh: ## Full reset: fresh DB + seed + rebuild frontend
	$(SAIL) artisan migrate:fresh --seed
	$(SAIL) npm run build
