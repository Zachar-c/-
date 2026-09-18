### Task 2: 编写 `Dockerfile`

**Files:**
- Create: `Dockerfile`

**Interfaces:**
- Consumes: `pom.xml`, `src/main/`（Maven 阶段自动编译）
- Produces: 镜像内 `/app/fortune-app-1.8.0.jar`，启动命令 `java -jar /app/fortune-app-1.8.0.jar`

- [ ] **Step 1: 编写 Dockerfile**

```dockerfile
# 阶段 1：编译并打包 uber-jar
FROM maven:3.9.9-eclipse-temurin-11-alpine AS builder

WORKDIR /build
COPY pom.xml .
COPY src ./src

RUN mvn -B clean package -DskipTests

# 阶段 2：仅保留 JRE 运行
FROM eclipse-temurin:11-jre-alpine

WORKDIR /app

# 创建非 root 用户运行应用
RUN addgroup -S fortune && adduser -S fortune -G fortune

# 拷贝构建产物
COPY --from=builder /build/target/fortune-app-1.8.0.jar app.jar

# 数据目录由 docker-compose 挂载，这里创建并赋权
RUN mkdir -p /app/data /app/logs && chown -R fortune:fortune /app

USER fortune

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

- [ ] **Step 2: 本地构建镜像并验证能运行**

Run:

```bash
# 构建
docker build -t fortune-app:local .

# 运行（前台测试 10 秒）
docker run --rm -p 8080:8080 -v "$(pwd)/data:/app/data" fortune-app:local &
PID=$!
sleep 10
curl -s http://localhost:8080/fortune | head -c 200
echo
kill $PID
```

Expected:

```text
# curl 输出应包含 JSON，例如
{"text":"...","level":...}
```

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat: add multi-stage Dockerfile"
```
