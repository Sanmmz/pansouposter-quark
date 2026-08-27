# poster-pansou 公开分发版

> 本仓库**不含任何业务源码**。所有逻辑均封装在预构建的 Docker 镜像内，
> 维护者通过 [GitHub Releases](https://github.com/你的用户名/poster-pansou-dist/releases)
> 发布二进制镜像 tarball，用户一键安装。

---

## 给最终用户：你只需 3 步

### 1. 准备环境

- Linux / macOS / Windows + WSL2
- 已安装 **Docker Engine 20.10+** 和 **Docker Compose v2**（`docker compose` 命令可用）

### 2. 一键安装

**Linux / macOS / WSL:**
```bash
git clone https://github.com/你的用户名/poster-pansou-dist.git
cd poster-pansou-dist
bash install.sh
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/你的用户名/poster-pansou-dist.git
cd poster-pansou-dist
.\install.bat
```

### 3. 完成

脚本会自动：
1. 从 GitHub Releases 下载最新版本的 `poster-pansou-<版本>-docker.tar`
2. `docker load` 导入镜像
3. `docker compose up -d` 启动
4. 等待健康检查通过
5. 打印访问 URL（默认 `http://127.0.0.1:17001`）

整个过程不需要 Python，不需要 Node，不需要任何源代码。

---

## 目录说明

```
poster-pansou-dist/                  ← 本仓库（公开）
├── README.md                        ← 你正在看
├── docker-compose.yml               ← Docker Compose 配置（用户启动入口）
├── install.sh                       ← Linux/macOS 一键安装
├── install.bat                      ← Windows 一键安装
├── .gitignore                       ← 防止误提交本地构建产物
└── .github/workflows/release.yml    ← 维护者用：推送 tag → 自动构建 + Release

poster-pansou/                      ← 私有源（不上传 GitHub）
├── server.py             ← 业务源码（核心实现）
├── static/              ← 前端静态资源
├── config/              ← 配置模板
├── Dockerfile.dist      ← 镜像构建配方（私有源使用）
├── scripts/             ← 构建脚本
└── ...
```

---

## 升级

```bash
cd poster-pansou-dist
git pull                  # 拉取最新 docker-compose.yml / install.sh
bash install.sh --upgrade # 自动下载新版本镜像 + 重启容器（数据保留）
```

---

## 卸载

```bash
cd poster-pansou-dist
docker compose down       # 停止容器
rm -rf db/                # 删除数据（可选）
```

---

## 配置

镜像默认监听 `17001`（主端口）和 `8024`（网关端口）。可通过编辑
`docker-compose.yml` 顶部的 `ports:` 修改。

数据卷：`./db`（首次运行自动创建）。删除容器不会丢失数据，
删除整个 `./db` 才会清除所有数据。

---

## 故障排查

| 现象 | 可能原因 | 解决方法 |
|---|---|---|
| `install.sh` 下载 tarball 失败 | 网络无法访问 GitHub | 配置 HTTP 代理或使用 VPN 后重试 |
| `docker compose up -d` 后立刻退出 | 端口 17001/8024 已被占用 | 编辑 `docker-compose.yml` 的 ports |
| 浏览器访问无响应 | 容器健康检查未通过 | `docker compose logs` 看启动日志 |
| 提示 "no such image" | tarball 损坏或版本不匹配 | `docker images`  | 看 `poster-pansou` 镜像是否存在 |

---

## 安全说明

本仓库**不包含**：
- ❌ `server.py`（业务核心）
- ❌ `static/`（前端资源）
- ❌ `config/`（配置模板）
- ❌ 任何 `.py` / `.pyc` / `.js`（除了 install 脚本）

唯一可执行的是：
- ✅ `docker-compose.yml`：编排已构建好的镜像
- ✅ `install.sh` / `install.bat`：从官方 GitHub Releases 下载并加载
- ✅ `.github/workflows/release.yml`：维护者自动构建流水线

镜像本身的业务逻辑被 PyInstaller 编译 + 多阶段 Docker 编译双重保护，
即使有人能从镜像中提取出二进制，源码也是不可读的。