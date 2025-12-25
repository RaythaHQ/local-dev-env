# =========================
# start-dev
# =========================
# Starts all dev containers created by setup-dev.sh
# Safe to run repeatedly.
#
# Save as: ~/bin/start-dev
# Run: chmod +x ~/bin/start-dev
# (Optional) sudo ln -sf ~/bin/start-dev /usr/local/bin/start-dev

cat > ~/bin/start-dev <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

echo "Starting SQL Server..."
docker start sqlserver >/dev/null || true

echo "Starting Azurite..."
docker start azurite >/dev/null || true

echo "Starting MongoDB..."
docker start mongodb >/dev/null || true

echo "Starting Postgres..."
docker start postgres >/dev/null || true

echo "Starting ClickHouse..."
docker start clickhouse >/dev/null || true

echo "Starting Metabase..."
docker start metabase >/dev/null || true

echo "Starting MailHog..."
docker start mailhog >/dev/null || true

echo "Starting OpenObserve..."
docker start openobserve >/dev/null || true

echo "Starting redis..."
docker start redis >/dev/null || true

echo ""
echo "Dev environment is up."
echo ""
echo "UIs:"
echo "  Metabase    → http://localhost:3000"
echo "  MailHog     → http://localhost:8025"
echo "  OpenObserve → http://localhost:5080"
BASH

chmod +x ~/bin/start-dev
echo "Wrote ~/bin/start-dev"
echo "Run it with: start-dev"
