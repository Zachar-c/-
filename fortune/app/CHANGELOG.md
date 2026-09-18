# 变更日志

记录 fortune-app 项目的重要变更。

## [1.8.0] - 2026-07-03

### 新增
- H2 数据库持久化：替代文本文件作为数据存储
- 新增 `FortuneRepository` 数据访问层：封装 JDBC 操作
- 新增 `src/main/resources/schema.sql`：建表脚本
- 新增 `CODESTYLE.md` 数据库规范章节
- 新增 `.gitignore` `data/` 规则，避免提交 H2 数据库文件

### 改造
- `FortuneService`：不再直接读写文件，委托 `FortuneRepository` 操作数据库
- `pom.xml`：新增 H2 数据库依赖（2.2.224）
- `application.properties`：新增数据库连接配置
- `AppConfig`：新增数据库配置 getter 和测试用五参数构造方法
- `FortuneServiceTest`：适配 Repository，使用 H2 内存数据库进行测试
- API id 映射：对外 id 从 0 开始，内部映射到数据库 id（自增，从 1 开始）

### 数据策略
- 启动时数据库为空 → 从 classpath `fortunes.txt` 导入种子数据
- 种子数据仅首次初始化时使用，之后由数据库独立管理
- 增删操作直接操作数据库，不再维护文件同步

### 数据库
- 引擎：H2（文件模式 `jdbc:h2:file:./data/fortune-db`）
- 表结构：`fortunes (id, text, level, created_at)`
- 测试：H2 内存模式 `jdbc:h2:mem:testdb-xxx`
- 资源管理：全部使用 try-with-resources 防止泄漏

### 教学价值
- JDBC 基础使用（DriverManager、Connection、PreparedStatement）
- SQL 建表、增删查操作
- Repository 分层模式：数据访问与业务逻辑解耦
- 自增主键与 API id 的映射转化
- 种子数据（Seed Data）概念
- 内存数据库在单元测试中的应用

## [1.7.0] - 2026-07-03

### 新增
- 引入 SLF4J 2.0.13 + Logback 1.5.6 生产级日志框架
- 新增 `src/main/resources/logback.xml`：同时输出到控制台和 `logs/fortune-app.log`
- 新增增删运势的 INFO 级别日志

### 改造
- `Main.java`：`System.out.println` 替换为 `logger.info`
- `AppConfig.java`：`System.err.println` 替换为 `logger.warn`
- `FortuneService.java`：所有日志输出统一使用 SLF4J 占位符写法
- `pom.xml` 新增 SLF4J API 和 Logback Classic 依赖

### 日志规范
- `INFO`：正常流程（启动、加载数据、增删运势）
- `WARN`：警告（配置加载失败、格式错误、使用默认值）
- `ERROR`：错误（IO 异常）
- `DEBUG`：调试信息（保存数据）

### 教学价值
- 理解 SLF4J 作为日志门面的优势
- 理解 Logback 作为实现框架
- 掌握日志级别 DEBUG/INFO/WARN/ERROR 的使用场景
- 理解为什么生产项目不用 `System.out.println`
- 学习占位符写法：`logger.info("消息 {}", value)`

## [1.6.0] - 2026-07-02

### 新增
- 引入 JUnit 5 和 Mockito 测试依赖
- 新增 `FortuneServiceTest`：覆盖 service 层 10 个核心测试场景
- 新增 `AppConfig` 测试友好构造方法：支持直接指定端口和数据文件路径

### 测试覆盖
- 随机运势返回非空且在列表中
- 查询全部运势数量正确
- 按星级筛选结果正确
- 按 id 查询：有效 id 返回运势、越界返回 null
- 添加运势：成功添加、空文本拒绝、非法星级拒绝、null 拒绝
- 删除运势：成功删除、非法 id 拒绝

### 改造
- `pom.xml` 新增 JUnit 5（5.10.2）和 Mockito（5.11.0）依赖
- `AppConfig` 新增 `AppConfig(int port, String dataFile)` 构造方法，便于测试注入
- 测试使用 `@TempDir` 创建临时数据文件，避免污染生产数据

### 教学价值
- 理解单元测试的作用和写法
- 掌握 JUnit 5 基础注解：`@Test`、`@BeforeEach`、`@TempDir`
- 掌握常用断言：`assertEquals`、`assertTrue`、`assertFalse`、`assertNull`、`assertNotNull`
- 理解测试隔离的重要性
- 为后续严格 TDD 开发打基础

## [1.5.0] - 2026-07-02

### 新增
- 配置文件支持：新增 `src/main/resources/application.properties`
- 新增 `com.example.config.AppConfig`：使用 `java.util.Properties` 加载配置
- 支持外部配置覆盖内置配置：jar 运行目录下的 `application.properties` 优先级更高

### 可配置项
- `server.port`：HTTP 服务端口，默认 `8080`
- `fortune.data.file`：运行时运势数据文件路径，默认 `data/fortunes.txt`

### 改造
- `Main.java` 从 `AppConfig` 读取端口启动服务
- `FortuneService` 通过构造函数接收 `AppConfig`，动态获取数据文件路径
- `FortuneController` 通过构造函数接收 `AppConfig` 并透传给 service

### 教学价值
- 理解"配置与代码分离"
- 理解配置优先级：外部 > 内置 > 代码默认值
- 掌握 `java.util.Properties` 的基础用法
- 为后续 Docker / CI / 多环境部署打基础

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
