#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[1/3] 编译 FortuneServer.java..."
javac FortuneServer.java

echo "[2/3] 停止旧的 FortuneServer 进程..."
for pid in $(jps -l | awk '/FortuneServer/{print $1}'); do
    echo "    终止 PID $pid"
    kill -f "$pid" 2>/dev/null || true
done

# 等待端口释放
sleep 1

echo "[3/3] 启动新的 FortuneServer..."
nohup java FortuneServer > fortune-server.log 2>&1 &

echo "✅ 服务已启动，访问: http://localhost:8080/fortune"
echo "📝 日志文件: $SCRIPT_DIR/fortune-server.log"
