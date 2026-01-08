#!/bin/bash
set -euo pipefail

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

echo "🔄 Restarting eschool backend stack (with automated backups)..."

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

# --- Stop existing containers ---
echo "🛑 Stopping running containers..."
docker compose down

# --- Optional cleanup of unused images and volumes ---
echo "🧹 Cleaning up unused Docker resources..."
docker system prune -f --volumes

# --- Ensure backup script permissions ---
if [ -f "scripts/backup.sh" ]; then
  chmod +x scripts/backup.sh
  echo "✅ Backup script permissions verified."
else
  echo "⚠️ Warning: scripts/backup.sh not found, skipping."
fi

# --- Pull latest images ---
echo "⬇️ Pulling latest images..."
docker compose pull

# --- Rebuild images if needed ---
echo "🏗️ Rebuilding images..."
docker compose build

# --- Start containers again ---
echo "🚀 Starting containers..."
docker compose up -d

# --- Wait for backend health check ---
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

echo "🎉 Restart complete!"
echo "💾 Automated backups are still active (every Sunday 2 AM)."
echo "📂 Backup files: ./backups"
