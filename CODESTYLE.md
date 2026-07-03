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

- 内置默认数据：`src/main/resources/fortunes.txt`
- 运行时外部数据：`data/fortunes.txt`
- 代码中优先读取外部文件，不存在时从 classpath 复制

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
