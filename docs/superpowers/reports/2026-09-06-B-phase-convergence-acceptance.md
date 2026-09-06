# B 系地基收敛 · 合拢验收报告（A-1/B1/B2/B3）

> 日期：2026-09-06
> 分支：`测试，用完就丢`（已备份 gitee，远端 == 本地 `ec10917`）
> 范围：自 C4 蛊目录重建 `85150f7` 之后的 39 个提交（A-1 视觉批次 + B 系三批地基收敛）
> 状态：全量回归绿；合并到 master 待用户裁定

---

## 1. 提交分组

| 批次 | 核心提交 | 内容 | 验证 |
|---|---|---|---|
| A-1 视觉批次落地 | `3cda288` feat + `6e6a7c3` docs | 提交 18 批 wenzhen 视觉成果（官方 .tscn 7 屏 + 资产 + 报告 + 手牌测试修复） | unit UI 守卫 7/7、战斗屏 11/11、真实窗口抽验 5 屏截图 |
| B1 引擎收敛 | `90aefbd` feat（删 battle_resolver）+ 桶 C 系列（`7c3c294`→`ae9c479`）+ `f97bb12` elite_cost 迁移 + `b5b3a34` docs | legacy 卡牌战斗引擎删除（1514 行）；数据/存续契约迁 V1 facade；19 v3 冻结测试退役；守护 `test_legacy_abolition` 转绿 | 定向套件绿；`rg battle_resolver scripts/` 零命中 |
| B2 卡层退役 | `534d610` feat + `3a5b9bf` docs | cards.json/deck_builder.gd/蓝图层退役；gu.json 去 card_blueprint_ids（16 键）；校验改 v1_effect 完备守卫；deck 键迁移 balance | 定向 9 套件绿；scripts/tools 零卡层 token |
| B3 冒烟驱动瘦身 | `3951e4b` feat + `6e9afbc` fix + `e8b3d23` docs + `ec10917` fix | 6 驱动（~2844 行）收编为单一 acceptance_driver.gd（5 模式）；修复 legacy quit 覆盖假绿；修两处断言过期 | smoke 31 OK exit0、play 441 步到 L5 终局、契约 4 套件绿 |

## 2. 全量回归基线（最近一次完整跑）

- **unit：162 scripts / 1093 tests / 1093 passing / 0 failing**
- **integration：11 scripts / 37 tests / 37 passing**
- smoke（headless）：31 OK + INTEGRATION OK，exit 0（含全部 8 .tscn 屏 verify + 真实主场景段）
- play：`PLAYTHROUGH_SEED=42` 441 步推进到 L5 升仙窗尝试飞升进 Ending，222 条日志零错误
- crash check：改入口后子进程实际执行 run/verify/tamper 阶段；编排 restore 清理步在沙箱被个人目录删除保护拦截（需非沙箱环境完整跑通，不在 check.ps1 验收线）

## 3. B3 额外产出（修复型）

- **legacy 假绿修复**：旧 smoke_render 断言失败 quit(1) 后被结尾 quit() 覆盖成 exit 0——shop 屏起的 8 屏 verify 从未真正验证过。新 acceptance_driver 单点 quit + 返回码穿透。
- **两处断言过期修复**：Stage 包装层路径前缀（ShopStage/StageContent 等）；battle 手牌多行卡面按钮改 contains 匹配。
- **crash_recovery_check.ps1 env 健壮性**：注入环境 http_proxy/HTTP_PROXY 大小写重复键导致 Start-Process 崩溃，.NET API 去重修复（`ec10917`）。

## 4. 合并到 master 提案

前置条件：
1. 并行 visual/audio 会话合拢（当前 12 data + 7 presentation M 未提交），避免合并时把未完成内容带入。
2. 用户裁定确认 B 系验收（本报告 §2 基线为证据）。

建议步骤（只读先验，符合 git 纪律）：
```
# 1) 只读预检合并冲突面
git diff --stat master...测试，用完就丢
# 2) 用临时 worktree 试合（不污染工作树，--import 后跑全套件）
git worktree add <tmp> master
git -C <tmp> merge 测试，用完就丢 --no-commit --no-ff   # 或 cherry-pick 39 个
# 3) 验收通过后合主线 + 推送（wincred 绕凭证链）
git push origin HEAD:master
git worktree remove --force <tmp>
```

## 5. 遗留清单（不阻塞 B 系验收）

| 项 | 归属 | 说明 |
|---|---|---|
| V1 蛊槽战斗预览空白 | 预览子系统收敛（B1/B2 均已记录） | `preview_battle_actions` 两分支查已删卡索引恒空；深改需独立工单（含 UI 手牌数据源核对） |
| D1-剩余 | Phase D | 386 方中仅 9 带 source 溯源、synergy 全空、跨流派 4 方；R6-R8 缺输出蛊（月霓裳/月痕蛊/月旋蛊）需策展裁定 |
| crash check 完整跑通 | 工具 | 需非沙箱/真机环境（AppData 存档删除保护） |
| `action_card` 信封 | B1 移交态 | V1 走 facade passthrough，旧信封仅存量测试使用 |
