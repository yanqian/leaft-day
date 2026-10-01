# v8 原生 UI 实施与验收矩阵

批准方向：照片颜色 → 低饱和提亮渐变 → 原生 Liquid Glass。以下为真实 SwiftUI 截图，测试照片为生成素材；概念图和 HTML 不作为实现验收证据。

| 表面 | 配色和状态 | 原生截图 | Feature / 验收 |
|---|---|---|---|
| 共享取色、玻璃卡片与按钮 | 64×64 sRGB取色、最多3色；暗/亮/透明/无图默认；丢弃旧回调 | [草木](F026-草木.png)、[海蓝](F026-海蓝.png)、[暖桃](F026-暖桃.png) | F026 独立通过 |
| 首页、主卡、双卡、待删入口 | 复用已加载hero；无图/加载/离线/失败均可读 | [首页](F027-F009-home-real-library.png) | F027 独立通过 |
| 首次授权 | 默认清淡渐变；未授权不读取装饰照片 | [授权](F027-F025-welcome-glass.png)、[最大字号](F027-welcome-readable-final.png) | F027 独立通过 |
| 设置 | 本地授权照片取色；真实权限与数量；正文与底部按钮分区 | [设置](F027-F022-settings-glass.png) | F027 独立通过 |
| 待删复核与保留对照 | 待删照片本地取色；资源变化/空/错误玻璃状态 | [复核](v8-F015-deletion-review.png) | F015 独立通过 |
| 确认、执行、删除结果 | 确认前冻结RGB；成功后不重读已删除照片；五种真实结果语义 | [确认](v8-F015-fixed-confirmation.png)、[结果](v8-F015-v3-deletion-complete.png)、[最大字号](v8-F015-confirm-large-opaque.png) | F015 独立通过 |
| 删除记录 | 接收冻结色板；独立入口默认渐变；最近20条真实记录 | [记录](v8-F024-real-history.png)、[空](v8-F024-history-empty.png)、[最大字号](v8-F024-history-large-opaque.png) | F028 独立通过 |
| 操作核对 | 默认/调用方色板；未知不等于成功，核对不清除待删 | [核对](v8-F017-reconciliation.png)、[最大字号](v8-F028-reconciliation-large-opaque.png) | F028 独立通过 |
| 相似比较 | 当前组照片取色；选择/保留/保存/跳过语义保持 | [比较](v8-F029-comparison-real.png)、[空组](v8-F029-comparison-normal.png) | F029 独立通过 |
| 清晰照片、视频与放大 | 原媒体保持fit；浮动玻璃控件，默认收起，原手势不变 | [照片](v8-F020-photo-3.png)、[视频](v8-F019-video-overlay.png)、[放大](v8-F029-comparison-zoom.png) | F029 独立通过 |
| 回顾完成、无会话 | 最近照片色板/默认；玻璃状态、撤销、恢复和返回 | [横屏完成](v8-F023-completed-landscape.png)、[无会话](v8-F029-empty-normal.png) | F029 独立通过 |
| 媒体不可用、下载与重试 | 渐变与玻璃错误/加载状态；大字号可滚动到重试 | [照片](v8-F029-photo-normal.png)、[视频](v8-F029-video-normal.png)、[资源失效](v8-F029-unavailable-normal.png) | F029 独立通过 |

## 验证证据

- F026：`.agent-harness/runs/20260930-F026-evaluation.md`。
- F027：首次视觉验收拒绝了正文透过底部按钮的问题；修复后 `.agent-harness/runs/20260930-F027-reevaluation.md` 独立通过。
- F015：`.agent-harness/runs/20260930-F015-v8-evaluation.md`，85单元/39UI。明确44pt撤回命中区域、最大字号完整确认说明、五种结果和真实生成素材取消/删除。
- F028：`.agent-harness/runs/20260930-F028-evaluation.md`，85单元/40UI。小屏目标6UI通过，包含核对重启、未知语义及待删保留。
- F029：小屏15UI通过 `.build/v8-F029.MA4Net/Tests.xcresult`；横屏完成卡片进一步压缩并补滚动可视范围断言，两项通过 `.build/v8-F029-final-viewport.xcresult`。首次独立85单元/42UI通过后，自查重开最大字号横屏边界；新增2项回归通过 `.build/v8-F029-max-landscape-screen.xcresult`，最终独立复验 `.agent-harness/runs/20261001-F029-reevaluation.md` 通过：85单元/44UI，零失败；完整结果 `.build/test-run.pwIzQ0/Tests.xcresult`。

生产页面已无 `CoastalBackdrop(...)` 或 `RecollectionBackground(...)` 调用。旧定义和历史图片仅为兼容/历史证据保留；原片的黑色留边用于完整显示媒体，不是页面装饰背景。系统授权、删除和照片选择器仍使用原生系统界面。

测试范围为模拟器生成资产及合成异常状态。2026-10-01用户授权后，签名包已原位安装到真机并正常启动；提交前再次通过85单元/44UI（`.build/test-run.TmNGKu/Tests.xcresult`）。F018私人图库/iCloud与真机体验仍待验，安装成功不等于完整体验验收。未推送。

最大字号横屏补充：[完成页返回](v8-F029-completion-largest-landscape-return.png)、[照片重试](v8-F029-photo-largest-landscape-retry.png)、[视频重试](v8-F029-video-largest-landscape-retry.png)。正文和工具栏分别滚动，减少透明度时使用实色辅助模式。
