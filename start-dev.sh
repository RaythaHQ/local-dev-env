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

echo "Starting MinIO S3..."
docker start minio >/dev/null || true

echo "Starting Sentry..."
docker start sentry >/dev/null || true

# Wait for Sentry dependencies (postgres and redis) to be ready
if docker ps --format '{{.Names}}' | grep -q '^sentry$'; then
  echo "Waiting for Sentry to initialize..."
  sleep 5
  
  # Initialize Sentry database if needed (first run)
  # Create sentry database in postgres if it doesn't exist
  if ! docker exec postgres psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'sentry'" 2>/dev/null | grep -q 1; then
    echo "Initializing Sentry database..."
    docker exec postgres psql -U postgres -c "CREATE DATABASE sentry;" 2>/dev/null || true
    sleep 3
    # Run Sentry migrations (wait for container to be fully ready)
    echo "Running Sentry migrations (this may take a minute on first run)..."
    docker exec sentry sentry upgrade --noinput 2>/dev/null || {
      echo "Note: Sentry initialization may take a moment. Check http://localhost:9004 after a minute."
    }
  fi
fi

# Wait for MinIO to be ready, then ensure bucket exists
if docker ps --format '{{.Names}}' | grep -q '^minio$'; then
  echo "Waiting for MinIO to initialize..."
  sleep 5
  
  # Create user-uploads bucket if it doesn't exist using MinIO Client
  # Use a temporary mc container to connect to MinIO and create the bucket
  # Note: Bucket can also be created via the console at http://localhost:9003
  docker run --rm --network devnet --entrypoint sh minio/mc:latest -c "
    mc alias set local http://minio:9000 minioadmin minioadmin
    if ! mc ls local/user-uploads 2>/dev/null | grep -q user-uploads; then
      echo 'Creating user-uploads bucket...'
      mc mb local/user-uploads
    fi
  " 2>/dev/null || {
    echo "Note: Bucket can be created via the console at http://localhost:9003 (login with minioadmin/minioadmin)"
  }
fi

echo ""
echo "Dev environment is up."
echo ""
echo "UIs:"
echo "  Metabase    → http://localhost:3000"
echo "  MailHog     → http://localhost:8025"
echo "  OpenObserve → http://localhost:5080"
echo ""
echo "MinIO S3:"
echo "  Endpoint: http://localhost:9002"
echo "  Access Key: minioadmin"
echo "  Secret Key: minioadmin"
echo "  Region: us-east-1"
echo "  Bucket: user-uploads"
echo "  Console: http://localhost:9003"
echo ""
echo "Sentry:"
echo "  Web UI: http://localhost:9004"
echo "  Default login: sentry / sentry (change on first login)"
echo "  DSN: Get from project settings after creating a project"
BASH

chmod +x ~/bin/start-dev
echo "Wrote ~/bin/start-dev"
echo "Run it with: start-dev"
