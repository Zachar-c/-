# 变更日志

记录 fortune-app 项目的重要变更。

## [1.4.0] - 2026-07-02

### 新增
- 前端展示页面：`src/main/resources/static/index.html`
- 访问 `http://localhost:8080/` 可打开可视化运势抽取界面
- 使用 `frontend-design` skill 指导设计

### 设计特点
- 采用 GitHub Dark 配色 + 紫色幸运光效，避免 AI 设计三俗
- 标志性元素：「▶ 运行命运.exe」按钮
- 字体：JetBrains Mono + Inter
- 交互：按钮加载态、终端打字机效果输出运势、星级 emoji 展示

### 改造
- `Main.java` 新增 `StaticPageHandler`，从 classpath 提供静态页面
- 根路径 `/` 返回 `index.html`，其余静态资源从 `/static/` 提供

## [1.3.0] - 2026-07-02

### 新增
- 支持 `POST /fortune`：通过 form 参数 `text` 和 `level` 添加新运势
- 支持 `DELETE /fortune/{id}`：删除指定索引的运势
- 运行时数据持久化到 `data/fortunes.txt`，增删后立即写回文件
- 首次启动时自动将 classpath 内置资源复制到外部数据目录

### 改造
- `FortuneService` 重构：
  - 支持从外部文件 `data/fortunes.txt` 加载
  - 新增 `addFortune(text, level)` 和 `deleteFortune(id)` 方法
  - 数据修改后同步保存
- `FortuneController` 重构：
  - 支持 GET/POST/DELETE 三种 HTTP 方法
  - POST 解析 form 数据并校验 `text` 和 `level`
  - 添加操作成功返回 201，删除成功返回 200

### 修复
- 修复源码目录结构：`src/main/java/xxx/` → `src/main/java/com/example/xxx/`
- 解决 VSCode Java 扩展标红：package 与目录不匹配

### 新增文档
- `CODESTYLE.md`：记录包目录规范、分层约束、提交前检查等

## [1.2.0] - 2026-07-02

### 改造
- 引入 `com.google.code.gson` 依赖，统一接口返回 JSON 格式
- `Fortune` 新增 `display` 字段，JSON 中保留 emoji 星级展示
- `FortuneController` 重构：
  - 所有响应改为 `application/json; charset=UTF-8`
  - 单条运势返回 `{"text", "level", "display"}`
  - 列表接口返回 `{"count", "data"}`
  - 错误返回 `{"error"}`，并保留 400/404 状态码
- `.gitignore` 增加 `dependency-reduced-pom.xml`

### 接口示例
```bash
GET /fortune
{"text":"中吉：服务器资源充足不卡顿","level":4,"display":"🌟 🌟 🌟 🌟 中吉：服务器资源充足不卡顿"}

GET /fortune/count
{"count":34}

GET /fortune/abc
{"error":"id 必须是数字：abc"}
```

## [1.1.0] - 2026-07-01

### 改造
- 项目升级为 Maven 标准工程结构
- 源码迁移至 `src/main/java/com/example/`
- `fortunes.txt` 迁移至 `src/main/resources/`，通过 classpath 加载
- 包名统一为 `com.example.controller/service/model`
- 新增 `pom.xml`，使用 maven-shade-plugin 打包可执行 jar
- `run.sh` 改用本地 `mvnd` 构建，自动输出 `target/fortune-app-1.0.0.jar`

### 项目结构
```
fortune-app/
├── pom.xml
├── run.sh
├── CHANGELOG.md
├── .gitignore
└── src/
    └── main/
        ├── java/com/example/
        │   ├── Main.java
        │   ├── controller/FortuneController.java
        │   ├── service/FortuneService.java
        │   └── model/Fortune.java
        └── resources/fortunes.txt
```

## [1.0.0] - 2026-07-01

### 新增
- 初始版本：基于 `com.sun.net.httpserver` 的分层 Java Web 项目
- `GET /fortune`：随机返回一条运势
- `GET /fortune/list`：列出所有运势
- `GET /fortune/count`：返回运势总数
- `GET /fortune/level/{level}`：按星级筛选运势
- `GET /fortune/{id}`：按索引返回单条运势
- `fortunes.txt` 外部数据文件，支持不编译直接修改运势内容
- `run.sh` 一键脚本：自动杀旧进程、编译、启动、测试
- 运势库扩展至 34 条，覆盖 1-6 星

### 项目结构
```
fortune-app/
├── Main.java
├── controller/FortuneController.java
├── service/FortuneService.java
├── model/Fortune.java
├── fortunes.txt
├── run.sh
├── CHANGELOG.md
└── .gitignore
```

### 技术点
- 分层架构：controller / service / model 职责分离
- 文件持久化：启动时从 `fortunes.txt` 加载运势
- 错误处理：路径参数非法返回 400，资源不存在返回 404
- 字符编码：HTTP 响应头声明 `Content-Type: text/plain; charset=UTF-8`
