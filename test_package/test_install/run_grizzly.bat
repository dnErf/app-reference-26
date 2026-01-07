@echo off
REM Grizzly Database Launcher for Windows
REM Double-click this file to start the database demo

echo ==========================================
echo         Grizzly Database Demo
echo ==========================================
echo.
echo Starting the Grizzly columnar database...
echo This will show you how to interact with the database
echo just like SQLite or DuckDB!
echo.
echo Press any key to continue...
pause > nul

REM Check if we're in the right directory
if not exist "griz.exe" (
    echo Error: griz.exe not found in current directory
    echo Please make sure you're running this from the Grizzly database folder
    echo.
    echo Press any key to exit...
    pause > nul
    exit /b 1
)

REM Run the demo
echo.
echo Launching Grizzly Database REPL...
echo.
griz.exe

echo.
echo ==========================================
echo         Demo Complete!
echo ==========================================
echo.
echo The Grizzly database successfully demonstrated:
echo • Loading sample data (Alice, Bob, Charlie)
echo • Running SQL-like queries
echo • Columnar data processing
echo.
echo This is a high-performance database built with Mojo,
echo similar to modern analytical databases like DuckDB.
echo.
echo Press any key to exit...
pause > nul