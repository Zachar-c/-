#!/usr/bin/env bash
set -euo pipefail

# 使用方式：
#   SERVER_HOST=1.2.3.4 SERVER_USER=ubuntu REMOTE_DIR=/opt/fortune-app ./deploy.sh
# 前置条件：
#   - 本地已配置好到服务器的 SSH 免密登录
#   - 远程服务器已安装 Docker 和 Docker Compose v2

SERVER_HOST="${SERVER_HOST:?请设置环境变量 SERVER_HOST}"
SERVER_USER="${SERVER_USER:?请设置环境变量 SERVER_USER}"
REMOTE_DIR="${REMOTE_DIR:?请设置环境变量 REMOTE_DIR}"

echo "🚀 开始部署到 ${SERVER_USER}@${SERVER_HOST}:${REMOTE_DIR}"

# 1. 确保本地 jar 已构建
if [[ ! -f target/fortune-app-1.8.0.jar ]]; then
    echo "📦 正在本地构建 jar..."
    mvn -B clean package -DskipTests
fi

# 2. 在远程创建目录
ssh "${SERVER_USER}@${SERVER_HOST}" "mkdir -p ${REMOTE_DIR}/data ${REMOTE_DIR}/logs"

# 3. 上传必要文件
scp target/fortune-app-1.8.0.jar Dockerfile docker-compose.yml \
    "${SERVER_USER}@${SERVER_HOST}:${REMOTE_DIR}/"

# 4. 远程构建并启动
ssh "${SERVER_USER}@${SERVER_HOST}" << EOF
    cd ${REMOTE_DIR}
    docker compose down || true
    docker compose up --build -d
    docker compose ps
EOF

echo "✅ 部署完成：http://${SERVER_HOST}:8080"
