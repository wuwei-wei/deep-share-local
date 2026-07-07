@echo off
chcp 65001 >nul
title DeepShare Local Server - 一键安装
cd /d "%~dp0"

echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║     DeepShare Local DOCX Server - 一键安装程序      ║
echo ╚══════════════════════════════════════════════════════╝
echo.

REM ── Step 1: Check Python ──────────────────────────────
echo [1/4] 检查 Python 环境...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo   [✗] 未检测到 Python
    echo.
    echo   正在尝试通过 winget 自动安装 Python 3.12...
    winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements -q
    if %errorlevel% neq 0 (
        echo   [✗] 自动安装失败，请手动安装：
        echo       https://www.python.org/downloads/
        echo   ※ 安装时务必勾选 "Add Python to PATH"
        pause
        exit /b 1
    )
    echo   [✓] Python 安装完成
    echo   ※ 请重新打开此脚本以继续
    pause
    exit /b 0
)
for /f "tokens=2" %%i in ('python --version 2^>^&1') do echo   [✓] 已检测到 Python %%i

REM ── Step 2: Check Pandoc ──────────────────────────────
echo.
echo [2/4] 检查 Pandoc 环境...

REM First check if already in PATH
where pandoc >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('pandoc --version 2^>^&1 ^| findstr /r "^pandoc"') do echo   [✓] 已检测到 Pandoc - %%i
    goto :install_deps
)

REM Check common install locations
if exist "%LOCALAPPDATA%\Pandoc\pandoc.exe" (
    set "PATH=%LOCALAPPDATA%\Pandoc;%PATH%"
    echo   [✓] 已在 %LOCALAPPDATA%\Pandoc\ 找到 Pandoc
    goto :install_deps
)
if exist "C:\Program Files\Pandoc\pandoc.exe" (
    set "PATH=C:\Program Files\Pandoc;%PATH%"
    echo   [✓] 已在 C:\Program Files\Pandoc\ 找到 Pandoc
    goto :install_deps
)

REM Not found — try auto-install
echo   [✗] 未检测到 Pandoc
echo.
echo   正在通过 winget 自动安装 Pandoc...

winget install Pandoc.Pandoc --accept-package-agreements --accept-source-agreements -q
if %errorlevel% neq 0 (
    echo   [✗] 自动安装失败
    echo.
    echo   请手动安装 Pandoc：
    echo       https://pandoc.org/installing.html
    echo   ※ 下载 .msi 文件，双击安装即可
    echo.
    echo   安装完成后重新运行本脚本。
    pause
    exit /b 1
)

REM Refresh PATH and copy pandoc to known location for server.py fallback
for /f "tokens=*" %%i in ('where pandoc 2^>nul') do echo   [✓] Pandoc 安装完成: %%i
if %errorlevel% neq 0 (
    set "PATH=%LOCALAPPDATA%\Pandoc;%PATH%"
)

:install_deps

REM ── Step 3: Install Python dependencies ───────────────
echo.
echo [3/4] 安装 Python 依赖...

pip install -r requirements.txt -q 2>&1
if %errorlevel% neq 0 (
    echo   [✗] 依赖安装失败，尝试不使用静默模式...
    pip install -r requirements.txt
    if %errorlevel% neq 0 (
        echo   [✗] 安装失败，请检查网络连接后重试
        pause
        exit /b 1
    )
)
echo   [✓] Python 依赖安装完成

REM ── Step 4: Generate reference template ───────────────
echo.
echo [4/4] 生成 Word 参考模板...

if not exist "templates\reference.docx" (
    pandoc -o "templates\reference.docx" --print-default-data-file reference.docx >nul 2>&1
    if %errorlevel% equ 0 (
        echo   [✓] 参考模板已生成: templates\reference.docx
    ) else (
        echo   [!] 模板生成失败（不影响使用，将使用 Pandoc 默认样式）
    )
) else (
    echo   [✓] 参考模板已存在: templates\reference.docx
)

REM ── Done ──────────────────────────────────────────────
echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║              ✓  安装完成！                           ║
echo ╚══════════════════════════════════════════════════════╝
echo.
echo   启动方式:
echo     方式 1 - 双击 start.bat
echo     方式 2 - 在此目录执行: python server.py
echo.
echo   启动后，在 DeepShare 扩展中设置:
echo     Server URL: http://localhost:5050
echo     API Key:    任意填写（本地不验证）
echo.
echo   现在启动服务吗？(Y/N)

choice /c YN /n /m "  "
if errorlevel 2 goto :end
if errorlevel 1 (
    echo.
    echo   正在启动服务...
    start "DeepShare Local Server" /min cmd /c "set PATH=%LOCALAPPDATA%\Pandoc;%PATH% && python "%~dp0server.py""
    echo   [✓] 服务已在后台启动（最小化窗口）
    echo   ※ 如需停止服务，在任务栏找到该窗口关闭即可
    echo.
    timeout /t 3 >nul
    start http://localhost:5050/templates
)

:end
echo.
pause
