# poster-pansou-dist 一键发布到 GitHub
# 用法（在 P:\影视\影视获取 目录下 PowerShell 执行）：
#   .\poster-pansou-dist\publish-to-github.ps1
# 首次会要求输入 GitHub 用户名 + Personal Access Token。

$ErrorActionPreference = 'Stop'
$RepoDir = 'P:\影视\影视获取\poster-pansou-dist'
$RepoUrl = 'https://github.com/你的用户名/poster-pansou-dist.git'   # ← 发布前改这一行

if (-not (Test-Path $RepoDir)) {
    Write-Host "ERR: 找不到 $RepoDir" -ForegroundColor Red
    exit 1
}
Set-Location $RepoDir

# 1. 检查 git
$git = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $git) {
    Write-Host "ERR: git 未安装" -ForegroundColor Red
    exit 1
}

# 2. 输入凭证（首次）
Write-Host "=== GitHub 发布向导 ===" -ForegroundColor Cyan
$username = Read-Host "GitHub 用户名"
$token    = Read-Host "Personal Access Token (https://github.com/settings/tokens, 勾选 repo 权限)" -AsSecureString
$plain    = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))

# 3. init / commit
if (-not (Test-Path .git)) {
    git init -b main
    git config user.name  $username
    git config user.email "$username@users.noreply.github.com"
}
git add .
$status = git status --porcelain
if ($status) {
    git commit -m "Initial dist: install/docker-compose/source-free"
} else {
    Write-Host "没有变更需要提交" -ForegroundColor Yellow
}

# 4. 加 remote + push（用 token 鉴权）
$authUrl = "https://${username}:${plain}@github.com/${username}/poster-pansou-dist.git"
git remote remove origin 2>$null
git remote add origin $authUrl
git push -u origin main --force

# 5. 清掉 remote 里的 token（保留 .git/config 干净）
git remote set-url origin "https://github.com/${username}/poster-pansou-dist.git"
Remove-Variable plain -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== 完成 ===" -ForegroundColor Green
Write-Host "仓库地址: https://github.com/$username/poster-pansou-dist"
Write-Host ""
Write-Host "下一步（在你已经创建好空 GitHub 仓库后）：" -ForegroundColor Yellow
Write-Host "  1. 打开 https://github.com/$username/poster-pansou-dist"
Write-Host "  2. 在 Settings -> Secrets and variables -> Actions 加 PAT_TOKEN"
Write-Host "     (PAT 需勾选 poster-pansou 私有仓库读权限)"
Write-Host "  3. 打 tag 触发 Release 构建: git tag v0.43.11-r232-member-gate-no-flash; git push --tags"