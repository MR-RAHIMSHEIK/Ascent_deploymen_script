@echo off
SETLOCAL

REM --- Check for Docker Compose ---
where docker-compose >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Compose is not installed or not in PATH.
    pause
    exit /b 1
)

echo 🛑 Stopping all containers...
docker-compose down

if errorlevel 1 (
    echo ❌ Failed to stop containers. Check Docker logs.
    pause
    exit /b 1
)

echo ✅ All containers stopped successfully.
pause

ENDLOCAL
