# 代码规范（Code Style）

记录 fortune-app 项目中容易踩坑、必须遵守的编码约定。

---

## 1. Java 包名必须与目录结构完全一致

### 规则

Java 的 `package` 声明必须和文件所在的目录层级一一对应。

```
package com.example.service;

对应路径必须是：
src/main/java/com/example/service/FortuneService.java
```

### 错误案例（已踩坑）

```
package com.example.service;

实际路径：
src/main/java/service/FortuneService.java
```

**后果**：
- Maven 编译可能通过，但运行时报 `ClassNotFoundException` 或 `NoClassDefFoundError`
- VSCode Java 扩展标红提示：
  - `The declared package "com.example.model" does not match the expected package "model"`
  - `FortuneService cannot be resolved to a type`
  - `The method loadFortunes() from the type FortuneService refers to the missing type Fortune`

### 正确做法

使用 Maven 标准目录结构后，所有源码必须放在 `src/main/java/com/example/` 下：

```
src/main/java/com/example/
├── Main.java
├── controller/
│   └── FortuneController.java
├── service/
│   └── FortuneService.java
└── model/
    └── Fortune.java
```

---

## 2. 分层调用方向

- controller → service → model
- 禁止反向调用
- 禁止跨层直接操作数据

---

## 3. 源码编码

- 统一 UTF-8
- 响应头统一声明 `application/json; charset=UTF-8`

---

## 4. 数据文件

### 种子数据
- 内置数据：`src/main/resources/fortunes.txt`，仅供首次初始化使用
- 首次启动（数据库为空）时从 classpath 导入到 H2 数据库
- 种子数据导入后不再使用，后续独立由数据库管理

### 运行时数据
- 生产/开发环境：H2 数据库文件 `data/fortune-db.mv.db`
- 测试环境：H2 内存数据库（不落盘）

---

## 5. 提交前检查

- 运行 `bash run.sh` 确认能正常编译和启动
- 用 `curl` 测试核心接口
- 确认没有新增 `.class` 或 `target/` 文件进入提交

---

## 7. 日志规范

- 使用 SLF4J + Logback 作为日志框架
- 禁止直接使用 `System.out.println` 或 `System.err.println`
- 每个类声明自己的 Logger：
  ```java
  private static final Logger logger = LoggerFactory.getLogger(Xxx.class);
  ```
- 日志级别选择：
  - `DEBUG`：调试细节，如方法入参、循环内部状态
  - `INFO`：正常流程信息，如启动、加载完成、关键业务操作
  - `WARN`：可恢复的异常或警告，如配置缺失、格式错误、使用默认值
  - `ERROR`：严重错误，如 IO 异常、数据库连接失败
- 使用占位符写法，禁止字符串拼接：
  - ✅ `logger.info("用户 {} 登录成功", username);`
  - ❌ `logger.info("用户 " + username + " 登录成功");`
- 异常对象作为最后一个参数传入，便于打印堆栈：
  ```java
  logger.error("保存失败：{}", e.getMessage(), e);
  ```

---

## 8. 版本号规则

- 1.0.0：初始可用版本
- 1.1.0：架构/工程化改造
- 1.2.0：功能增强（JSON 输出等）
- 1.3.0：新增写操作接口（POST/DELETE）
- 1.4.0：前端展示页面
- 1.5.0：配置外置
- 1.6.0：单元测试
- 1.7.0：生产级日志
- 1.8.0：H2 数据库持久化

---

## 9. 数据库操作规范

### 原则
- 使用 JDBC 原生 API，不引入 ORM 框架（保持依赖最小化）
- 所有数据库资源使用 try-with-resources 确保释放
- 禁止在业务层直接操作 Connection，必须通过 Repository 层

### Repository 规范
- 每个方法独立获取连接（无连接池，简单项目适用）
- 查询方法返回 `List<Fortune>` 或单个 `Fortune`
- 写操作返回影响行数或布尔值
- 异常内部捕获并记录日志，不向上抛出

### SQL 规范
- 表名、列名统一小写 + 下划线
- 主键使用 `AUTO_INCREMENT`（H2 兼容）
- 参数化查询使用 `PreparedStatement`，禁止字符串拼接 SQL
- 示例：
  ```java
  // ✅ 正确
  PreparedStatement stmt = conn.prepareStatement("SELECT text, level FROM fortunes WHERE id = ?");
  stmt.setInt(1, id);

  // ❌ 错误
  Statement stmt = conn.createStatement();
  stmt.executeQuery("SELECT text, level FROM fortunes WHERE id = " + id);
  ```

### 测试中的数据库
- 单元测试使用 H2 内存模式 `jdbc:h2:mem:testdb-{UUID}`
- 每个测试类使用独立数据库实例，确保隔离
- 使用 `DB_CLOSE_DELAY=-1` 防止数据库被意外关闭

### 文件 vs 数据库
- 生产环境：H2 文件模式（数据持久化到磁盘）
- 测试环境：H2 内存模式（每次测试重建，不残留数据）
- 种子数据：`fortunes.txt` 仅首次初始化时使用，之后独立于数据库
