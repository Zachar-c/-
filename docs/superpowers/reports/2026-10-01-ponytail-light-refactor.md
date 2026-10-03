# Ponytail 项目遍历与轻量重构（2026-10-01）

用户授权遍历项目并实施轻量化重构。本批只简化已有实现，保持对外行为、错误诊断、游戏数值和 Wiki 语义。已有未提交的 Wiki 内容、前端功能和迁移工具改动均保留，不计作本批重构。

## 遍历与选择

先按 Git 受控代码清单遍历，覆盖游戏、Wiki、编辑工具、fortune、AI执行脚本、文档计算器和根工具；678个代码路径包括测试、供应商代码、生成物及原型，不表示全部逐行审查。深入追踪活动入口、调用链与现有测试，Luna子代理分别调查和实施互不冲突的改动，并交叉复审。

| 实施位置 | 简化 | 行为保留依据 |
|---|---|---|
| [编辑索引](../../../editorial/scripts/build_index.py) | 导入已有 `gu_tools.noise_flags`，删除重复实现及不可达越界分支 | 三种标签、regex语义和顺序不变；章节区间最高只到源文末行 |
| [游戏跑局流程](../../../game/wenzhen-web-lab/js/run_flow.js) | 境界显示、突破判断复用现有 `stageIndexFor` | 默认值、上下界及原有不取整行为不变；无新通用工具 |
| [Wiki网页构建](../../../lore/wiki/web/build_app.py) | H1只搜索一次；相对链接共用一次路由赋值 | 保留有/无H1时的标题优先级及缺失目标的标记 |
| [运行时编译](../../../lore/wiki/tools/compile_runtime.py) | 用标准库 `Counter` 替代逐项重复扫描 | 重复ID仍拒绝，诊断列表仍去重且排序；不放宽证据和依赖门禁 |

不合并外观相似但语义不同的实例ID生成器；不复用规则不等价的归一化噪声函数；不更改Godot模块门面与依赖方向。供应商代码、历史原型、生成数据和原著资料不作机械重写。AI执行入口、根文档检查和fortune本轮未发现收益足以抵消风险的必要改动。

## 验证

- `python3 editorial/scripts/test_build_index.py`：2/2通过；同一CP936样本与空源在重构前后生成物一致，metadata仅排除时间戳。
- `python3 lore/wiki/web/test_build_app.py`：4种标题条件与已收录/未收录相对链接检查通过。
- `python3 lore/wiki/tools/test_compile_relations.py`：原关系投影一致，12种字段变更及3种状态缺失均拒绝；重复ID有序唯一诊断检查通过。
- 重构前后逐页比较：238页Wiki完整投影一致；运行时编译均成功，隔离输出的7份JSON一致（只排除manifest时间戳），未重写正式runtime目录。
- `node lore/wiki/web/app/check-app.mjs`、网站构建及 `check_runtime_benchmark.py --pack lore/runtime/packs/south_border_rank1_combat.json` 通过，后者25题引用完整、无死重。
- 游戏直接相关测试36/36通过。扩展WSL全套测试269/276通过，其余7项统一在浏览器发现阶段报缺少Edge/Chrome；将相同Web Lab代码复制到临时Windows目录后，用Windows Node/浏览器补跑两份集成测试，17/17通过，覆盖上述7个浏览器用例；因此276项用例均获得通过结果，但不是WSL单环境全套通过。

文档检查FAIL 0、WARN 0、孤儿0，`git diff --check`通过。

GitHub Issues读取请求返回EOF，未获取远程issue清单；未提交或推送。本报告只记录本批已经实施并可验证的重构，不宣称整个项目没有技术债。
