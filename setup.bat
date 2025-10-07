@echo off
echo ========================================
echo Tap Battle Arena - Setup Script
echo ========================================
echo.

echo [1/5] Installing Elixir dependencies...
call mix deps.get
if %errorlevel% neq 0 (
    echo ERROR: Failed to install Elixir dependencies
    exit /b 1
)
echo.

echo [2/5] Installing Node.js dependencies...
cd assets
call npm install
cd ..
if %errorlevel% neq 0 (
    echo ERROR: Failed to install Node.js dependencies
    exit /b 1
)
echo.

echo [3/5] Creating database...
call mix ecto.create
if %errorlevel% neq 0 (
    echo WARNING: Database might already exist or PostgreSQL is not running
    echo Please ensure PostgreSQL is running and credentials are correct
)
echo.

echo [4/5] Running migrations...
call mix ecto.migrate
if %errorlevel% neq 0 (
    echo ERROR: Failed to run migrations
    exit /b 1
)
echo.

echo [5/5] Compiling assets...
call mix assets.deploy
if %errorlevel% neq 0 (
    echo WARNING: Asset compilation had issues, but continuing...
)
echo.

echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo To start the server, run:
echo     mix phx.server
echo.
echo Then open your browser to:
echo     http://localhost:4000
echo.
echo ========================================
