# 组件开发规范入口

组件开发遵循所属产品的约束，不在 Monorepo 根目录引入统一组件框架。

- 游戏表现层与领域层接口：[领域 UI 契约](game/docs/contracts/2026-09-02-domain-ui-contract.md)。
- 样式与公共组件：[前端全局约束](game/docs/contracts/2026-09-02-frontend-global-constraints.md)。
- 模块依赖与接口：[模块接口索引](game/docs/contracts/module-interfaces/README.md)。
- Web 运行与验证：[Web 可玩版 README](game/wenzhen-web-lab/README.md)。

修改前核对目标实现的契约与依赖；修改后验证交互结果、禁用原因、文本溢出及状态一致性。涉及接口变更时同步其原始契约，不仅修改此导航。

## 无障碍与发布状态

本次仅整理文档，未执行键盘操作、焦点顺序或屏幕阅读器审计，不宣称符合任何无障碍等级。独立组件发布流程与分发清单尚未建立，见 [REGISTRY.md](REGISTRY.md)。
