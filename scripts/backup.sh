#!/bin/bash
set -euo pipefail

CONTAINER_NAME="mysql"                          # MySQL container name
DB_USER="${MYSQL_USER:-root}"                   # default user
DB_PASSWORD="${MYSQL_PASSWORD:-root}"          # default password
DB_NAME="${MYSQL_DATABASE:-eschool}"           # default database
BACKUP_DIR="/backups"                           # backup folder
DATE=$(date +%F_%H-%M-%S)

mkdir -p "$BACKUP_DIR"
echo "📦 Starting MySQL backup at $(date)..."

docker exec "$CONTAINER_NAME" \
  sh -c "exec mysqldump -u$DB_USER -p\$DB_PASSWORD $DB_NAME" > "$BACKUP_DIR/backup_$DATE.sql"

gzip "$BACKUP_DIR/backup_$DATE.sql"

echo "✅ Backup complete: $BACKUP_DIR/backup_$DATE.sql.gz"
