好的。我**不做任何精简，不删任何细节，只做一件事：把这份文档当成“AI开发者的唯一依据”来补齐所有缺口，确保AI拿到就能开工，不需要猜、不需要脑补、不需要再来回确认。**

以下为最终完整版：


# 个人AI生产力系统 · 完整交付文档（AI开发最终版）


## 第一部分：项目宪法（CONSTITUTION.md）


### 一、项目定位

| 项目属性 | 说明 |
|---------|------|
| 项目名称 | MyAIProductionSystem |
| 项目类型 | 个人AI生产力系统（不是“知识库”，不是“软件”） |
| 生命周期 | 伴随开发者一生，持续迭代 |
| 所有权 | 100%属于个人，所有数据在本地，可迁移 |
| 开发方式 | AI辅助开发（Web Coding），AI Agent全程参与 |
| 当前最高优先级 | 软件自动化测试（V0.1-V0.5） |
| 预留扩展场景 | 穿搭助手、健身管理、开发辅助、私密数据管理 |


### 二、技术栈约束（不可更改）

| 组件 | 技术选型 | 版本/说明 |
|------|---------|----------|
| 后端语言 | Python | 3.10+ |
| 前端框架 | Vue3 | 搭配Element Plus |
| 向量数据库 | Chroma | 持久化客户端，使用相对路径 |
| 嵌入模型 | bge-small-zh | 约80MB，中文优化 |
| 浏览器自动化 | Playwright | 用于截图和DOM提取 |
| Web框架 | FastAPI | 后端API服务 |
| MCP协议 | Python MCP SDK | 对接Claude Desktop |
| 文档解析 | pypdf / python-docx / pandas | PDF/Word/Excel解析 |
| 多模态模型 | CLIP（本地）/ GPT-4o（云端备选） | 用于设计稿理解 |


### 三、核心架构原则（不可违反）

| 原则 | 说明 |
|------|------|
| 模块化 | 所有功能以独立模块存在，每个模块可独立增删替换，互不依赖 |
| 配置驱动 | 不硬编码任何业务逻辑，所有可调参数在config/目录下 |
| 数据属于用户 | 所有数据在data/目录，使用相对路径，复制文件夹即迁移 |
| 场景=模块组合 | 切换场景就是切换启用哪些模块，不改代码 |
| AI是助手 | AI必须展示思考过程，标注引用来源，不知道就承认 |
| 私密数据隔离 | 默认完全不参与任何检索，仅用户主动查询时解密 |
| 契约优先 | 模块间通过定义明确的接口通信，不直接依赖内部实现 |


### 四、质量门禁（硬性标准）

| 门禁项 | 标准 | 检查方式 |
|--------|------|---------|
| 单元测试覆盖率 | ≥80% | pytest --cov |
| 集成测试 | 覆盖所有模块接口 | pytest integration/ |
| 代码审查 | 必须通过 | AI Agent审查 + 人工确认 |
| 检索性能 | <500ms | 基准测试 |
| 内存占用 | <500MB | 运行时监控 |
| 规范追溯 | 每行代码可追溯到具体Spec | 代码审查时核对 |


## 第二部分：术语表


### 一、核心术语定义

| 术语 | 精确定义 |
|------|---------|
| **AI生产力系统** | 一个以“个人”为中心、可不断扩展的AI工作平台，能让AI进入用户的工作流、帮助完成具体任务 |
| **系统内核** | 稳定不变的底层组件：存储引擎、检索引擎、模块加载器、配置管理 |
| **功能模块** | 可插拔的独立功能单元，实现BaseModule接口，通过配置文件启用/禁用 |
| **场景** | 一组特定模块的组合，对应一个使用场景。如“测试场景”=采集器+视觉+推理+报告 |
| **存量逻辑** | 五个历史数据的集合：历史Story、历史PRD、页面快照、历史Bug、历史Case |
| **页面快照** | 某一时间点页面的完整记录：DOM树 + Accessibility Tree + 截图 + 时间戳 |
| **五维输入** | 生成测试点时的五个输入维度：新Story + 存量Story + 页面快照 + 历史Bug + 历史Case |
| **四层架构** | Kernel（内核层）、Modules（模块层）、Data（数据层）、Interfaces（界面层） |
| **V0.1-V0.5** | 五个可交付版本，每个版本独立可用，逐步叠加功能 |


### 二、实体术语定义

| 实体 | 定义 | 关键字段 |
|------|------|---------|
| **Story** | 单个需求条目 | id, title, description, version, customer, status, created_at, module |
| **PRD** | 产品需求文档 | id, title, version, content, created_at, status |
| **Bug** | 缺陷记录 | id, title, description, severity, module, status, created_at, closed_at |
| **Case** | 测试用例 | id, title, steps, expected_result, module, version, status |
| **Snapshot** | 页面快照 | id, version, page_url, dom, accessibility_tree, screenshot_ref, created_at |
| **TestPoint** | 测试点 | id, source, dimension_weights (JSON), status, created_at, updated_at |
| **TestCase** | 完整测试用例 | id, test_point_id, format, execution_status, screenshots (array), created_at |


## 第三部分：完整目录结构


### 一、项目根目录

```
MyAIProductionSystem/                         # ← 项目根目录（整体复制即迁移）
│
├─ kernel/                                    # ======== 系统内核层（稳定不变） ========
│  ├─ storage/
│  │  ├─ __init__.py
│  │  ├─ chroma_client.py                     # Chroma持久化客户端封装
│  │  └─ vector_operations.py                 # 增删改查操作
│  ├─ retriever/
│  │  ├─ __init__.py
│  │  ├─ hnsw_index.py                        # HNSW检索引擎
│  │  ├─ bm25_retriever.py                    # 关键词检索（BM25）
│  │  └─ hybrid_search.py                     # 混合检索（BM25+向量）
│  ├─ loader/
│  │  ├─ __init__.py
│  │  ├─ module_scanner.py                    # 动态扫描modules/目录
│  │  └─ module_loader.py                     # 加载/卸载模块
│  └─ config/
│     ├─ __init__.py
│     ├─ config_manager.py                    # 统一配置管理
│     └─ config_validator.py                  # 配置校验
│
├─ modules/                                   # ======== 功能模块层（可插拔） ========
│  │
│  ├─ collector/                              # 模块1：数据采集器
│  │  ├─ __init__.py
│  │  ├─ manifest.yaml                        # 模块声明（名称/版本/依赖）
│  │  ├─ adapters/
│  │  │  ├─ __init__.py
│  │  │  ├─ base_adapter.py                   # 适配器基类
│  │  │  ├─ devops_platform/                  # 组里平台适配器
│  │  │  │  ├─ __init__.py
│  │  │  │  ├─ api_client.py                  # API调用封装
│  │  │  │  ├─ story_fetcher.py               # 拉取Story
│  │  │  │  ├─ bug_fetcher.py                 # 拉取缺陷
│  │  │  │  └─ case_fetcher.py                # 拉取用例
│  │  │  ├─ screenshot/
│  │  │  │  ├─ __init__.py
│  │  │  │  ├─ playwright_manager.py          # Playwright浏览器管理
│  │  │  │  ├─ page_loader.py                 # 页面加载和等待
│  │  │  │  └─ screenshot_taker.py            # 截图执行
│  │  │  └─ design_upload/
│  │  │     ├─ __init__.py
│  │  │     └─ upload_handler.py              # 设计稿上传处理
│  │  └─ tests/
│  │     ├─ test_api_client.py
│  │     ├─ test_screenshot.py
│  │     └─ test_upload.py
│  │
│  ├─ vision/                                 # 模块2：视觉识别
│  │  ├─ __init__.py
│  │  ├─ manifest.yaml
│  │  ├─ page_analyzer/
│  │  │  ├─ __init__.py
│  │  │  ├─ dom_parser.py                     # DOM树解析
│  │  │  ├─ accessibility_parser.py           # Accessibility Tree解析
│  │  │  ├─ screenshot_analyzer.py            # 截图分析（备用）
│  │  │  └─ structure_fuser.py                # 三者融合生成页面结构
│  │  ├─ design_reader/
│  │  │  ├─ __init__.py
│  │  │  ├─ multimodal_analyzer.py            # CLIP/GPT-4o调用
│  │  │  └─ layout_extractor.py               # 布局和交互提取
│  │  ├─ flow_extractor/
│  │  │  ├─ __init__.py
│  │  │  └─ sequence_analyzer.py              # 交互流程提取
│  │  └─ tests/
│  │     ├─ test_dom_parser.py
│  │     ├─ test_fuser.py
│  │     └─ test_multimodal.py
│  │
│  ├─ inference/                              # 模块3：推理引擎
│  │  ├─ __init__.py
│  │  ├─ manifest.yaml
│  │  ├─ agents/                              # Agent编排
│  │  │  ├─ __init__.py
│  │  │  ├─ base_agent.py                     # Agent基类
│  │  │  ├─ story_agent.py                    # Story解析Agent
│  │  │  ├─ retriever_agent.py                # 历史数据检索Agent
│  │  │  ├─ planner_agent.py                  # 测试策略规划Agent
│  │  │  ├─ case_agent.py                     # 测试点生成Agent
│  │  │  └─ reviewer_agent.py                 # AI自检Agent
│  │  ├─ pipelines/                           # 执行管道
│  │  │  ├─ __init__.py
│  │  │  ├─ five_dim_pipeline.py              # 五维输入→测试点
│  │  │  └─ case_conversion.py                # 测试点→测试用例
│  │  ├─ diff_highlighter/                    # 版本变更高亮
│  │  │  ├─ __init__.py
│  │  │  └─ version_diff.py                   # Story/PRD版本对比
│  │  └─ tests/
│  │     ├─ test_story_agent.py
│  │     ├─ test_pipeline.py
│  │     └─ test_diff.py
│  │
│  ├─ reporter/                               # 模块4：报告生成
│  │  ├─ __init__.py
│  │  ├─ manifest.yaml
│  │  ├─ test_report/
│  │  │  ├─ __init__.py
│  │  │  └─ word_generator.py                 # 测试报告Word生成
│  │  ├─ defect_report/
│  │  │  ├─ __init__.py
│  │  │  └─ word_generator.py                 # 缺陷报告Word生成
│  │  ├─ case_exporter/
│  │  │  ├─ __init__.py
│  │  │  └─ excel_exporter.py                 # 用例导出Excel
│  │  ├─ screenshot_editor/                   # 截图手动微调
│  │  │  ├─ __init__.py
│  │  │  ├─ association_manager.py            # 截图-用例关联管理
│  │  │  └─ correction_memory.py              # 用户修正记忆
│  │  └─ tests/
│  │     ├─ test_word_gen.py
│  │     └─ test_excel_export.py
│  │
│  ├─ api_adapter/                            # 模块5：多API适配
│  │  ├─ __init__.py
│  │  ├─ manifest.yaml
│  │  ├─ providers/
│  │  │  ├─ __init__.py
│  │  │  ├─ base_provider.py                  # Provider基类
│  │  │  ├─ kimi/
│  │  │  │  ├─ __init__.py
│  │  │  │  └─ provider.py
│  │  │  ├─ doubao/
│  │  │  │  ├─ __init__.py
│  │  │  │  └─ provider.py
│  │  │  ├─ claude/
│  │  │  │  ├─ __init__.py
│  │  │  │  └─ provider.py
│  │  │  ├─ deepseek/
│  │  │  │  ├─ __init__.py
│  │  │  │  └─ provider.py
│  │  │  └─ ollama/
│  │  │     ├─ __init__.py
│  │  │     └─ provider.py
│  │  ├─ factory.py                           # 抽象工厂
│  │  └─ tests/
│  │     └─ test_providers.py
│  │
│  ├─ monitor/                                # 模块6：监控通知（预留）
│  │  ├─ __init__.py
│  │  ├─ manifest.yaml
│  │  ├─ defect_watcher.py                    # 缺陷状态监控
│  │  └─ notifier.py                          # 通知推送
│  │
│  ├─ outfit/                                 # 模块7：穿搭助手（预留）
│  ├─ fitness/                                # 模块8：健身管理（预留）
│  └─ dev_assist/                             # 模块9：开发辅助（预留）
│
├─ data/                                      # ======== 数据层 ========
│  ├─ vector_db/                              # Chroma向量库（相对路径）
│  │  └─ chroma_data/                         # 实际数据文件
│  ├─ raw_files/                              # 原始文件存储
│  │  ├─ 01_work/
│  │  │  └─ test/
│  │  │     ├─ stories/                       # Story文件（.md/.json）
│  │  │     ├─ prd/                           # PRD文件（.pdf/.docx/.md）
│  │  │     ├─ bugs/                          # 缺陷文件（.json/.md）
│  │  │     ├─ cases/                         # 用例文件（.xlsx/.json）
│  │  │     ├─ screenshots/                   # 页面截图（.png）
│  │  │     ├─ designs/                       # 设计稿（.png/.jpg/.pdf）
│  │  │     └─ meetings/                      # 会议纪要（.md/.txt）
│  │  ├─ 02_life/                             # 预留：穿搭/健身
│  │  └─ 03_private/                          # 预留：私密数据（加密）
│  ├─ snapshots/                              # 存量逻辑快照
│  │  └─ {version}_{timestamp}/
│  │     ├─ stories.json
│  │     ├─ prd.json
│  │     ├─ page_snapshots.json
│  │     ├─ bugs.json
│  │     └─ cases.json
│  └─ backups/                                # 手动备份
│     └─ backup_{date}.zip
│
├─ interfaces/                                # ======== 界面层 ========
│  ├─ web_ui/                                 # Web界面（Vue3 + Element Plus）
│  │  ├─ public/
│  │  │  └─ index.html
│  │  ├─ src/
│  │  │  ├─ App.vue
│  │  │  ├─ main.js
│  │  │  ├─ components/
│  │  │  │  ├─ ChatPanel.vue                  # 对话面板
│  │  │  │  ├─ FileManager.vue                # 文件管理
│  │  │  │  ├─ TestPointEditor.vue            # 测试点编辑
│  │  │  │  ├─ ExecutionHelper.vue            # 执行辅助
│  │  │  │  ├─ ReportPreview.vue              # 报告预览
│  │  │  │  ├─ SettingsPanel.vue              # 设置面板
│  │  │  │  └─ OnboardingGuide.vue            # 首次引导
│  │  │  ├─ stores/
│  │  │  │  ├─ modules.js                     # 模块状态
│  │  │  │  ├─ api.js                         # API切换状态
│  │  │  │  └─ data.js                        # 数据状态
│  │  │  └─ utils/
│  │  │     └─ api_client.js                  # 后端API调用
│  │  └─ package.json
│  │
│  ├─ mcp_server/                             # MCP服务
│  │  ├─ __init__.py
│  │  ├─ server.py                            # MCP服务主程序
│  │  ├─ handlers/
│  │  │  ├─ query_handler.py                  # 查询工具
│  │  │  ├─ ingest_handler.py                 # 入库工具
│  │  │  └─ switch_handler.py                 # 切换工具
│  │  └─ tests/
│  │     └─ test_mcp.py
│  │
│  └─ api/                                    # RESTful API
│     ├─ __init__.py
│     ├─ main.py                              # FastAPI主程序
│     ├─ routes/
│     │  ├─ chat.py                           # 对话接口
│     │  ├─ files.py                          # 文件管理接口
│     │  ├─ modules.py                        # 模块管理接口
│     │  ├─ inference.py                      # 推理接口
│     │  └─ report.py                         # 报告接口
│     └─ tests/
│        └─ test_api.py
│
├─ prompts/                                   # ======== Prompt管理 ========
│  ├─ system.md                               # 系统级Prompt
│  ├─ story_analyzer.md                       # Story解析Prompt
│  ├─ case_generator.md                       # 测试用例生成Prompt
│  ├─ bug_writer.md                           # 缺陷生成Prompt
│  ├─ report_writer.md                        # 报告生成Prompt
│  ├─ reviewer.md                             # AI自检Prompt
│  └─ version_diff.md                         # 版本对比Prompt
│
├─ logs/                                      # ======== 日志系统 ========
│  ├─ ai_calls.log                            # AI调用记录（模型/输入/输出）
│  ├─ token_usage.log                         # Token消耗统计
│  ├─ retrieval.log                           # 检索耗时和结果
│  ├─ errors.log                              # 错误记录
│  └─ performance.log                         # 各环节耗时
│
├─ config/                                    # ======== 配置中心 ========
│  ├─ system.yaml                             # 系统级配置
│  ├─ models.yaml                             # 模型配置
│  ├─ retriever.yaml                          # 检索配置
│  ├─ rag.yaml                                # RAG配置
│  ├─ vision.yaml                             # 视觉识别配置
│  ├─ playwright.yaml                         # Playwright配置
│  ├─ modules.yaml                            # 模块启用/禁用
│  ├─ mapping.yaml                            # 路径→标签映射
│  └─ api_keys.enc                            # API密钥（AES-256加密）
│
├─ skill_templates/                           # ======== 技能模板 ========
│  ├─ 测试工程师.md                           # 当前使用
│  ├─ 穿搭助手.md                             # 预留
│  └─ 健身营养师.md                           # 预留
│
├─ .specify/                                  # ======== SDD规范 ========
│  ├─ constitution.md                         # 项目宪章（本文件的上半部分）
│  ├─ specs/                                  # 模块规范
│  │  ├─ 001_collector/
│  │  │  ├─ spec.md
│  │  │  ├─ api_contract.yaml
│  │  │  └─ acceptance_criteria.md
│  │  ├─ 002_vision/
│  │  │  └─ spec.md
│  │  ├─ 003_inference/
│  │  │  └─ spec.md
│  │  ├─ 004_reporter/
│  │  │  └─ spec.md
│  │  └─ 005_api_adapter/
│  │     └─ spec.md
│  ├─ tasks/                                  # 任务看板
│  │  ├─ v0.1_tasks.md
│  │  ├─ v0.2_tasks.md
│  │  ├─ v0.3_tasks.md
│  │  ├─ v0.4_tasks.md
│  │  └─ v0.5_tasks.md
│  └─ templates/
│     ├─ spec_template.md
│     └─ test_template.md
│
├─ tests/                                     # ======== TDD测试 ========
│  ├─ unit/                                   # 单元测试
│  │  ├─ test_kernel/
│  │  ├─ test_modules/
│  │  └─ test_interfaces/
│  ├─ integration/                            # 集成测试
│  │  ├─ test_collector_integration.py
│  │  ├─ test_inference_integration.py
│  │  └─ test_e2e.py
│  └─ e2e/                                    # 端到端测试
│     └─ test_full_workflow.py
│
├─ scripts/                                   # ======== 工具脚本 ========
│  ├─ init_project.sh                         # 项目初始化
│  ├─ start_backend.sh                        # 启动后端
│  ├─ start_frontend.sh                       # 启动前端
│  ├─ start_all.sh                            # 一键启动
│  ├─ backup.sh                               # 手动备份
│  └─ migrate.sh                              # 版本迁移
│
├─ AGENTS.md                                  # ======== AI开发规范 ========
├─ CONSTITUTION.md                            # ======== 项目宪章 ========
├─ README.md                                  # ======== 项目说明 ========
├─ requirements.txt                           # Python依赖
├─ requirements-dev.txt                       # 开发依赖
└─ start.sh                                   # 一键启动（入口）
```


## 第四部分：五个版本的详细规划


### 一、V0.1：最小可用产品（MVP）

**目标**：把 Story 喂进去 → AI 生成测试点 → 导出 Excel。省掉 XMind 手工写测试点 + 翻历史用例的时间。

**预计工期**：3-5天

**交付物清单**：

| 交付物 | 说明 |
|--------|------|
| 项目完整目录结构 | 所有目录创建好 |
| Chroma向量库 | 初始化，可读写 |
| Story手动录入功能 | Web界面粘贴或上传.md/.txt |
| 历史用例手动上传功能 | Web界面上传.xlsx |
| RAG检索 | 根据关键词检索历史用例 |
| 测试点生成 | LLM生成测试点列表 |
| 测试点编辑 | 勾选、删减、修改 |
| Excel导出 | 符合自动化运维系统导入格式 |
| Web界面（基础版） | 可操作以上所有功能 |

**详细任务列表**：

| 任务 | 验收标准 |
|------|---------|
| 创建完整目录结构 | 所有目录存在，README.md已生成 |
| 初始化Chroma | 可连接，可写入向量 |
| 实现Story录入 | 支持文本粘贴和.md/.txt上传，显示成功状态 |
| 实现历史用例上传 | 支持.xlsx上传，自动解析并向量化存储 |
| 实现RAG检索 | 输入关键词，返回相关用例列表 |
| 实现测试点生成 | 输入Story，调用LLM返回测试点列表 |
| 实现测试点编辑 | 每个测试点有编辑/删除/勾选按钮 |
| 实现Excel导出 | 导出文件可直接导入自动化运维系统 |
| 实现Web界面 | 所有功能可通过浏览器操作 |
| 实现基础日志 | 记录AI调用和错误 |

**V0.1不做（明确排除）** ：
- ❌ 自动从组里平台拉取（手动复制粘贴）
- ❌ Playwright自动截图
- ❌ 设计稿理解
- ❌ Word报告
- ❌ 缺陷自动生成
- ❌ 多API切换
- ❌ MCP服务
- ❌ 存量逻辑自动积累

**V0.1验收标准**：
1. 你能把Story粘贴进去 → AI生成测试点列表
2. 你能勾选/修改你认为合适的测试点
3. 你能点击“导出Excel” → 拿到符合自动化运维系统导入格式的文件
4. 整个过程不卡顿、不出错


### 二、V0.2：历史数据 + 存量逻辑

**目标**：AI能结合历史Bug和Case生成更准确的用例，五维输入完整。

**预计工期**：+3-5天（累计6-10天）

**新增功能**：

| 功能 | 说明 |
|------|------|
| 历史Bug导入 | 手动上传或API拉取 |
| 历史Case导入 | 手动上传或API拉取 |
| PRD导入 | 手动上传 |
| 存量逻辑存储 | Story/PRD/页面快照/Bug/Case五维存储 |
| 版本变更高亮 | 测试点用绿/黄/红三色标识 |
| 五维输入生成 | 升级推理引擎，五个维度合并 |
| 存量逻辑可视化 | Web界面查看“系统记住了什么” |

**V0.2验收标准**：
1. 导入历史Bug后，AI生成测试点时能引用“哪些模块容易出问题”
2. 导入历史Case后，AI能识别“哪些用例可复用”
3. 版本变更高亮：新增（绿）/存量修改（黄）/PRD缺失推测（红）
4. 存量逻辑面板能显示已存储的五个维度数据


### 三、V0.3：Playwright + 页面结构理解

**目标**：不用手工截图，系统自动截、自动分析、自动关联。

**预计工期**：+3-5天（累计9-15天）

**新增功能**：

| 功能 | 说明 |
|------|------|
| Playwright自动登录 | 模拟登录测试环境 |
| DOM+Accessibility提取 | 获取页面结构 |
| 截图同步获取 | 自动截图 |
| 三者融合分析 | 生成完整页面结构描述 |
| 截图自动关联 | 截图自动匹配用例编号 |
| 执行进度可视化 | 进度条+预估剩余时间 |
| 截图预览确认 | 截图后弹出缩略图确认 |
| 截图手动微调 | 拖拽换图，记录修正历史 |

**V0.3验收标准**：
1. Playwright能自动登录并截取指定页面
2. 页面结构描述准确率≥90%（验证方式：你对比描述与实际页面）
3. 截图自动关联到对应用例，无需手工操作
4. 截图关联错误时，你能手动调整


### 四、V0.4：多模态 + 设计稿理解

**目标**：设计稿也能喂给AI。

**预计工期**：+3-5天（累计12-20天）

**新增功能**：

| 功能 | 说明 |
|------|------|
| 设计稿上传 | Web界面支持拖拽上传 |
| 多模态模型接入 | CLIP（本地）/ GPT-4o（云端） |
| 设计稿→页面描述 | AI理解布局和交互 |
| 设计稿持久化 | 作为存量逻辑一部分 |

**V0.4验收标准**：
1. 上传设计稿截图后，AI能描述页面布局和交互流程
2. 描述内容与实际设计稿匹配度≥80%
3. 设计稿信息被纳入存量逻辑，后续可复用


### 五、V0.5：全链路自动化

**目标**：从Story到报告，一站式自动化。

**预计工期**：+3-5天（累计15-25天）

**新增功能**：

| 功能 | 说明 |
|------|------|
| 自动缺陷生成 | 失败时AI生成缺陷草稿（可编辑） |
| 测试报告Word | 一键生成，模板可自定义 |
| 缺陷报告Word | 一键生成，模板可自定义 |
| 多API切换 | Kimi/豆包/Claude/DeepSeek/Ollama |
| 缺陷与用例双向绑定 | 互相关联 |
| MCP服务 | 对接Claude Desktop |
| 报告预览 | 生成前先预览确认 |
| 中间态报告 | 测试中也能生成进度报告 |

**V0.5验收标准**：
1. 执行失败时AI自动生成缺陷草稿
2. 一键生成Word测试报告和缺陷报告
3. Web界面下拉切换API，立即生效
4. 完整链路：Story导入→测试点生成→执行辅助→报告生成，一站式完成


## 第五部分：详细Spec模板


### 一、Spec标准格式

每个模块的spec.md必须包含以下内容：

```markdown
# 模块规范：{模块名称}

## 一、功能描述
{用1-2段话描述这个模块是干什么的}

## 二、用户故事
- 作为{角色}，我希望{功能}，以便{价值}

## 三、验收标准（Given-When-Then格式）

### AC-001: {场景名称}
- Given: {前置条件}
- When: {用户操作}
- Then: {期望结果}
- And: {额外条件}

### AC-002: {异常场景}
- Given: {异常条件}
- When: {用户操作}
- Then: {系统响应}

## 四、接口契约

### 输入
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|

### 输出
| 字段 | 类型 | 说明 |
|------|------|------|

## 五、边界条件
- 场景1: {边界条件} → {预期行为}
- 场景2: {边界条件} → {预期行为}

## 六、性能要求
- {具体指标}
```


### 二、采集器Spec示例（001_collector/spec.md）

```markdown
# 模块规范：采集器（Collector）

## 一、功能描述

采集器负责从多个数据源获取原始数据，存入本地data/raw_files/目录。支持三种数据源：
1. 组里平台API（Story/缺陷/用例）
2. Playwright自动截图
3. 用户手动上传（设计稿/会议纪要/历史用例）

## 二、用户故事

- 作为测试工程师，我希望系统能从组里平台自动拉取Story，以便我不用手工复制
- 作为测试工程师，我希望系统能自动截取测试环境页面，以便我不用手工截图
- 作为测试工程师，我希望上传设计稿时支持拖拽，以便操作更便捷

## 三、验收标准

### AC-001: 成功拉取Story列表
- Given: 组里平台API可访问，管理员账号有效
- When: 用户点击“拉取数据”按钮
- Then: 系统成功拉取所有Story，存入data/raw_files/01_work/test/stories/
- And: Web界面显示“拉取成功，共N条Story”
- And: 每个Story文件名为{story_id}_{title}.md

### AC-002: API超时处理
- Given: 组里平台API响应超时（>30秒）
- When: 用户点击“拉取数据”按钮
- Then: 系统显示“拉取超时，请检查网络或稍后重试”
- And: 系统记录错误日志到logs/errors.log
- And: 不覆盖已有数据

### AC-003: 页面截图自动命名
- Given: 用户执行测试用例
- When: 系统自动截图
- Then: 截图按“{用例编号}_{操作动作}_{时间戳}.png”格式命名
- And: 截图保存到data/raw_files/01_work/test/screenshots/
- And: 截图信息记录到logs/performance.log

### AC-004: 设计稿拖拽上传
- Given: 用户打开设计稿上传界面
- When: 用户拖拽图片/PDF到上传区域
- Then: 文件自动上传到data/raw_files/01_work/test/designs/
- And: 显示上传进度条
- And: 上传成功后显示缩略图预览

## 四、接口契约

### 输入
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| source_type | enum | 是 | devops_api / screenshot / manual_upload |
| config | dict | 是 | 包含认证信息和参数 |

### 输出
| 字段 | 类型 | 说明 |
|------|------|------|
| success | bool | 是否成功 |
| message | string | 成功/失败消息 |
| data | dict | 拉取的数据 |
| errors | list | 错误列表（如果有） |

## 五、边界条件

- 磁盘空间不足 → 提示“空间不足，请清理后重试”，停止写入
- 已有数据重复 → 增量更新（检查content_hash），不覆盖用户修改
- 网络中断 → 自动重试3次，间隔5秒，失败后提示用户手动重试

## 六、性能要求

- 拉取100条Story耗时<10秒
- 截图耗时<3秒/页
- 上传100MB文件耗时<30秒
```


## 第六部分：开发契约


### 一、AI开发行为规范

| 规范 | 说明 |
|------|------|
| 先想后写 | 写代码前先说明假设、权衡，不懂就问 |
| 最小实现 | 不加没要求的抽象、配置、兼容性 |
| 精准修改 | 只改必须改的地方，不做顺手重构 |
| 复用优先 | 先检查有没有现成的东西可用 |
| 原则优于规则 | “简单优先”是最高原则 |


### 二、代码规范

| 规范 | 说明 |
|------|------|
| Python命名 | 模块/文件用小写+下划线，类用驼峰 |
| 类型注解 | 所有函数必须标注类型 |
| 文档字符串 | 每个模块、类、公共函数必须有docstring |
| 错误处理 | 所有外部调用必须try-except |
| 日志记录 | 关键操作必须记录日志 |


### 三、AI调用规范

| 规范 | 说明 |
|------|------|
| 系统Prompt | 使用prompts/system.md作为系统Prompt |
| 任务Prompt | 每个任务使用对应的prompts/{task}.md |
| 引用标注 | 所有输出必须标注信息来源 |
| 不知道就承认 | 不确定时不编造 |
| 思考过程展示 | 显示推理过程 |


### 四、Git提交规范

| 规范 | 说明 |
|------|------|
| 提交粒度 | 按功能点提交，不混合多个功能 |
| 提交信息 | feat: 新功能 / fix: 修复 / docs: 文档 / test: 测试 / refactor: 重构 |
| 关联任务 | 提交信息必须关联任务ID（如 TSK-001） |


## 第七部分：边界条件与异常处理


### 一、边界条件清单

| 场景 | 预期行为 |
|------|---------|
| 数据库为空 | 引导页显示“请先导入数据”，提供“导入Story”按钮 |
| API调用超时 | 自动重试3次，间隔5秒，失败后提示用户 |
| 磁盘空间不足 | 提示清理，停止写入 |
| 文件格式不支持 | 提示“不支持此格式”，列出支持的格式列表 |
| 数据重复 | 增量更新，不覆盖用户手动修改的内容 |
| 模型不可用 | 自动切换到备用模型，提示用户 |
| 网络断开 | 提示“网络断开，请检查连接”，自动重试 |
| 登录态过期 | 提示“登录已过期，请重新登录”，引导用户操作 |
| 并发冲突 | 锁机制，防止同时写入 |
| 向量库损坏 | 手动备份恢复按钮 |


### 二、错误码定义

| 错误码 | 含义 | 处理方式 |
|--------|------|---------|
| E001 | API认证失败 | 引导用户检查账号密码 |
| E002 | API超时 | 自动重试3次 |
| E003 | 文件解析失败 | 提示文件格式不正确 |
| E004 | 向量库写入失败 | 提示检查磁盘空间 |
| E005 | 模型调用失败 | 切换到备用模型 |
| E006 | 数据不存在 | 提示“未找到相关数据” |
| E007 | 权限不足 | 提示检查权限配置 |


## 第八部分：环境配置与启动


### 一、系统要求

| 要求 | 最低配置 | 推荐配置 |
|------|---------|---------|
| CPU | 4核 | 8核 |
| 内存 | 8GB | 16GB |
| 磁盘 | 50GB | 100GB |
| 操作系统 | Ubuntu 20.04 / Windows WSL2 | Ubuntu 22.04 |
| Python | 3.10 | 3.11 |


### 二、依赖清单（requirements.txt）

```
# 核心框架
chromadb==0.5.0
fastapi==0.104.1
uvicorn[standard]==0.24.0

# AI模型
sentence-transformers==2.2.2
transformers==4.36.0
torch==2.1.0

# 文档解析
pypdf==3.17.0
python-docx==1.1.0
pandas==2.1.0
openpyxl==3.1.0

# 浏览器自动化
playwright==1.40.0

# 多模态
pillow==10.1.0
clip @ git+https://github.com/openai/CLIP.git

# API适配
httpx==0.25.0
aiohttp==3.9.0

# 日志与监控
loguru==0.7.2
python-json-logger==2.0.7

# 加密
cryptography==41.0.0

# MCP服务
mcp==0.1.0

# 测试
pytest==7.4.0
pytest-cov==4.1.0
pytest-asyncio==0.21.0

# 工具
python-dotenv==1.0.0
pyyaml==6.0.0
```


### 三、启动流程

**首次启动（初始化）** ：
1. 运行 `scripts/init_project.sh` → 创建目录结构、初始化Chroma、生成配置文件
2. 手动修改 `config/api_keys.enc`（填入你的API密钥）
3. 修改 `config/playwright.yaml`（填入组里平台账号密码）
4. 运行 `scripts/start_all.sh` → 启动所有服务

**日常启动**：
1. 运行 `scripts/start_all.sh` → 浏览器打开 `http://localhost:8080`
2. 登录Web界面后即可使用

**迁移到新设备**：
1. 整体复制 `MyAIProductionSystem/` 目录
2. 在新设备安装Python依赖（`pip install -r requirements.txt`）
3. 运行 `scripts/start_all.sh`
4. 无需重新向量化，所有数据自动加载


## 第九部分：V0.1 第一周期执行指令


### 一、第一天任务：项目初始化

AI需要完成以下内容，不能跳过任何一项：

1. **创建完整目录结构**（根目录 `MyAIProductionSystem/`，所有子目录）
2. **生成 CONSTITUTION.md**（使用本文档第一部分内容）
3. **生成 AGENTS.md**（AI开发行为规范）
4. **生成 config/ 下所有配置文件**（system.yaml, modules.yaml, mapping.yaml等）
5. **生成 prompts/ 下所有Prompt模板**
6. **生成 requirements.txt**
7. **生成 scripts/init_project.sh**
8. **初始化 Chroma**（创建空的向量库）
9. **生成 .specify/constitution.md**
10. **生成 .specify/specs/001_collector/spec.md**（采集器规范）


### 二、第二天任务：数据录入与检索

1. **实现 Story 录入功能**（Web界面文本粘贴）
2. **实现历史用例上传功能**（Excel上传）
3. **实现 Chroma 向量化存储**（自动解析并向量化）
4. **实现 RAG 检索**（关键词搜索返回相关用例）


### 三、第三天任务：测试点生成与导出

1. **实现测试点生成**（LLM调用 + 测试点列表展示）
2. **实现测试点编辑**（勾选/删减/修改）
3. **实现 Excel 导出**（符合自动化运维系统导入格式）


### 四、第四天任务：验收测试

1. **自己走一遍完整流程**（Story录入 → 检索 → 生成 → 导出）
2. **检查测试点质量**（能不能用、准不准、格式对不对）
3. **修复发现的阻塞性问题**
4. **确认 V0.1 验收标准全部通过**


## 第十部分：常见问题处理指南


### 一、遇到问题时的处理流程

| 步骤 | 操作 |
|------|------|
| 1 | 查看 `logs/errors.log`，找到具体错误信息 |
| 2 | 根据错误码查询本手册“第七部分-错误码定义” |
| 3 | 无法解决时，向AI描述现象 + 错误日志，让AI定位修复 |
| 4 | 修复后重新运行，验证问题已解决 |


### 二、与AI沟通的模板

**告知AI出了问题：**
> “V0.1的Story录入功能报错了，错误日志显示 {具体错误}，帮我定位修复。”

**告知AI需求变更：**
> “我想在V0.1增加一个功能：{具体需求}，评估一下工期和改动范围。”

**告知AI功能验证结果：**
> “测试点生成功能我用了一个迭代的真实Story测试，发现以下问题：{具体问题}，帮我修正。”


## 第十一部分：完整需求追溯矩阵

| 需求编号 | 需求内容 | V0.1 | V0.2 | V0.3 | V0.4 | V0.5 |
|---------|---------|------|------|------|------|------|
| R1 | 拉取Story | ✅ | ✅ | ✅ | ✅ | ✅ |
| R2 | 拉取缺陷 | | ✅ | ✅ | ✅ | ✅ |
| R3 | 拉取用例 | | ✅ | ✅ | ✅ | ✅ |
| R4 | 存量逻辑五维存储 | | ✅ | ✅ | ✅ | ✅ |
| R5 | 页面结构理解 | | | ✅ | ✅ | ✅ |
| R6 | 设计稿理解 | | | | ✅ | ✅ |
| R7 | 五维输入生成 | | ✅ | ✅ | ✅ | ✅ |
| R8 | Excel导出 | ✅ | ✅ | ✅ | ✅ | ✅ |
| R9 | 执行读取用例 | | | ✅ | ✅ | ✅ |
| R10 | 截图自动关联 | | | ✅ | ✅ | ✅ |
| R11 | 自动生成缺陷 | | | | | ✅ |
| R12 | Word报告 | | | | | ✅ |
| R13 | 多API切换 | | | | | ✅ |
| R14 | 思考过程展示 | ✅ | ✅ | ✅ | ✅ | ✅ |
| R15 | AI不知道就承认 | ✅ | ✅ | ✅ | ✅ | ✅ |
| U-D1 | 版本变更高亮 | | ✅ | ✅ | ✅ | ✅ |
| U-D2 | 截图手动微调 | | | ✅ | ✅ | ✅ |
| U-D3 | 场景预设保存 | | ✅ | ✅ | ✅ | ✅ |
| U1-U30 | 体验缺陷修复 | 逐步修复 | 逐步修复 | 逐步修复 | 逐步修复 | 全部完成 |


## 第十二部分：V0.1 落地更新（2026-07-20）

本部分记录自上述 PRD 定稿后，根据审阅建议、源码基座（AnythingLLM）现状以及实际可执行性所做的关键调整。

### 一、落地范围确认

- **落地位置**：`anything-llm-master/MyAIProductionSystem/`（与 AnythingLLM 源码同仓库但完全独立，不改造 AnythingLLM）。
- **遵循技术栈**：Python 3.10+ / FastAPI / Vue3 / Element Plus / Chroma / bge-small-zh / Playwright。
- **当前完成阶段**：顶层设计补齐 + V0.1 后端 + V0.1 前端骨架 + 基础测试。

### 二、顶层设计修正

| 修正项 | 原 PRD | 落地实现 |
| -------- | -------- | --------- |
| 共享数据模型 | 术语表有字段，无统一代码位置 | 新增 `shared/schemas.py`（Pydantic v2）和 `shared/types.py` |
| LLM Provider | V0.5 才出现多 API 切换 | 提前到 `kernel/llm/providers/`，V0.1 默认 OpenAI 兼容协议（DeepSeek），Ollama 单独实现 |
| 配置中心 | 多 YAML 文件可能冲突 | 统一用 Pydantic Settings，加载顺序：env > YAML > default |
| 私密数据隔离 | 只有原则 | 新增 `kernel/security/vault.py`（AES-256-GCM + PBKDF2HMAC + 审计日志） |
| 日志系统 | 多文件分存 | 改为结构化 JSON Lines（`logs/app.jsonl`）+ `correlation_id` |
| HNSW 索引 | `kernel/retriever/hnsw_index.py` | 删除，统一用 Chroma 内置 HNSW；BM25/hybrid 作为 V0.2 组件 |
| 多 API 模块 | `modules/api_adapter` | 重命名为 `modules/llm_bridge`，避免与 `interfaces/api` 混淆 |
| 截图编辑 | `modules/reporter/screenshot_editor` | 调整至 `modules/vision/media_manager/`，减少跨模块耦合 |
| 设计稿理解 | CLIP（本地） | 改为本地 VLM / GPT-4o；CLIP 无法生成自然语言描述 |
| 内存目标 | < 500 MB | V0.1 放宽为 < 1.5 GB（本地 embedding + torch 现实值） |
| MCP 包 | `mcp==0.1.0` | 暂不引入，V0.5 再评估官方 Python MCP SDK 正确包名 |

### 三、V0.1 已实现功能

1. **项目骨架**：完整目录结构、`CONSTITUTION.md`、`AGENTS.md`、`README.md`、工程配置。
2. **配置中心**：`kernel/config/settings.py` + `config/*.yaml`。
3. **日志基座**：`kernel/logging.py` 结构化日志 + 请求 correlation_id。
4. **安全基座**：`kernel/security/vault.py` + `kernel/utils/path_security.py`。
5. **向量库**：`kernel/vector_db/chroma.py` + collection 名称规范化 + 按 `document_id` 删除。
6. **LLM/Embedding**：`kernel/llm/providers/openai_compatible.py`、`kernel/llm/embeddings/bge_embedder.py`。
7. **采集器**：Story 录入/上传、历史用例 Excel 解析与向量化、文件上传安全校验。
8. **检索器**：基于 bge-small-zh + Chroma 的历史用例向量检索。
9. **推理引擎**：`TestPointPipeline` + `TestPointAgent`，Prompt 外置于 `prompts/case_generator.md`。
10. **报告导出**：Excel 导出（默认 + 自动化运维导入模板）。
11. **RESTful API**：`/stories`、`/cases/upload`、`/retrieval/cases`、`/test-points`、`/export/test-points`。
12. **Web UI**：Vue3 + Element Plus 四页面：Story 录入、历史用例、检索验证、测试点生成/编辑/导出。
13. **测试**：单元测试 + 集成测试 + Eval Harness 最小实现。

### 四、V0.1 明确不做（与原 PRD 一致）

- 自动从外部平台拉取 Story/Bug/Case
- Playwright 自动截图
- 设计稿理解
- Word/PDF 报告
- 缺陷自动生成
- 多 API 切换 UI
- MCP 服务
- 私密数据 Vault 完整 UI

### 五、下一步工作

1. 安装依赖并跑通 `pytest`（`python -m pip install -r requirements.txt && pytest`）。
2. 填入 `.env` 中的 `LLM_API_KEY`。
3. 运行 `python scripts/init_project.py` 初始化目录与 `.env`。
4. 运行 `python scripts/start_dev.py` 启动后端 + 前端。
5. 手工走通：Story 录入 → 用例上传 → 检索 → 测试点生成 → 编辑 → 导出 Excel。
6. 根据实测问题补全测试、修复边界 bug。

### 六、关键文件索引

| 文件 | 说明 |
| -------- | --------- |
| `MyAIProductionSystem/CONSTITUTION.md` | 项目宪法（含模块依赖禁令） |
| `MyAIProductionSystem/AGENTS.md` | AI 开发规范 |
| `MyAIProductionSystem/pyproject.toml` | Python 依赖与工具配置 |
| `MyAIProductionSystem/shared/schemas.py` | 所有实体 Pydantic 模型 |
| `MyAIProductionSystem/kernel/config/settings.py` | 统一配置中心 |
| `MyAIProductionSystem/kernel/vector_db/chroma.py` | Chroma 实现 |
| `MyAIProductionSystem/kernel/llm/factory.py` | LLM/Embedder 工厂 |
| `MyAIProductionSystem/interfaces/api/main.py` | FastAPI 入口 |
| `MyAIProductionSystem/interfaces/web_ui/src/views/TestPointView.vue` | 测试点生成与导出页面 |
| `MyAIProductionSystem/prompts/case_generator.md` | 测试点生成 Prompt |
| `MyAIProductionSystem/tests/integration/test_story_to_export.py` | 端到端集成测试 |

---

**本文档结束。**
