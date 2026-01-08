# **Eschool Docker Setup Documentation**

## **1️⃣ Project Overview**

This project uses **Docker and Docker Compose** to run:

* **MySQL 8** – database
* **Two backend services** – `backend-v1` (eschool-app) and `backend-v2` (eschool-reports)
* **Angular frontend** – served via Nginx
* **Backup container** – automatic weekly MySQL backups

All services communicate over a **Docker network** called `backend`.

---

## **2️⃣ Prerequisites**

Before running the project, ensure the client machine has:

* [Docker](https://www.docker.com/get-started) installed
* [Docker Compose](https://docs.docker.com/compose/install/) installed
* Git or access to the project folder

---

## **3️⃣ Environment Variables (.env)**

Create a file named `.env` in the project root:

```env
MYSQL_DATABASE=eschool
MYSQL_USER=root
MYSQL_PASSWORD=root
MYSQL_ROOT_PASSWORD=root
```

> **Note:** These variables are used for MySQL, backend connections, and backup scripts. They only take effect **when the MySQL data directory is empty** (first container start).

---

## **4️⃣ Docker Compose Setup**

**File:** `docker-compose.yml`

```yaml
version: "3.8"

services:
  mysql:
    image: mysql:8.0
    container_name: mysql
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - ./data/mysql:/var/lib/mysql
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h localhost -uroot -p$$MYSQL_ROOT_PASSWORD"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend-v1:
    image: dockersrihari578/eschool-app:v1
    container_name: eschool-app-v1
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/${MYSQL_DATABASE}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
      SPRING_DATASOURCE_USERNAME: ${MYSQL_USER}
      SPRING_DATASOURCE_PASSWORD: ${MYSQL_PASSWORD}
      SPRING_PROFILES_ACTIVE: docker
    ports:
      - "8080:8080"
    networks:
      - backend

  backend-v2:
    image: dockersrihari578/eschool-reports:v1
    container_name: eschool-reports-v2
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/${MYSQL_DATABASE}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
      SPRING_DATASOURCE_USERNAME: ${MYSQL_USER}
      SPRING_DATASOURCE_PASSWORD: ${MYSQL_PASSWORD}
      SPRING_PROFILES_ACTIVE: docker
    ports:
      - "9090:9090"
    networks:
      - backend

  angular-frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: angular-frontend
    restart: unless-stopped
    ports:
      - "4200:80"
    networks:
      - backend
    depends_on:
      - backend-v1
      - backend-v2

  backup:
    build:
      context: .
      dockerfile: Dockerfile.backup
    container_name: eschool-backup
    restart: unless-stopped
    volumes:
      - ./backups:/backups
      - ./scripts:/scripts
    env_file:
      - .env
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - backend

networks:
  backend:
    driver: bridge
```

---

## **5️⃣ Backup Setup**

### **5.1 Dockerfile.backup**

```dockerfile
FROM alpine:latest
RUN apk add --no-cache bash mysql-client

COPY scripts/backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh
RUN mkdir -p /backups

# Weekly backup: every Sunday at 2 AM
RUN echo "0 2 * * 0 /usr/local/bin/backup.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root

CMD ["crond","-f","-l","2"]
```

### **5.2 scripts/backup.sh**

```bash
#!/bin/bash
set -euo pipefail

CONTAINER_NAME="mysql"
DB_USER="${MYSQL_USER:-root}"
DB_PASSWORD="${MYSQL_PASSWORD:-root}"
DB_NAME="${MYSQL_DATABASE:-eschool}"
BACKUP_DIR="/backups"
DATE=$(date +%F_%H-%M-%S)

mkdir -p "$BACKUP_DIR"
echo "📦 Starting MySQL backup at $(date)..."

docker exec "$CONTAINER_NAME" \
  sh -c "exec mysqldump -u$DB_USER -p\$DB_PASSWORD $DB_NAME" > "$BACKUP_DIR/backup_$DATE.sql"

gzip "$BACKUP_DIR/backup_$DATE.sql"

echo "✅ Backup complete: $BACKUP_DIR/backup_$DATE.sql.gz"
```

* **Automatic weekly backup:** Runs Sunday 2 AM
* **Manual trigger:**

```bash
docker-compose run --rm backup
```

* **Backups stored in:** `./backups`

---

## **6️⃣ Start & Stop Scripts**

### **6.1 start-eschool.bat**

```bat
@echo off
SETLOCAL

where docker >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not installed.
    pause
    exit /b 1
)

where docker-compose >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Compose is not installed.
    pause
    exit /b 1
)

if not exist ".env" (
    echo ❌ .env file missing.
    pause
    exit /b 1
)

echo 🌐 Pulling latest images...
docker-compose pull

echo 🚀 Starting containers in detached mode...
docker-compose up -d

echo ✅ All services running:
echo Angular: http://localhost:4200
echo Backend V1: http://localhost:8080
echo Backend V2: http://localhost:9090
pause
ENDLOCAL
```

### **6.2 stop-eschool.bat**

```bat
@echo off
SETLOCAL

where docker-compose >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Compose is not installed.
    pause
    exit /b 1
)

echo 🛑 Stopping containers...
docker-compose down

echo ✅ All containers stopped.
pause
ENDLOCAL
```

> **Note:** Volumes are preserved, so MySQL and backup data remain intact.

---

## **7️⃣ Angular Dockerfile**

```dockerfile
# Build stage
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Serve with Nginx
FROM nginx:alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/login-angular18-spring-boot-integration/browser/ /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## **8️⃣ Notes / Tips**

1. **Volumes** keep data safe across restarts. Don’t use `docker-compose down -v` unless you want to reset everything.
2. **Environment variables** only affect MySQL on **first container run**.
3. **Manual backup** is available anytime using:

```bash
docker-compose run --rm backup
```

4. **Client workflow**:

* Double-click `start-eschool.bat` → services start
* Access Angular frontend: `http://localhost:4200`
* Access backend APIs: `http://localhost:8080` and `http://localhost:9090`
* Weekly backup runs automatically
* Double-click `stop-eschool.bat` → stops all services safely

---

✅ This is now a **full complete guide** for your Docker Eschool project, ready to hand over to a client or team.

---

If you want, I can also make a **single-page diagram** showing **all services, ports, volumes, and backup flow**, so your client can **visualize everything at a glance**.

Do you want me to make that diagram?
