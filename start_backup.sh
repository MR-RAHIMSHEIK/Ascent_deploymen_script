#!/bin/bash
set -euo pipefail

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

echo "🚀 Starting eschool backend stack (with automated backups)..."

# --- Check prerequisites ---
if ! command_exists docker; then
  echo "❌ Error: Docker is not installed or not in PATH."
  exit 1
fi

if ! command_exists docker-compose; then
  echo "❌ Error: docker-compose is not installed or not in PATH."
  exit 1
fi

if [ ! -f .env ]; then
  echo "❌ Error: .env file not found in current directory."
  exit 1
fi

# --- Load environment variables ---
export $(grep -v '^#' .env | xargs)

# --- Ensure backup script is executable ---
if [ -f "scripts/backup.sh" ]; then
  chmod +x scripts/backup.sh
  echo "✅ Backup script permissions set."
else
  echo "⚠️ Warning: scripts/backup.sh not found. Skipping permission setup."
fi

# --- Build all services (including backup container) ---
echo "🏗️ Building Docker images..."
docker compose build

# --- Pull latest images if needed ---
echo "⬇️ Pulling latest images..."
docker compose pull || echo "⚠️ Skipping pull (build used local images)."

# --- Start all containers ---
echo "🚀 Starting containers..."
docker compose up -d

# --- Wait for backend to become healthy ---
echo "⏳ Waiting for backend service to become healthy..."

timeout=120
interval=5
elapsed=0

while true; do
  status=$(docker inspect --format='{{json .State.Health.Status}}' eschool-app 2>/dev/null || echo null)
  if [[ "$status" == "\"healthy\"" ]]; then
    echo "✅ Backend service is healthy!"
    break
  fi
  if [[ "$elapsed" -ge "$timeout" ]]; then
    echo "❌ Timeout waiting for backend service to become healthy."
    docker compose logs eschool-app
    exit 1
  fi
  echo "⌛ Waiting for backend health status... ($elapsed/$timeout seconds)"
  sleep $interval
  elapsed=$((elapsed + interval))
done

echo "🎉 All services are up and running successfully!"
echo "💾 Automated backups are enabled (weekly on Sunday 2 AM)."
echo "📂 Backup files will appear in ./backups"
