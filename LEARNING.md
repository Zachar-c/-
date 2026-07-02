# 学习路径（Learning Path）

> 本文档面向希望借助 fortune-app 从 0 基础成长为资深 Java 开发工程师的学习者。  
> 每个阶段都有明确的能力目标，每个目标都对应 fortune-app 中的具体实现点。

---

## 如何使用本文档

1. **按阶段学习**：不要跳过阶段，每个阶段都是下一阶段的基础。
2. **对照代码**：每个训练点都标注了对应的文件或 commit，打开代码边看边学。
3. **动手改**：不是读完就算，要尝试自己改一行代码、加一个接口、修一个 bug。
4. **复盘总结**：每完成一个阶段，尝试不看代码，用自己的话解释"为什么这样设计"。

---

## 阶段 0：零基础小白 —— 让程序跑起来

### 能力目标
- 认识 Java 文件结构
- 会用 `javac` 和 `java` 编译运行程序
- 理解变量、方法、随机数

### 对应 fortune-app 内容
- 单文件版 `Main.java`：随机输出一条运势
- 运行命令：`javac Main.java && java Main`

### 学习检查点
- [ ] 能独立编译并运行单文件版 fortune-app
- [ ] 能修改运势文本并重新运行看到效果
- [ ] 能解释 `Random` 和 `System.out.println` 的作用

---

## 阶段 1：入门开发者 —— 代码要分开放

### 能力目标
- 理解类的职责分离
- 理解包（package）和目录结构
- 初步认识 MVC/分层思想

### 对应 fortune-app 内容
- 拆分为 `Main.java` / `controller/` / `service/` / `model/`
- `Fortune` 实体类：`text` + `level`
- `FortuneService`：封装运势生成逻辑
- `FortuneController`：接收请求并返回结果

### 学习检查点
- [ ] 能说出 controller、service、model 各自负责什么
- [ ] 能解释 `package` 和 `import` 的关系
- [ ] 能独立在 service 层新增一个方法

---

## 阶段 2：初级工程师 —— 能做接口和持久化

### 能力目标
- 理解 HTTP 请求方法（GET/POST/DELETE）
- 会设计 REST 风格接口
- 会读写文件做持久化
- 会基础错误处理

### 对应 fortune-app 内容
- `GET /fortune`：随机运势
- `GET /fortune/list`：全部运势
- `GET /fortune/count`：总数
- `GET /fortune/level/{level}`：按星级筛选
- `GET /fortune/{id}`：按索引查询
- `fortunes.txt`：外部数据文件
- `POST /fortune` + `DELETE /fortune/{id}`：增删运势
- 400 / 404 / 405 错误码处理

### 学习检查点
- [ ] 能用 curl 测试所有接口
- [ ] 能解释路径参数和查询参数的区别
- [ ] 能修改 `fortunes.txt` 并看到后端数据变化
- [ ] 能独立添加一个 `GET /fortune/random/{level}` 接口

---

## 阶段 3：中级工程师 —— 工程化改造

### 能力目标
- 理解 Maven/Gradle 构建工具
- 会管理外部依赖
- 理解 classpath 和资源文件
- 会打包可执行 jar

### 对应 fortune-app 内容
- `pom.xml`：Maven 配置
- 源码迁移到 `src/main/java/com/example/`
- `fortunes.txt` 迁移到 `src/main/resources/`
- 引入 `com.google.code.gson` 依赖
- 统一返回 JSON 格式
- `mvn/mvnd clean package` 打包
- `run.sh` 一键构建启动

### 学习检查点
- [ ] 能解释 `groupId` / `artifactId` / `version`
- [ ] 能手动执行 `mvn clean package` 并找到 jar
- [ ] 能解释 classpath 资源如何被打包进 jar
- [ ] 能独立给项目添加一个新的 Maven 依赖

---

## 阶段 4：高级工程师 —— 完整系统能力

### 能力目标
- 写操作接口 + 数据持久化
- 静态资源服务
- 设计文档和代码规范
- 版本控制 + 变更日志

### 对应 fortune-app 内容
- `POST /fortune` + `DELETE /fortune/{id}`
- 运行时外部数据文件 `data/fortunes.txt`
- 前端页面 `src/main/resources/static/index.html`
- `Main.java` 中新增静态资源处理器
- `PRD.md` / `CHANGELOG.md` / `CODESTYLE.md`
- Git commit 规范

### 学习检查点
- [ ] 能解释为什么运行时数据要放在 jar 外部
- [ ] 能独立修改前端页面样式
- [ ] 能写出一条合格的 commit message
- [ ] 能在项目中新增一条规范并写入 CODESTYLE.md

---

## 阶段 5：资深工程师 —— 生产级改造

### 能力目标
- 配置外置
- 单元测试 + TDD
- 日志框架
- 数据库持久化
- 部署运维

### 对应 fortune-app 内容
- `application.properties`：端口、数据路径外置 ✅
- JUnit 5 + Mockito：测试 service 层 ✅
- SLF4J + Logback：替换 `System.out.println`
- SQLite / H2：替代文本文件
- Docker / CI：打包部署

### 学习检查点
- [ ] 能解释为什么 8080 不应该写死在代码里
- [ ] 能说明配置优先级：外部 > 内置 > 默认值
- [ ] 能使用 `java.util.Properties` 读取配置文件
- [ ] 能独立新增一个配置项并正确加载
- [ ] 能解释单元测试的作用，并写出一个 JUnit 5 测试方法
- [ ] 能理解 `@BeforeEach`、`@Test`、`@TempDir` 的用法
- [ ] 能说出至少 3 个 JUnit 断言方法及其使用场景
- [ ] 能解释为什么测试要隔离，避免互相影响
- [ ] 能写出 RED-GREEN-REFACTOR 的 TDD 流程
- [ ] 能解释日志级别 DEBUG/INFO/WARN/ERROR 的使用场景
- [ ] 能设计一张简单的数据库表
- [ ] 能写出 Dockerfile 并运行容器

---

## 学习心法

1. **不要复制粘贴**：每一行代码都自己敲一遍。
2. **多问自己"为什么"**：为什么分层？为什么用 Maven？为什么数据要外置？
3. **主动制造 bug**：改错一个路径、删一个 import、改一个状态码，看系统怎么反应。
4. **教别人**：能给别人讲清楚，才算真正学会。
5. **记录笔记**：每个阶段结束后，用自己的话写一篇学习笔记。

---

## 下一步

继续阅读 [ROADMAP.md](ROADMAP.md)，了解每个阶段的具体功能路线图。
