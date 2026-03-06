.PHONY: archive-sqlite archive-sqlite-fast archive-postgres update export validate clean e2e

COMPOSE_SQLITE = docker compose -f docker-compose.sqlite.yml
COMPOSE_PG = docker compose -f docker-compose.postgres.yml
ARCHIVE_CMD = archive --urls https://meta.discourse.org --categories 61 --formats hybrid --search-backend static --output-dir /archives

# Full archive with SQLite (includes images, ~2 hours)
archive-sqlite:
	$(COMPOSE_SQLITE) run --rm archiver $(ARCHIVE_CMD)

# Fast archive without images (~2 minutes)
archive-sqlite-fast:
	$(COMPOSE_SQLITE) run --rm archiver $(ARCHIVE_CMD) --text-only

# Full archive with PostgreSQL (includes images, ~2 hours)
archive-postgres:
	$(COMPOSE_PG) up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5
	$(COMPOSE_PG) run --rm archiver $(ARCHIVE_CMD)
	$(COMPOSE_PG) down

# Fast archive with PostgreSQL without images (~2 minutes)
archive-postgres-fast:
	$(COMPOSE_PG) up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5
	$(COMPOSE_PG) run --rm archiver $(ARCHIVE_CMD) --text-only
	$(COMPOSE_PG) down

# Incremental update (SQLite)
update:
	$(COMPOSE_SQLITE) run --rm archiver update --output-dir /archives

# Re-export from existing database
export:
	$(COMPOSE_SQLITE) run --rm archiver export --output-dir /archives --formats hybrid --search-backend static

# Validate archive integrity
validate:
	$(COMPOSE_SQLITE) run --rm archiver validate --output-dir /archives

# Clean all generated files (uses container to handle UID mismatch)
clean:
	docker run --rm -v $(CURDIR)/archives:/archives --entrypoint /bin/sh chronicon:latest -c "rm -rf /archives/*" 2>/dev/null || rm -rf archives
	mkdir -p archives
	$(COMPOSE_PG) down -v 2>/dev/null || true

# E2E validation: full cycle with both backends (fast mode, no images)
e2e:
	$(MAKE) clean
	@echo "=== Testing SQLite backend ==="
	$(MAKE) archive-sqlite-fast
	$(MAKE) validate
	@echo "=== SQLite test passed ==="
	$(MAKE) clean
	@echo "=== Testing PostgreSQL backend ==="
	$(MAKE) archive-postgres-fast
	$(MAKE) validate
	@echo "=== PostgreSQL test passed ==="
	@echo "=== All E2E tests passed ==="
