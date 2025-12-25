# =========================
# One-time teardown / cleanup script
# =========================
# This will REMOVE EVERYTHING created by your setup-dev.sh:
# - containers (sqlserver, azurite, mongodb, postgres, clickhouse, metabase, mailhog, openobserve)
# - volumes (sqlserver_data, azurite_data, mongodb_data, pg_data, clickhouse_data, metabase_data, openobserve_data)
# - network (devnet)
#
# Save as: ~/bin/nuke-dev.sh
# Run: chmod +x ~/bin/nuke-dev.sh && ~/bin/nuke-dev.sh

cat > ~/bin/nuke-dev.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

NET="devnet"

CONTAINERS=(
  sqlserver
  azurite
  mongodb
  postgres
  clickhouse
  metabase
  mailhog
  openobserve
)

VOLUMES=(
  sqlserver_data
  azurite_data
  mongodb_data
  pg_data
  clickhouse_data
  metabase_data
  openobserve_data
)

echo "Stopping containers (if running)..."
for c in "${CONTAINERS[@]}"; do
  docker stop "$c" >/dev/null 2>&1 || true
done

echo "Removing containers..."
for c in "${CONTAINERS[@]}"; do
  docker rm -f "$c" >/dev/null 2>&1 || true
done

echo "Removing volumes (THIS DELETES DATA)..."
for v in "${VOLUMES[@]}"; do
  docker volume rm "$v" >/dev/null 2>&1 || true
done

echo "Removing network..."
docker network rm "$NET" >/dev/null 2>&1 || true

echo ""
echo "Done."
echo "Remaining matching containers (should be none):"
docker ps -a --format '{{.Names}}' | grep -E '^(sqlserver|azurite|mongodb|postgres|clickhouse|metabase|mailhog|openobserve)$' || true

echo ""
echo "Remaining matching volumes (should be none):"
docker volume ls --format '{{.Name}}' | grep -E '^(sqlserver_data|azurite_data|mongodb_data|pg_data|clickhouse_data|metabase_data|openobserve_data)$' || true

echo ""
echo "Remaining network (should be none):"
docker network ls --format '{{.Name}}' | grep -E "^${NET}$" || true
BASH

chmod +x ~/bin/nuke-dev.sh
echo "Wrote ~/bin/nuke-dev.sh"
echo "Run it now with: ~/bin/nuke-dev.sh"
