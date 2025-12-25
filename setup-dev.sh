# =========================
# 1) One-time setup script
# =========================
# This creates:
# - a dedicated docker network
# - named volumes (so data persists across container restarts/recreates)
# - containers with fixed names: sqlserver, azurite, mongodb, postgres, clickhouse, metabase, mailhog, openobserve, redis
#
# Save as: ~/bin/setup-dev.sh
# Run: chmod +x ~/bin/setup-dev.sh && ~/bin/setup-dev.sh

cat > ~/bin/setup-dev.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

# ---- config (edit if you want) ----
NET="devnet"

# Postgres (you asked for these defaults)
PG_USER="postgres"
PG_PASS="changeme"
PG_DB="postgres"
PG_PORT="5432"

# Mongo
MONGO_PORT="27017"

# ClickHouse
CH_HTTP_PORT="8123"
CH_TCP_PORT="9000"

# Metabase
MB_PORT="3000"

# Azurite
AZ_BLOB_PORT="10000"
AZ_QUEUE_PORT="10001"
AZ_TABLE_PORT="10002"

# SQL Server (you MUST set a strong SA password; SQL Server enforces complexity)
# If you already have one, export MSSQL_SA_PASSWORD before running the script.
: "${MSSQL_SA_PASSWORD:=ChangeMe_Strong!123}"
MSSQL_PORT="1433"

# OpenObserve
OO_HTTP_PORT="5080"
OO_GRPC_PORT="5081"        # optional but nice to expose

# Redis


# ---- volumes (named = persistent) ----
V_MSSQL="sqlserver_data"
V_AZURITE="azurite_data"
V_MONGO="mongodb_data"
V_PG="pg_data"      # keeping your screenshot name
V_CH="clickhouse_data"
V_MB="metabase_data"
V_OO="openobserve_data"
V_REDIS="redis_data"

# ---- helpers ----
ensure_network() {
  if ! docker network inspect "$NET" >/dev/null 2>&1; then
    docker network create "$NET" >/dev/null
  fi
}

ensure_volume() {
  local v="$1"
  if ! docker volume inspect "$v" >/dev/null 2>&1; then
    docker volume create "$v" >/dev/null
  fi
}

ensure_image() {
  local image="$1"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "Pulling image: $image"
    docker pull "$image" || {
      echo "Warning: Failed to pull $image, docker run will attempt to pull it"
    }
  fi
}

ensure_container() {
  local name="$1"
  shift
  
  # Extract image name (last argument that looks like an image name)
  # This handles cases like: redis:7 redis-server --appendonly yes
  local image=""
  local args=("$@")
  for ((i=${#args[@]}-1; i>=0; i--)); do
    if [[ "${args[i]}" =~ ^[a-zA-Z0-9._/-]+(:[a-zA-Z0-9._-]+)?$ ]] && [[ ! "${args[i]}" =~ ^-- ]]; then
      image="${args[i]}"
      break
    fi
  done
  
  if [[ -z "$image" ]]; then
    echo "Error: Could not determine image name for container $name" >&2
    return 1
  fi
  
  # Ensure image is available
  ensure_image "$image"
  
  if ! docker inspect "$name" >/dev/null 2>&1; then
    # create container but don't necessarily start it yet
    # Suppress stdout but show stderr for errors
    if ! docker run -d --name "$name" "$@" >/dev/null; then
      echo "Error: Failed to create container $name" >&2
      return 1
    fi
    docker stop "$name" >/dev/null 2>&1
  fi
}

main() {
  ensure_network

  # volumes (persist data even if you docker rm + recreate the container)
  ensure_volume "$V_MSSQL"
  ensure_volume "$V_AZURITE"
  ensure_volume "$V_MONGO"
  ensure_volume "$V_PG"
  ensure_volume "$V_CH"
  ensure_volume "$V_MB"
  ensure_volume "$V_OO"
  ensure_volume "$V_REDIS"

  # ---- SQL Server ----
  # Server=localhost,1433;Database=master;User Id=sa;Password=ChangeMe_Strong!123;TrustServerCertificate=True;
  # Data dir: /var/opt/mssql
  ensure_container sqlserver \
    --restart unless-stopped \
    --network "$NET" \
    -p "${MSSQL_PORT}:1433" \
    -e "ACCEPT_EULA=Y" \
    -e "MSSQL_SA_PASSWORD=${MSSQL_SA_PASSWORD}" \
    -v "${V_MSSQL}:/var/opt/mssql" \
    mcr.microsoft.com/mssql/server:2022-latest

  # ---- Azurite ----
  # DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://localhost:10000/devstoreaccount1;QueueEndpoint=http://localhost:10001/devstoreaccount1;TableEndpoint=http://localhost:10002/devstoreaccount1;
  # Data dir: /data
  ensure_container azurite \
    --restart unless-stopped \
    --network "$NET" \
    -p "${AZ_BLOB_PORT}:10000" \
    -p "${AZ_QUEUE_PORT}:10001" \
    -p "${AZ_TABLE_PORT}:10002" \
    -v "${V_AZURITE}:/data" \
    mcr.microsoft.com/azure-storage/azurite \
    azurite --blobHost 0.0.0.0 --queueHost 0.0.0.0 --tableHost 0.0.0.0 --location /data --debug /data/debug.log

  # ---- MongoDB ----
  # mongodb://localhost:27017
  # Data dir: /data/db
  ensure_container mongodb \
    --restart unless-stopped \
    --network "$NET" \
    -p "${MONGO_PORT}:27017" \
    -v "${V_MONGO}:/data/db" \
    mongo:7

  # ---- Postgres ----
  # postgresql://postgres:changeme@localhost:5432/postgres
  # Data dir: /var/lib/postgresql/data
  ensure_container postgres \
    --restart unless-stopped \
    --network "$NET" \
    -p "${PG_PORT}:5432" \
    -e "POSTGRES_USER=${PG_USER}" \
    -e "POSTGRES_PASSWORD=${PG_PASS}" \
    -e "POSTGRES_DB=${PG_DB}" \
    -v "${V_PG}:/var/lib/postgresql/data" \
    postgres:16

  # ---- ClickHouse ----
  # clickhouse://localhost:9000
  # http://localhost:8123
  # Data dir: /var/lib/clickhouse
  ensure_container clickhouse \
    --restart unless-stopped \
    --network "$NET" \
    -p "${CH_HTTP_PORT}:8123" \
    -p "${CH_TCP_PORT}:9000" \
    -v "${V_CH}:/var/lib/clickhouse" \
    clickhouse/clickhouse-server:latest

  # ---- Metabase ----
  # Web UI: http://localhost:3000
  # We'll persist its internal app DB to /metabase-data (H2 by default)
  ensure_container metabase \
    --restart unless-stopped \
    --network "$NET" \
    -p "${MB_PORT}:3000" \
    -e "MB_DB_FILE=/metabase_data/metabase.db" \
    -v "${V_MB}:/metabase_data" \
    metabase/metabase:latest

  # ---- MailHog ----
  # SMTP: 1025, Web UI: 8025
  ensure_container mailhog \
    --restart unless-stopped \
    --network "$NET" \
    -p 1025:1025 \
    -p 8025:8025 \
    mailhog/mailhog

  # ---- OpenObserve ----
  # http://localhost:5080
  ensure_container openobserve \
    --restart unless-stopped \
    --network "$NET" \
    -p "${OO_HTTP_PORT}:5080" \
    -p "${OO_GRPC_PORT}:5081" \
    -e "ZO_ROOT_USER_EMAIL=root@example.com" \
    -e "ZO_ROOT_USER_PASSWORD=Complexpass#123" \
    -v "${V_OO}:/data" \
    openobserve/openobserve:latest

  # ---- Redis ----
  # redis://localhost:6379
  ensure_container redis \
    --restart unless-stopped \
    --network "$NET" \
    -p 6379:6379 \
    -v "${V_REDIS}:/data" \
    redis:7 \
    redis-server --appendonly yes


  echo "Setup complete."
  echo "Run: start-dev (after installing it below) or: ~/bin/start-dev"
  echo ""
  echo "Postgres creds: user=${PG_USER} pass=${PG_PASS}"
}

main "$@"
BASH

chmod +x ~/bin/setup-dev.sh
echo "Wrote ~/bin/setup-dev.sh"
echo "Run it now with: ~/bin/setup-dev.sh"
