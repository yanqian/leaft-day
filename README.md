# Swipe-go

iPhone 上以回顾为主的照片与视频工具：随机打开一段连续时光，沉浸浏览，顺手收藏或标记待删，人工复核后再删除。

## 当前状态

2026-09-27：F001 环境检查已通过独立验收；下一项为 F002 可运行 iOS 骨架。产品方向、四屏视觉设计与 iPhone / iOS 26 基线已确认。尚无 App 工程；当前状态以 `.agent-harness/progress.md` 和功能列表为准，未提交 Git。

## 阅读顺序

1. [需求规格](.agent-harness/SPEC.md)：范围、流程、约束、建议默认值与待确认事项。
2. [架构设计](docs/architecture.md)：模块、数据归属、加载与删除流程。
3. [已确认设计](docs/design/approved-design.md) / [设计图](docs/design/ui-approved-liquid-glass-v1.png)。
4. [功能路线图](docs/roadmap.md)：F001 起的依赖与验收边界。
5. [验证方案](docs/verification.md) / [环境与 provider](docs/development.md)。
6. [当前进度](.agent-harness/progress.md) / [机器可读任务](.agent-harness/feature_list.json)。

## 开发规则

按 [AGENTS.md](AGENTS.md) 恢复现场。逻辑状态只在 `.agent-harness/`；根目录 `docs/` 是产品文档，`.agent-harness/docs/` 是工作流规则。

目前 `./init.sh` 只验证 Harness。F002 将其升级为真实 iOS 工程的恢复与 smoke 入口。用户已要求继续；按 `work-fast` 每次实施并验收一个 Feature。
