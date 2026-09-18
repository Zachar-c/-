# Task 1 报告：添加 .dockerignore

## 完成内容

按照任务要求，在项目根目录 `c:/Users/Zachary/OneDrive/Workspace/00_Inbox/fortune-app` 创建了 `.dockerignore` 文件，内容包含：

- 排除 Git 版本控制目录（`.git`、`.gitignore`）
- 排除 Maven 构建产物（`target/`）
- 排除 IDE 配置（`.idea/`、`.iml`、`.vscode/`）
- 排除运行时持久化数据（`data/`、`logs/`，应通过 volume 挂载而非打包进镜像）
- 排除本地文档与环境文件（`*.md`、`.github/`、`docs/`），避免镜像体积膨胀和泄露无关信息

## 测试/验证结果

执行验证命令：

```bash
docker build -t fortune-app:test-build . --no-cache 2>&1 | tail -n 5
```

结果：当前环境未安装 Docker（`docker: command not found`），因此跳过构建验证。已在报告中记录该情况。

文件内容已按要求精确创建，路径正确。

## 变更文件

- `c:/Users/Zachary/OneDrive/Workspace/00_Inbox/fortune-app/.dockerignore`（新增）

## 关注点

- Docker 在当前环境不可用，未进行实际的 `docker build` 验证；后续在已安装 Docker 的环境中可重新运行验证命令。
- `.dockerignore` 中排除了 `data/` 与 `logs/`，符合"运行时数据通过 volume 持久化，不进入镜像"的约束。
- 未排除 `Dockerfile` 本身或构建所需的 `pom.xml`、`src/` 等文件，不会影响后续镜像构建。
