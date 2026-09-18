# Stage 6: 部署运维 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 fortune-app 容器化，加入本地 docker-compose 编排、GitHub Actions CI 流水线，并提供一台 Linux 服务器即可运行的部署脚本。

**Architecture:** 用 Maven shade 插件生成可执行 uber-jar，多阶段 Dockerfile 把 jar 打包进最小 JRE 镜像；docker-compose 把数据目录持久化到宿主机；GitHub Actions 在每次 push/PR 时自动 `mvn package` 并把 jar 作为 artifact 保存；部署脚本把构建产物传到远程服务器并用 docker compose 启动。

**Tech Stack:** Maven 3.9 + Eclipse Temurin JDK/JRE 11、Docker、Docker Compose v2、GitHub Actions、H2 文件数据库、bash。

## Global Constraints

- Java 版本：`maven.compiler.source` 和 `target` 均为 **11**
- 主类：`com.example.Main`
- 可执行 jar 路径：`target/fortune-app-1.8.0.jar`（shade plugin 生成）
- 默认端口：`8080`，可通过 `application.properties` 的 `server.port` 覆盖
- 默认数据库：`jdbc:h2:file:./data/fortune-db`，通过挂载 `./data` 持久化
- 所有新增文件路径保持项目已有约定，文档使用中文
- 不要在 Docker 镜像里提交真实凭据；敏感信息通过环境变量或外部挂载传入

---

## File Structure

| 文件 | 作用 |
|---|---|
| `.dockerignore` | 排除不需要进入 Docker build context 的文件，缩小镜像构建体积 |
| `Dockerfile` | 多阶段构建：Maven 阶段编译打包 → JRE 阶段运行 jar |
| `docker-compose.yml` | 本地/服务器一键启动 fortune-app 并持久化 H2 数据 |
| `.github/workflows/ci.yml` | GitHub Actions：编译、测试、打包、上传 jar artifact |
| `deploy.sh` | 把 jar + Docker 文件上传到服务器并远程启动服务 |
| `DEPLOY.md` | 部署运维使用说明，补充 `LEARNING.md` 阶段 6 内容 |
| `ROADMAP.md` | 更新阶段 6 子任务状态 |

---

### Task 1: 添加 `.dockerignore`

**Files:**
- Create: `.dockerignore`

**Interfaces:**
- Consumes: 无
- Produces: `.dockerignore` 被 Docker build context 读取

- [ ] **Step 1: 创建 `.dockerignore` 文件**

```text
# Git
.git
.gitignore

# Maven build output
target/

# IDE
.idea/
*.iml
.vscode/

# Runtime data (persisted via volume, not image)
data/
logs/

# Local env / docs not needed in image
*.md
.github/
docs/
```

- [ ] **Step 2: 验证 build context 大小**

Run:

```bash
docker build -t fortune-app:test-build . --no-cache 2>&1 | tail -n 5
```

Expected: 构建命令能正常开始（不会把 `target/` 或 `.git/` 传入 context）。

- [ ] **Step 3: Commit**

```bash
git add .dockerignore
git commit -m "chore: add .dockerignore to reduce build context"
```

---

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

---

### Task 3: 编写 `docker-compose.yml`

**Files:**
- Create: `docker-compose.yml`

**Interfaces:**
- Consumes: `Dockerfile`, `./data/` 目录
- Produces: 服务名 `fortune-app`，端口 `8080:8080`

- [ ] **Step 1: 创建 `docker-compose.yml`**

```yaml
services:
  fortune-app:
    build: .
    container_name: fortune-app
    ports:
      - "8080:8080"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    restart: unless-stopped
    environment:
      # 预留：后续可通过环境变量覆盖配置
      - SERVER_PORT=8080
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/fortune"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

- [ ] **Step 2: 本地一键启动并验证**

Run:

```bash
docker compose up --build -d
sleep 10
curl -s http://localhost:8080/fortune | head -c 200
echo
docker compose down
```

Expected:

```text
{"text":"...","level":...}
```

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add docker-compose for local orchestration"
```

---

### Task 4: 创建 GitHub Actions CI 工作流

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `pom.xml`, `src/main/`, `src/test/`
- Produces: artifact `fortune-app-jar`，包含 `target/fortune-app-1.8.0.jar`

- [ ] **Step 1: 创建工作流文件**

```yaml
name: CI

on:
  push:
    branches: [master, main]
  pull_request:
    branches: [master, main]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 11
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '11'
          cache: maven

      - name: Build and test
        run: mvn -B clean package

      - name: Upload jar artifact
        uses: actions/upload-artifact@v4
        with:
          name: fortune-app-jar
          path: target/fortune-app-1.8.0.jar
```

- [ ] **Step 2: 验证 workflow 语法**

Run locally (requires `actionlint`):

```bash
actionlint .github/workflows/ci.yml
```

Expected: 无错误输出。

- [ ] **Step 3: Commit 并推送到 GitHub 触发一次运行**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow"
git push origin master
```

Expected: GitHub 仓库 Actions 页出现一次成功的 `CI` 运行，artifact 下载后可得到 jar。

---

### Task 5: 编写服务器部署脚本 `deploy.sh`

**Files:**
- Create: `deploy.sh`

**Interfaces:**
- Consumes: 环境变量 `SERVER_HOST`, `SERVER_USER`, `REMOTE_DIR`
- Produces: 远程服务器上的 `/opt/fortune-app`（或 `$REMOTE_DIR`）更新并运行容器

- [ ] **Step 1: 创建 `deploy.sh`**

```bash
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
```

- [ ] **Step 2: 赋予执行权限并做静态检查**

Run:

```bash
chmod +x deploy.sh
bash -n deploy.sh
```

Expected: `bash -n` 不输出任何内容，表示语法正确。

- [ ] **Step 3: Commit**

```bash
git add deploy.sh
git commit -m "feat: add server deploy script"
```

---

### Task 6: 编写部署文档 `DEPLOY.md`

**Files:**
- Create: `DEPLOY.md`

**Interfaces:**
- Consumes: `Dockerfile`, `docker-compose.yml`, `deploy.sh`
- Produces: 一份面向学习者和部署者的中文操作手册

- [ ] **Step 1: 创建 `DEPLOY.md`**

```markdown
# 部署运维指南

> 本文档对应 fortune-app **阶段 6：部署运维**。  
> 阅读前请确保已完成 [LEARNING.md](LEARNING.md) 阶段 5。

---

## 1. 本地 Docker 运行

### 1.1 构建并启动

```bash
docker compose up --build -d
```

### 1.2 验证服务

```bash
curl http://localhost:8080/fortune
```

### 1.3 停止服务

```bash
docker compose down
```

数据保存在 `./data`，日志保存在 `./logs`，不会被容器删除。

---

## 2. 服务器部署

### 2.1 前置条件

- 一台已安装 Docker + Docker Compose v2 的 Linux 服务器
- 本地已配置到该服务器的 SSH 免密登录
- 环境变量 `SERVER_HOST`、`SERVER_USER`、`REMOTE_DIR` 已设置

### 2.2 一键部署

```bash
SERVER_HOST=1.2.3.4 \
SERVER_USER=ubuntu \
REMOTE_DIR=/opt/fortune-app \
./deploy.sh
```

脚本会：

1. 本地执行 `mvn package` 生成 jar
2. 把 jar、Dockerfile、docker-compose.yml 上传到服务器
3. 在服务器上构建镜像并启动容器

部署完成后访问：

```text
http://<SERVER_HOST>:8080
```

---

## 3. GitHub Actions CI

每次 `push` 到 `master` / `main` 或提交 PR 时，GitHub Actions 会自动：

1. 检出代码
2. 使用 Temurin JDK 11 运行 `mvn clean package`
3. 上传构建产物 `fortune-app-jar`

可在仓库 **Actions** 标签页下载 jar。

---

## 4. 常见问题

### Q1: 容器启动后数据会丢失吗？

不会。`docker-compose.yml` 把 `./data` 挂载到容器的 `/app/data`，H2 文件数据库会写入宿主机目录。

### Q2: 如何修改端口？

编辑 `docker-compose.yml` 的端口映射，例如 `8081:8080` 把宿主机 8081 映射到容器 8080。  
若同时想修改容器内部端口，可挂载自定义的 `application.properties` 到 `/app/application.properties`。

### Q3: 如何查看日志？

```bash
docker compose logs -f
```

---

## 5. 学习检查点

- [ ] 能独立使用 `docker compose up` 在本地启动服务
- [ ] 能解释多阶段 Dockerfile 的优势
- [ ] 能在 GitHub Actions 看到一次成功的 CI 运行
- [ ] 能使用 `deploy.sh` 把应用部署到远程服务器
```

- [ ] **Step 2: Commit**

```bash
git add DEPLOY.md
git commit -m "docs: add deployment and operations guide"
```

---

### Task 7: 更新 `ROADMAP.md` 阶段 6 状态

**Files:**
- Modify: `ROADMAP.md`

**Interfaces:**
- Consumes: 前面任务完成状态
- Produces: 阶段 6 子任务状态更新

- [ ] **Step 1: 更新阶段 6 状态表**

修改 `ROADMAP.md` 中阶段 6 子任务状态：

```markdown
| 顺序 | 功能 | 训练能力 | 状态 |
|---|---|---|---|
| 6.1 | Dockerfile | 容器化打包 | ✅ 已完成 |
| 6.2 | docker-compose.yml | 本地多服务编排 | ✅ 已完成 |
| 6.3 | GitHub Actions CI | 自动化测试与构建 | ✅ 已完成 |
| 6.4 | 部署脚本 | 服务器上线 | ✅ 已完成 |
```

并把阶段 6 主表 `状态` 从 `🚧 未开始` 改为 `✅ 已完成`。

更新 `当前状态` 区块为：

```markdown
- 已完成阶段：0、1、2、3、4、5.1、5.2、5.3、5.4、6.1、6.2、6.3、6.4
- 进行中阶段：无
- 下一阶段建议：**项目已具备完整生产部署能力，可继续扩展监控、HTTPS、反向代理**
```

- [ ] **Step 2: Commit**

```bash
git add ROADMAP.md
git commit -m "docs: mark stage 6 deployment tasks as completed"
```

---

## Self-Review

**1. Spec coverage:**

- `6.1 Dockerfile` → Task 2 ✅
- `6.2 docker-compose.yml` → Task 3 ✅
- `6.3 GitHub Actions CI` → Task 4 ✅
- `6.4 部署脚本` → Task 5 ✅
- 文档与状态更新 → Task 6、Task 7 ✅

**2. Placeholder scan:**

- 无 `TBD` / `TODO`
- 所有代码块给出完整可执行内容
- 测试命令与期望输出明确

**3. Type consistency:**

- 统一使用 `fortune-app-1.8.0.jar`，与 `pom.xml` 版本一致
- 端口、数据路径与 `application.properties` 默认值一致
- 部署脚本环境变量名称在脚本与文档中一致

---

**Plan complete and saved to `docs/superpowers/plans/2026-07-03-stage-6-deployment-ops.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
