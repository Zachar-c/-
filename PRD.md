# fortune-app 产品需求文档（PRD）

> 版本：1.2.0  
> 最后更新：2026-07-02  
> 用途：作为需求与实现的唯一事实来源，方便新会话快速接手。

---

## 1. 产品定位

一个轻量级的**程序员运势占卜服务**，基于纯 JDK 实现，无需第三方 Web 容器。通过 HTTP 接口返回随机运势，支持按星级筛选、按索引查询、列表展示。

核心目标：
- 演示 Java 后端分层架构
- 体验从单文件到 Maven 工程的演进
- 保持最小依赖、最简部署

---

## 2. 技术栈

| 层级 | 技术 |
|---|---|
| 语言 | Java 11+ |
| HTTP 服务 | `com.sun.net.httpserver`（JDK 内置） |
| 构建工具 | Maven / mvnd |
| JSON 序列化 | Gson 2.10.1 |
| 数据存储 | 文本文件 `fortunes.txt`（classpath 资源） |
| 版本控制 | Git |

---

## 3. 项目结构

```
fortune-app/
├── pom.xml
├── run.sh
├── CHANGELOG.md
├── PRD.md                    ← 本文档
├── .gitignore
└── src/
    └── main/
        ├── java/com/example/
        │   ├── Main.java                 # 启动入口
        │   ├── controller/
        │   │   └── FortuneController.java # HTTP 请求分发
        │   ├── service/
        │   │   └── FortuneService.java    # 业务逻辑 + 数据加载
        │   └── model/
        │       └── Fortune.java           # 运势实体
        └── resources/
            └── fortunes.txt               # 运势数据文件
```

---

## 4. 功能需求

### 4.1 接口清单

所有接口前缀为 `/fortune`，统一返回 JSON。

| 方法 | 路径 | 功能 | 成功响应 | 错误响应 |
|---|---|---|---|---|
| GET | `/fortune` | 随机返回一条运势 | `{"text":"...","level":n,"display":"🌟 ..."}` | - |
| GET | `/fortune/list` | 返回所有运势 | `{"count":34,"data":[...]}` | - |
| GET | `/fortune/count` | 返回运势总数 | `{"count":34}` | - |
| GET | `/fortune/level/{level}` | 按星级筛选 | `{"count":n,"data":[...]}` | 404 `{"error":"没有找到 n 星运势"}` |
| GET | `/fortune/{id}` | 按索引查询 | `{"text":"...","level":n,"display":"🌟 ..."}` | 404 `{"error":"id 超出范围：n"}` |

### 4.2 路径参数规则

- `{level}` 必须是 1-6 的整数
- `{id}` 必须是 0 到 `count-1` 的整数
- 路径参数非法时返回 **400**：`{"error":"..."}`
- 资源不存在时返回 **404**：`{"error":"..."}`
- 非 GET 请求返回 **405**

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

### 4.4 数据源

- 文件位置：`src/main/resources/fortunes.txt`
- 打包后通过 classpath 加载
- 格式：`运势文本|星级`，每行一条
- 启动时加载，运行期间不变
- 文件缺失或格式错误时，回退到内置默认运势并打印警告

---

## 5. 非功能需求

### 5.1 编码

- 源码统一 UTF-8
- HTTP 响应头：`Content-Type: application/json; charset=UTF-8`
- 启动参数：`-Dfile.encoding=UTF-8`

### 5.2 部署

- 绑定端口：8080
- 启动命令：`bash run.sh`
- 手动启动：`java -Dfile.encoding=UTF-8 -jar target/fortune-app-1.0.0.jar`

### 5.3 构建

- 使用本地 mvnd：`/c/DevEnv/04_Language_Envs/Java/maven-mvnd-1.0.6-windows-amd64/bin/mvnd.exe`
- 打包命令：`mvnd clean package`
- 输出 jar：`target/fortune-app-1.0.0.jar`
- 可执行 jar，包含所有依赖（shade 插件）

### 5.4 版本控制

- 使用 Git 管理
- 每次重要变更需更新 `CHANGELOG.md`
- 忽略文件：`.gitignore` 中已配置 `target/`、IDE 文件、`.class`、`dependency-reduced-pom.xml`

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

---

## 8. 下一步可选方向

- **写操作接口**：`POST /fortune` 添加运势，`DELETE /fortune/{id}` 删除
- **配置文件**：将端口、数据文件路径外置到 `application.properties`
- **单元测试**：引入 JUnit 5 测试 service 层
- **日志框架**：引入 SLF4J + Logback 替代 `System.out.println`
- **持久化升级**：用 SQLite / H2 替代文本文件

---

## 9. 快速启动

```bash
# 进入项目目录
cd fortune-app

# 一键启动
bash run.sh

# 测试接口
curl http://localhost:8080/fortune
curl http://localhost:8080/fortune/list
curl http://localhost:8080/fortune/count
```
