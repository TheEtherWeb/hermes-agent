.PHONY: up down dev logs db-check redis-check build clean migrate

# ── Development ──────────────────────────────────────────────────────────────────
up:
	@cp -n .env.example .env 2>/dev/null || true
	docker compose up -d

down:
	docker compose down

dev:
	@cp -n .env.example .env 2>/dev/null || true
	docker compose -f docker-compose.yml -f docker-compose.dev.yml up

logs:
	docker compose logs -f --tail=50

build:
	docker compose build --parallel

clean:
	docker compose down -v --remove-orphans

# ── Database Checks ───────────────────────────────────────────────────────────────
db-check:
	@echo "=== TimescaleDB hypertables ==="
	docker compose exec timescaledb psql -U nexus -d nexus -c \
		"SELECT hypertable_name, num_chunks FROM timescaledb_information.hypertables;"
	@echo "\n=== MongoDB collections ==="
	docker compose exec mongodb mongosh --quiet nexus \
		--username nexus --password $${MONGO_PASSWORD:-nexus_dev} \
		--eval "db.getCollectionNames()"

redis-check:
	@echo "=== Redis streams ==="
	docker compose exec redis redis-cli KEYS "nexus:*"

# ── Service Logs ──────────────────────────────────────────────────────────────────
logs-ingestion:
	docker compose logs -f ingestion

logs-algo:
	docker compose logs -f algo-engine algo-beat

logs-gateway:
	docker compose logs -f gateway

logs-dashboard:
	docker compose logs -f dashboard

# ── Health ────────────────────────────────────────────────────────────────────────
health:
	@curl -sf http://localhost:3001/health | python3 -m json.tool || echo "Gateway not ready"
