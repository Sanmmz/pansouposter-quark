#!/usr/bin/env bash
# poster-pansou 用户一键安装脚本（Linux / macOS / WSL）
#
# 流程：
#   1. 探测环境（docker / docker compose）
#   2. 从 GitHub Releases 下载最新版本的镜像 tarball
#   3. docker load 导入镜像
#   4. docker compose up -d
#   5. 等待健康检查通过，打印访问 URL
#
# 维护者：把 IMAGE_VERSION 改成与 Release tag 一致（或留空自动取 latest）

set -euo pipefail

# ====== 可配置项（用户可通过环境变量覆盖）======
GITHUB_REPO="${GITHUB_REPO:-你的用户名/poster-pansou-dist}"   # 修改成你的 GitHub 仓库
IMAGE_NAME="${IMAGE_NAME:-poster-pansou}"
IMAGE_VERSION="${IMAGE_VERSION:-}"                          # 留空则自动取 latest release
HOST_PORT="${HOST_PORT:-17001}"
HOST_GATEWAY_PORT="${HOST_GATEWAY_PORT:-8024}"
# ============================================

# 颜色输出
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
say()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

# 探测 docker
if ! command -v docker >/dev/null 2>&1; then
    err "Docker 未安装。请先安装 Docker Engine 20.10+："
    err "  Linux: https://docs.docker.com/engine/install/"
    err "  macOS: https://docs.docker.com/desktop/install/macinstall/"
    exit 1
fi
say "Docker 已安装: $(docker --version)"

# 探测 docker compose v2
if ! docker compose version >/dev/null 2>&1; then
    err "未检测到 docker compose v2（需要 Docker Desktop 或 docker-compose-plugin）"
    exit 1
fi
say "Docker Compose v2: $(docker compose version --short)"

# 自动取最新版本
if [[ -z "$IMAGE_VERSION" ]]; then
    warn "未指定 IMAGE_VERSION，自动获取 GitHub 最新 release ..."
    IMAGE_VERSION="$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
        | grep -oE '"tag_name":\s*"v?[^"]+"' | head -1 | sed -E 's/.*"v?([^"]+)".*/\1/')"
    if [[ -z "$IMAGE_VERSION" ]]; then
        err "无法获取最新版本，请手动指定 IMAGE_VERSION=vX.Y.Z"
        exit 1
    fi
    say "最新版本: $IMAGE_VERSION"
fi

# 查找已加载的镜像
NEED_DOWNLOAD=1
if docker image inspect "${IMAGE_NAME}:${IMAGE_VERSION}" >/dev/null 2>&1; then
    warn "镜像 ${IMAGE_NAME}:${IMAGE_VERSION} 已存在，跳过下载"
    NEED_DOWNLOAD=0
fi

# 下载并加载 tarball
if [[ "$NEED_DOWNLOAD" -eq 1 ]]; then
    TARBALL="poster-pansou-${IMAGE_VERSION}-docker.tar"
    TARBALL_URL="https://github.com/${GITHUB_REPO}/releases/download/v${IMAGE_VERSION}/${TARBALL}"

    echo
    say "下载镜像: $TARBALL_URL"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT

    if ! curl -fL --retry 3 --connect-timeout 15 \
            -o "${TMP}/${TARBALL}" "$TARBALL_URL"; then
        err "下载失败。可能是以下原因："
        err "  1. 网络无法访问 GitHub"
        err "  2. Release v${IMAGE_VERSION} 不存在（去仓库 Releases 页面核对）"
        err "  3. 文件名不是 ${TARBALL}（请修改本脚本的 TARBALL 变量）"
        exit 1
    fi

    say "导入镜像到 Docker ..."
    docker load -i "${TMP}/${TARBALL}"
fi

# 准备 docker-compose 用的环境
export IMAGE_NAME IMAGE_VERSION HOST_PORT HOST_GATEWAY_PORT
[[ -f .env ]] || cat > .env <<EOF
IMAGE_NAME=${IMAGE_NAME}
IMAGE_VERSION=${IMAGE_VERSION}
HOST_PORT=${HOST_PORT}
HOST_GATEWAY_PORT=${HOST_GATEWAY_PORT}
EOF
mkdir -p db

# 启动
echo
say "启动容器 ..."
docker compose up -d

# 等待健康检查
echo
say "等待健康检查 ..."
for i in {1..30}; do
    if curl -fsS --max-time 3 "http://127.0.0.1:${HOST_PORT}/api/health" >/dev/null 2>&1; then
        echo
        say "============================================="
        say " 安装完成！"
        say "============================================="
        say " 访问地址: http://127.0.0.1:${HOST_PORT}"
        say " 网关端口: ${HOST_GATEWAY_PORT}"
        say ""
        say " 数据目录: $(pwd)/db"
        say " 日志查看: docker compose logs -f"
        say " 停止服务: docker compose down"
        say " 升级版本: bash install.sh （自动取最新 release）"
        exit 0
    fi
    sleep 2
done

err "健康检查超时（60s）。请运行 'docker compose logs' 查看启动日志"
exit 1