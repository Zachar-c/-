# 变更日志

记录 fortune-app 项目的重要变更。

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
