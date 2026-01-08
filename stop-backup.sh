#!/bin/bash
set -euo pipefail

echo "🛑 Stopping eschool backend stack (including backup service)..."

# --- Helper function to check if a command exists ---
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# --- Check prerequisites ---
if ! command_exists docker; then
  echo "❌ Error: Docker is not installed or not in PATH."
  exit 1
fi

if ! command_exists docker-compose; then
  echo "❌ Error: docker-compose is not installed or not in PATH."
  exit 1
fi

# --- Check if containers are running ---
running_containers=$(docker ps --filter "name=eschool" --format "{{.Names}}")

if [ -z "$running_containers" ]; then
  echo "⚠️ No running eschool containers found."
else
  echo "📦 Stopping containers: $running_containers"
fi

# --- Stop and remove all containers in the stack ---
docker compose down

echo "✅ All eschool containers stopped and removed."

# --- Optional: confirm specific services are down ---
if docker ps --filter "name=eschool" --format '{{.Names}}' | grep -q .; then
  echo "⚠️ Some eschool containers are still running:"
  docker ps --filter "name=eschool"
else
  echo "🧹 All eschool containers (including backup) are fully stopped."
fi

# --- Optional: confirm network and volumes cleanup ---
if docker network ls | grep -q "eschool"; then
  echo "⚠️ Custom Docker network still present. You can remove it manually if needed."
fi

echo "🏁 Done. Eschool backend stack is completely stopped."
