@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM Check if docker is available
where docker >nul 2>&1
if errorlevel 1 (
  echo Docker is not installed or not in PATH.
  pause
  exit /b 1
)

REM Check if docker-compose is available
where docker-compose >nul 2>&1
if errorlevel 1 (
  echo Docker Compose is not installed or not in PATH.
  pause
  exit /b 1
)

REM Check if .env file exists
if not exist ".env" (
  echo .env file not found in the current directory.
  pause
  exit /b 1
)

echo Pulling latest images...
docker-compose pull

echo Starting containers in detached mode...
docker-compose up -d

:end
echo All services are up and running successfully!
pause
ENDLOCAL
