#!/bin/bash

set -euo pipefail

echo "Stopping eschool backend stack..."

if ! command -v docker-compose >/dev/null 2>&1; then
  echo "Error: docker-compose is not installed or not in PATH."
  exit 1
fi

docker-compose down

echo "All containers stopped."
