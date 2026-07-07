@echo off
title DeepShare Local DOCX Server
cd /d "%~dp0"

REM Add Pandoc to PATH if installed in default user location
if exist "%LOCALAPPDATA%\Pandoc\pandoc.exe" (
    set "PATH=%LOCALAPPDATA%\Pandoc;%PATH%"
    echo [OK] Pandoc found at %LOCALAPPDATA%\Pandoc\
) else if exist "C:\Program Files\Pandoc\pandoc.exe" (
    set "PATH=C:\Program Files\Pandoc;%PATH%"
    echo [OK] Pandoc found at C:\Program Files\Pandoc\
)

echo Starting DeepShare Local DOCX Server...
echo.
python server.py
pause
