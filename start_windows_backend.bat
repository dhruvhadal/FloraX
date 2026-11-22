@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo  FloraX Windows Vision Backend (FastAPI + Keras/TensorFlow Grad-CAM)
echo =====================================================================

cd /d "%~dp0backend_vision"

:: 1. Activate Python Virtual Environment
if exist "venv\Scripts\activate.bat" (
    echo [FloraX] Activating Python virtual environment from venv...
    call "venv\Scripts\activate.bat"
) else if exist ".venv\Scripts\activate.bat" (
    echo [FloraX] Activating Python virtual environment from .venv...
    call ".venv\Scripts\activate.bat"
) else (
    echo [FloraX] No venv found. Creating venv...
    py -3.11 -m venv venv 2>nul || py -m venv venv 2>nul || python -m venv venv
    if exist "venv\Scripts\activate.bat" (
        call "venv\Scripts\activate.bat"
        echo [FloraX] Installing backend dependencies...
        pip install -r requirements.txt
    )
)

:: 2. Check and reverse ADB port for USB-connected Android devices
set "ADB_EXE=adb"
where adb >nul 2>nul
if %errorlevel% neq 0 (
    if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
        set "ADB_EXE=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
    ) else if exist "C:\Users\%USERNAME%\AppData\Local\Android\Sdk\platform-tools\adb.exe" (
        set "ADB_EXE=C:\Users\%USERNAME%\AppData\Local\Android\Sdk\platform-tools\adb.exe"
    )
)

"%ADB_EXE%" devices >nul 2>nul
if %errorlevel% equ 0 (
    echo [FloraX] Checking for connected Android devices via ADB...
    for /f "skip=1 tokens=1,2" %%A in ('"%ADB_EXE%" devices 2^>nul') do (
        if "%%B"=="device" (
            echo [FloraX] USB Android device detected (%%A). Setting up adb reverse tcp:8000 tcp:8000...
            "%ADB_EXE%" -s %%A reverse tcp:8000 tcp:8000
        )
    )
) else (
    echo [FloraX] Note: ADB tool not found on PATH or no USB device attached.
)

:: 3. Launch FastAPI backend on 0.0.0.0:8000
echo [FloraX] Starting FastAPI Grad-CAM Server on http://0.0.0.0:8000 ...
python -m uvicorn main:app --host 0.0.0.0 --port 8000

pause
