# 维护者发布指南

本文件给维护者（也就是你）看的，告诉如何把 `poster-pansou/` 私有源仓库
变成 GitHub 上 `poster-pansou-dist/` 公开仓库可用的发布产物。

## 整体流程

```
poster-pansou/  (私有源，本地)
   ↓ git tag v0.43.11-r232-member-gate-no-flash
   ↓ git push
GitHub Actions (.github/workflows/release.yml 在 poster-pansou-dist)
   ↓ checkout 私有源
   ↓ docker build (multi-stage)
   ↓ docker save -> tarball
   ↓ 创建 Release，上传资产
poster-pansou-dist/releases/v0.43.11-.../poster-pansou-...-docker.tar
   ↓ 用户从 GitHub Releases 下载
最终用户 → docker load → docker compose up
```

## 仓库布局（推荐）

| 仓库 | 公开性 | 内容 | 用途 |
|---|---|---|---|
| `poster-pansou` | 私有 | server.py、static/、config/、Dockerfile、scripts/ | 源码开发 |
| `poster-pansou-dist` | 公开 | Dockerfile.dist、docker-compose.yml、install.sh/.bat、release.yml、README.md | 用户分发 |
| `ghcr.io/<user>/poster-pansou` | 公开镜像 | 编译后的 Docker 镜像 | docker pull 用户 |

## 一次性初始化

### 步骤 A：把源码推到私有 GitHub 仓库

```bash
# 1. 在 GitHub 网页创建私有仓库：poster-pansou（勾选 Private）

# 2. 把本地源码推上去
cd P:\影视\影视获取\poster-pansou
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/Sanmmz/pansouposter-quark-source.git
git branch -M main
git push -u origin main
```

### 步骤 B：在 GitHub 创建公开仓库 poster-pansou-dist

```bash
# 1. 在 GitHub 网页创建公开仓库：poster-pansou-dist（Public，不要勾选 README）

# 2. 把 poster-pansou-dist 目录推上去
cd P:\影视\影视获取\poster-pansou-dist
git init
git add .
git commit -m "Initial dist repo (no source)"
git remote add origin https://github.com/Sanmmz/pansouposter-quark.git
git branch -M main
git push -u origin main
```

### 步骤 C：在 GitHub 上设置 Actions 密钥

进入 `poster-pansou-dist` 仓库 → Settings → Secrets and variables → Actions：

| 名称 | 类型 | 用途 |
|---|---|---|
| `PAT_TOKEN` | Personal Access Token | 用于 release.yml checkout 私有源 `poster-pansou` 仓库 |

创建 PAT：GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
- 资源所有者：你自己的账号
- 仓库访问：仅勾选 `poster-pansou`（私有源）
- 权限：Contents 读权限

## 每次发布新版本

### 步骤 1：在 poster-pansou 私有源 bump 版本号

编辑 `server.py` 顶部 `APP_VERSION = '...'`：
```python
APP_VERSION = '0.43.12-r233-your-new-version'
```

### 步骤 2：提交并打 tag

```bash
cd P:\影视\影视获取\poster-pansou
git add server.py
git commit -m "Bump to 0.43.12-r233-your-new-version"
git tag v0.43.12-r233-your-new-version
git push origin main
git push origin v0.43.12-r233-your-new-version
```

### 步骤 3：等待 Actions 自动构建

进入 `poster-pansou-dist` 仓库 → Actions → build-and-release workflow

流水线会自动：
1. ✅ checkout 私有源 `poster-pansou`
2. ✅ docker build（multi-stage，源码不进入最终镜像）
3. ✅ 导出 tarball
4. ✅ 创建 GitHub Release，上传 `poster-pansou-<VER>-docker.tar`
5. ✅ 推送镜像到 ghcr.io

### 步骤 4：在 `poster-pansou-dist` 同步更新默认版本号

如果新版本号是用户希望的"默认"（不再自动 latest），修改：

`docker-compose.yml`:
```yaml
image: ${IMAGE_NAME:-poster-pansou}:${IMAGE_TAG:-你的新版本号}
```

`install.sh` / `install.bat`：可改 `IMAGE_VERSION` 默认值（可选，留空则自动取 latest）。

提交：
```bash
cd P:\影视\影视获取\poster-pansou-dist
git add docker-compose.yml install.sh install.bat
git commit -m "Bump default version to 0.43.12-r233-your-new-version"
git push
```

## 验证 release 产物

发布完成后，验证 tarball 真的不含源码：

```bash
cd /tmp
wget https://github.com/Sanmmz/pansouposter-quark/releases/download/v<VER>/poster-pansou-<VER>-docker.tar
tar -tf poster-pansou-<VER>-docker.tar | grep -E '\.py$' | head -5
```

应当只看到 `app/server.pyc`，**不应有 `app/server.py`**。

## 用户安装命令（验证用户视角是否流畅）

```bash
docker rmi poster-pansou:0.43.12-r233-your-new-version 2>/dev/null
git clone https://github.com/Sanmmz/pansouposter-quark.git /tmp/test
cd /tmp/test
bash install.sh
# 验证：访问 http://127.0.0.1:17001 应返回主页
```

## 不使用 GitHub Actions 的备选（手动发布）

如果你不想用 Actions，可以本地手动发布：

```bash
cd P:\影视\影视获取\poster-pansou
git tag v0.43.12-r233-your-new-version
git push origin v0.43.12-r233-your-new-version

# 在本地 docker 环境构建
docker build -f Dockerfile.dist -t poster-pansou:0.43.12-r233-your-new-version --build-arg APP_VERSION=0.43.12-r233-your-new-version .
docker save -o poster-pansou-0.43.12-r233-your-new-version-docker.tar poster-pansou:0.43.12-r233-your-new-version

# 上传到 GitHub Releases（用 gh CLI 或网页手动上传）
gh release create v0.43.12-r233-your-new-version poster-pansou-0.43.12-r233-your-new-version-docker.tar --repo Sanmmz/pansouposter-quark
```