#!/bin/bash
set -e

PORT=8080

echo "🔍 检查端口 $PORT ..."
PID=$(netstat -ano | grep "0.0.0.0:$PORT" | awk '{print $5}' | head -n 1)

if [ -n "$PID" ]; then
    echo "🛑 杀掉旧进程 PID=$PID"
    cmd //c taskkill //PID $PID //F
else
    echo "✅ 端口 $PORT 空闲"
fi

echo "🔨 编译项目 ..."
javac -encoding UTF-8 Main.java controller/*.java service/*.java model/*.java

echo "🚀 启动服务 ..."
java -Dfile.encoding=UTF-8 Main &

echo "⏳ 等待服务就绪 ..."
sleep 2

echo "🧪 测试接口 ..."
curl -s http://localhost:$PORT/fortune/count && echo

echo "✨ 完成！服务运行在 http://localhost:$PORT/fortune"
