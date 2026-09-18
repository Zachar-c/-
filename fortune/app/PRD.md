# fortune-app 产品需求文档（PRD）

> 版本：1.8.0  
> 最后更新：2026-07-03  
> 用途：作为需求与实现的唯一事实来源，方便新会话快速接手。

---

## 1. 产品定位

一个轻量级的**程序员运势占卜服务**，基于纯 JDK 实现，无需第三方 Web 容器。通过 HTTP 接口返回随机运势，支持按星级筛选、按索引查询、列表展示。

核心目标：
- 演示 Java 后端分层架构
- 体验从单文件到 Maven 工程的演进
- 保持最小依赖、最简部署
- **作为流程化学习服务，帮助小白从 0 基础成长为资深 Java 开发工程师**：
  - 每个功能迭代对应一个真实工程能力的训练点
  - 从能跑通的单文件开始，逐步引入分层、接口、持久化、构建工具、JSON、前端、测试、配置管理
  - 让学习者在每一个 commit 中理解"为什么这样改"，而不仅是"怎么改"
  - 最终能够独立设计、实现、部署一个完整的小型 Java Web 项目

---

## 2. 技术栈

| 层级 | 技术 |
|---|---|
| 语言 | Java 11+ |
| HTTP 服务 | `com.sun.net.httpserver`（JDK 内置） |
| 构建工具 | Maven / mvnd |
| JSON 序列化 | Gson 2.10.1 |
| 数据存储 | H2 数据库 `jdbc:h2:file:./data/fortune-db`（文件模式），启动时从 classpath `fortunes.txt` 导入种子数据 |
| 数据库访问 | JDBC（纯 Java，无 ORM） |
| 前端 | HTML5 / CSS3 / 原生 JS |
| 设计指导 | `frontend-design` skill（Anthropics） |
| 配置管理 | `application.properties`，支持外部覆盖内置 |
| 单元测试 | JUnit 5 + Mockito |
| 日志框架 | SLF4J + Logback |

## 3. 项目结构

```
fortune-app/
├── pom.xml
├── run.sh
├── CHANGELOG.md
├── CODESTYLE.md
├── LEARNING.md
├── ROADMAP.md
├── PRD.md                    ← 本文档
├── .gitignore
└── src/
    └── main/
        ├── java/com/example/
        │   ├── Main.java                 # 启动入口 + 静态页面服务
        │   ├── config/
        │   │   └── AppConfig.java        # 配置加载
        │   ├── controller/
        │   │   └── FortuneController.java # HTTP 请求分发
        │   ├── service/
        │   │   └── FortuneService.java    # 业务逻辑
        │   ├── repository/
        │   │   └── FortuneRepository.java # 数据访问层（JDBC）
        │   └── model/
        │       └── Fortune.java           # 运势实体
        └── resources/
            ├── application.properties     # 默认配置
            ├── fortunes.txt               # 种子数据（仅首次初始化）
            ├── schema.sql                 # 建表脚本
            └── static/
                └── index.html             # 前端展示页面
```

---

## 4. 功能需求

### 4.1 接口清单

所有接口前缀为 `/fortune`，统一返回 JSON。

| 方法 | 路径 | 功能 | 请求体 | 成功响应 | 错误响应 |
|---|---|---|---|---|---|
| GET | `/` | 前端展示页面 | - | `text/html` | - |
| GET | `/fortune` | 随机返回一条运势 | - | `{"text":"...","level":n,"display":"🌟 ..."}` | - |
| GET | `/fortune/list` | 返回所有运势 | - | `{"count":34,"data":[...]}` | - |
| GET | `/fortune/count` | 返回运势总数 | - | `{"count":34}` | - |
| GET | `/fortune/level/{level}` | 按星级筛选 | - | `{"count":n,"data":[...]}` | 404 `{"error":"没有找到 n 星运势"}` |
| GET | `/fortune/{id}` | 按索引查询 | - | `{"text":"...","level":n,"display":"🌟 ..."}` | 404 `{"error":"id 超出范围：n"}` |
| POST | `/fortune` | 添加一条运势 | `text=...&level=n` | `{"count":35}` | 400 `{"error":"text 参数不能为空"}` |
| DELETE | `/fortune/{id}` | 删除指定运势 | - | `{"count":34}` | 404 `{"error":"id 超出范围：n"}` |

### 4.2 前端页面

- 访问 `http://localhost:8080/` 可打开可视化运势抽取界面
- 设计风格：GitHub Dark 配色 + 紫色幸运光效
- 标志性元素：「▶ 运行命运.exe」按钮
- 字体：JetBrains Mono + Inter
- 交互：按钮加载态、终端打字机效果输出运势、星级 emoji 展示

### 4.2 参数规则

- `{level}` 必须是 1-6 的整数
- `{id}` 必须是 0 到 `count-1` 的整数
- `text` 参数不能为空
- 路径参数非法时返回 **400**：`{"error":"..."}`
- 资源不存在时返回 **404**：`{"error":"..."}`
- 请求方法不支持返回 **405**

### 4.3 数据格式

**单条运势 JSON**：

```json
{
  "text": "大吉：全天写出零bug代码",
  "level": 5,
  "display": "🌟 🌟 🌟 🌟 🌟 大吉：全天写出零bug代码"
}
```

**列表 JSON**：

```json
{
  "count": 6,
  "data": [
    { "text": "...", "level": 6, "display": "🌟 ..." }
  ]
}
```

### 4.4 配置管理

- 内置默认配置：`src/main/resources/application.properties`
- 外部覆盖配置：jar 运行目录下的 `application.properties`
- 配置加载优先级：**外部配置 > 内置配置 > 代码默认值**
- 当前可配置项：
  - `server.port`：HTTP 服务端口，默认 `8080`
  - `fortune.db.url`：H2 数据库连接 URL，默认 `jdbc:h2:file:./data/fortune-db`
  - `fortune.db.username`：数据库用户名，默认 `sa`
  - `fortune.db.password`：数据库密码，默认空字符串
- 配置值非法或缺失时，回退到默认值并打印警告

### 4.5 数据源

- **数据库**：H2 文件模式，数据文件位于 `./data/fortune-db.mv.db`
- **种子数据**：`src/main/resources/fortunes.txt`，仅首次启动（数据库为空）时导入
- **数据格式**：`运势文本|星级`，每行一条
- 运行时通过 `FortuneRepository`（JDBC）操作数据库
- 增删操作直接写数据库，不再维护文件同步
- 表结构：
  ```sql
  fortunes (id INT AUTO_INCREMENT, text VARCHAR(500), level INT, created_at TIMESTAMP)
  ```
- **API id 映射**：对外 id 从 0 开始，内部映射到数据库自增 id（id + 1）

### 4.6 POST/DELETE 示例

```bash
# 添加运势
curl -X POST -d 'text=大吉：新项目顺利启动&level=5' http://localhost:8080/fortune
# {"count":35}

# 删除 id=34 的运势
curl -X DELETE http://localhost:8080/fortune/34
# {"count":34}
```

---

## 5. 非功能需求

### 5.1 编码

- 源码统一 UTF-8
- HTTP 响应头：`Content-Type: application/json; charset=UTF-8`
- 启动参数：`-Dfile.encoding=UTF-8`

### 5.2 部署

- 默认绑定端口：`8080`（可通过 `application.properties` 修改）
- 启动命令：`bash run.sh`
- 手动启动：`java -Dfile.encoding=UTF-8 -jar target/fortune-app-1.8.0.jar`

### 5.3 构建

- 使用本地 mvnd：`/c/DevEnv/04_Language_Envs/Java/maven-mvnd-1.0.6-windows-amd64/bin/mvnd.exe`
- 打包命令：`mvnd clean package`
- 测试命令：`mvnd test`
- 输出 jar：`target/fortune-app-1.0.0.jar`
- 可执行 jar，包含所有依赖（shade 插件）

### 5.4 版本控制

- 使用 Git 管理
- 每次重要变更需更新 `CHANGELOG.md`
- 忽略文件：`.gitignore` 中已配置 `target/`、IDE 文件、`.class`、`dependency-reduced-pom.xml`、`logs/`、`data/`

### 5.5 单元测试

- 测试框架：JUnit 5 + Mockito
- 测试目录：`src/test/java/`
- 当前测试覆盖：`FortuneService`
- 测试原则：
  - 每个测试验证一个明确行为
  - 使用 `@TempDir` 隔离文件系统副作用
  - 边界条件必须覆盖（负数、空值、越界等）
- 运行方式：`mvnd test`

---

## 6. 架构约束

- **禁止**在 controller 中写业务逻辑
- **禁止**在 service 中直接处理 HTTP 请求
- **禁止**在 model 中引入外部依赖
- 所有跨层调用只能向下：controller → service → model

---

## 7. 版本历史

| 版本 | 提交 | 主要变更 |
|---|---|---|
| 1.0.0 | a4e7cac | 初始分层项目，5 个接口，34 条运势，文件持久化 |
| 1.1.0 | 7a6ff7d | Maven 工程化改造，标准目录结构，mvnd 打包 |
| 1.2.0 | 87568c9 | 统一 JSON 输出，引入 Gson，保留 emoji display |
| 1.3.0 | cd907fe | 修复包目录结构，新增 CODESTYLE.md |
| 1.4.0 | 5ac996a | 前端展示页面，使用 frontend-design skill 指导设计 |
| 1.5.0 | b87b164 | 配置外置：application.properties 支持端口和数据路径配置 |
| 1.6.0 | 503c039 | 引入 JUnit 5 + Mockito，新增 FortuneServiceTest 单元测试 |
| 1.7.0 | - | 引入 SLF4J + Logback 生产级日志框架 |
| 1.8.0 | - | H2 数据库持久化，新增 FortuneRepository |

---

## 8. 下一步可选方向

- **配置文件**：将端口、数据文件路径外置到 `application.properties`
- **单元测试**：引入 JUnit 5 测试 service 层
- **日志框架**：引入 SLF4J + Logback 替代 `System.out.println`
- **持久化升级**：用 SQLite / H2 替代文本文件
- **批量导入**：支持上传文件一次性导入多条运势
- **热门统计**：记录每条运势被抽中次数
- **前端增强**：历史记录、分享按钮、动画优化

---

## 9. 快速启动

```bash
# 进入项目目录
cd fortune-app

# 一键启动
bash run.sh

# 打开前端页面
open http://localhost:8080

# 测试接口
curl http://localhost:8080/fortune
curl http://localhost:8080/fortune/list
curl http://localhost:8080/fortune/count
```
