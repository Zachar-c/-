#!/bin/bash
set -e

PORT=8080
JAR_NAME=target/fortune-app-1.0.0.jar
MVND=/c/DevEnv/04_Language_Envs/Java/maven-mvnd-1.0.6-windows-amd64/bin/mvnd.exe

echo "🔍 检查端口 $PORT ..."
PID=$(netstat -ano | grep "0.0.0.0:$PORT" | awk '{print $5}' | head -n 1)

if [ -n "$PID" ]; then
    echo "🛑 杀掉旧进程 PID=$PID"
    cmd //c taskkill //PID $PID //F
else
    echo "✅ 端口 $PORT 空闲"
fi

echo "🔨 Maven 打包 ..."
$MVND clean package -q

echo "🚀 启动服务 ..."
java -Dfile.encoding=UTF-8 -jar $JAR_NAME &

echo "⏳ 等待服务就绪 ..."
sleep 3

echo "🧪 测试接口 ..."
curl -s http://localhost:$PORT/fortune/count && echo

echo "✨ 完成！服务运行在 http://localhost:$PORT/fortune"
