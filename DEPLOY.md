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
