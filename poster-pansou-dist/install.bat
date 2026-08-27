@echo off
REM poster-pansou 用户一键安装脚本（Windows 原生 / PowerShell / cmd）
REM
REM 流程：
REM   1. 探测 docker
REM   2. 从 GitHub Releases 下载最新版本的镜像 tarball
REM   3. docker load 导入镜像
REM   4. docker compose up -d
REM   5. 等待健康检查通过，打印访问 URL

setlocal enableextensions enabledelayedexpansion

REM ====== 可配置项（用户可通过环境变量覆盖）======
if not defined GITHUB_REPO set "GITHUB_REPO=Sanmmz/pansouposter-quark"
if not defined IMAGE_NAME set "IMAGE_NAME=poster-pansou"
if not defined IMAGE_VERSION set "IMAGE_VERSION="
if not defined HOST_PORT set "HOST_PORT=17001"
if not defined HOST_GATEWAY_PORT set "HOST_GATEWAY_PORT=8024"
REM ============================================

REM 探测 docker
where docker >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Docker 未安装。请先安装 Docker Desktop for Windows：
    echo         https://docs.docker.com/desktop/install/windowsinstall/
    exit /b 1
)
echo [OK] Docker: 
docker --version

docker compose version >nul 2>nul
if errorlevel 1 (
    echo [ERROR] 未检测到 docker compose v2。请升级 Docker Desktop。
    exit /b 1
)
echo [OK] Docker Compose: 
docker compose version --short

REM 自动取最新版本
if "%IMAGE_VERSION%"=="" (
    echo [INFO] 自动获取 GitHub 最新 release ...
    REM 用 PowerShell 调 GitHub API 拿 tag_name，再去掉前导 v
    for /f "tokens=*" %%t in ('powershell -NoProfile -Command "$r=(Invoke-RestMethod 'https://api.github.com/repos/%GITHUB_REPO%/releases/latest');$r.tag_name -replace '^v',''"') do (
        set "IMAGE_VERSION=%%t"
    )
    if "%IMAGE_VERSION%"=="" (
        echo [ERROR] 无法获取最新版本，请手动指定 IMAGE_VERSION=vX.Y.Z
        exit /b 1
    )
)
echo [OK] 版本: %IMAGE_VERSION%

REM 探测镜像是否已存在
docker image inspect "%IMAGE_NAME%:%IMAGE_VERSION%" >nul 2>nul
if not errorlevel 1 (
    echo [INFO] 镜像 %IMAGE_NAME%:%IMAGE_VERSION% 已存在，跳过下载
    goto :run_compose
)

REM 下载 tarball
set "TARBALL=poster-pansou-%IMAGE_VERSION%-docker.tar"
set "TARBALL_URL=https://github.com/%GITHUB_REPO%/releases/download/v%IMAGE_VERSION%/%TARBALL%"
echo [INFO] 下载: %TARBALL_URL%

REM Windows 没有 mktemp；用 %TEMP%
set "TMPDIR=%TEMP%\poster-pansou-%RANDOM%"
mkdir "%TMPDIR%" 2>nul

curl -fL --retry 3 --connect-timeout 15 -o "%TMPDIR%\%TARBALL%" "%TARBALL_URL%"
if errorlevel 1 (
    echo [ERROR] 下载失败。可能原因：
    echo         1. 网络无法访问 GitHub
    echo         2. Release v%IMAGE_VERSION% 不存在
    echo         3. 文件名不是 %TARBALL%
    rmdir /s /q "%TMPDIR%" 2>nul
    exit /b 1
)

echo [INFO] 导入镜像到 Docker ...
docker load -i "%TMPDIR%\%TARBALL%"

:run_compose
REM 写 .env（如果用户没有）
if not exist .env (
    (
        echo IMAGE_NAME=%IMAGE_NAME%
        echo IMAGE_VERSION=%IMAGE_VERSION%
        echo HOST_PORT=%HOST_PORT%
        echo HOST_GATEWAY_PORT=%HOST_GATEWAY_PORT%
    ) > .env
)
if not exist db mkdir db

echo [INFO] 启动容器 ...
docker compose up -d

echo [INFO] 等待健康检查 ...
set /a count=0
:healthcheck_loop
set /a count+=1
if %count% gtr 30 (
    echo [ERROR] 健康检查超时（60s）。请运行 docker compose logs 查看启动日志
    exit /b 1
)
curl -fsS --max-time 3 "http://127.0.0.1:%HOST_PORT%/api/health" >nul 2>nul
if not errorlevel 1 goto :health_ok
timeout /t 2 /nobreak >nul
goto :healthcheck_loop

:health_ok
echo.
echo =============================================
echo  安装完成！
echo =============================================
echo  访问地址: http://127.0.0.1:%HOST_PORT%
echo  网关端口: %HOST_GATEWAY_PORT%
echo  数据目录: %CD%\db
echo  日志查看: docker compose logs -f
echo  停止服务: docker compose down
echo  升级版本: 重新运行 install.bat

endlocal