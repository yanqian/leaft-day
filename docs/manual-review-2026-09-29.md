# 2026-09-29 手动验收 v3

用户批准 `docs/design/ui-manual-review-v3-unified-glass.png`：“嗯 比较cool，就这样。” 实现和自动验收仍分别记录。

## 问题与边界

1. 短片段可能只有1项：原2小时分段及会话边界行为导致，并不以旧手势测试通过否定反馈。F021新增连续浏览；继续跨片段，随机优先多张，周年当天不暗中扩大。
2. 删除后仍显示的是App待删复核/确认清单：固定targets始终渲染，结果只追加文案。F015重开，成功结果替换清单，读取真实剩余意图，未知/取消/失败不清空。
3. 原底栏190pt且regular白玻璃过重：F009重开，已实现两条轻薄clear玻璃、居中日期数量、两侧翻页和独立退出/缩放。复核/完成页已由F015接入同材质。

## 验证状态

- F009：独立通过，`.agent-harness/runs/20260929T0356Z-F009-evaluation.md`；两条玻璃底栏、横屏/大字/不透明回退已留实际截图。
- F015：独立通过，`.agent-harness/runs/20260929T0706Z-F015-evaluation.md`；首次说明/网格/真实取消和成功/旧清单替换/新意图保留均通过。
- F021：独立通过，`.agent-harness/runs/20260929T0736Z-F021-evaluation.md`；最终独立完整回归 `.build/test-run.oQJ6Tl/Tests.xcresult`：71单元/23UI，零失败及跳过；SE3末尾视频横屏另行通过。
- 签名新版已原位安装到测试手机，保留App数据；`.build/v3-device-install.json`确认 `outcome=success` 及 `dev.armstrong.swipego`。构建哈希回执为 `.build/v3-device-build-receipt.json`。可以继续手动复测。
- F018：既有真机/iCloud/大图库未完成项继续pending，本轮模拟器测试不能代替。
- 没有提交代码、没有导出个人手机数据库、没有在私人图库执行测试删除。

## 复测重点

1. 首页继续回顾和随机时光，多次左右滑动；周年日只有一项时使用“继续看附近日期”。
2. 轻触显隐玻璃底栏、左右横屏、视频进度与缩放。
3. 待删复核的首次说明和再次展开；取消后清单保留，成功后结果页替代旧清单，显示真实剩余数。

## 实际截图（生成测试素材）

- [两条玻璃底栏](design/F009-v3-glass-2.png)
- [复核网格](design/F015-v3-deletion-review.png)
- [删除完成](design/F015-v3-deletion-complete.png)
- [周年单项接续](design/F021-anniversary-single.png)
- [小屏末尾视频横屏](design/F021-compact-terminal-landscape.png)

成功页的粉色来自测试现场创建的纯红图片作为柔化背景，并非固定产品配色。日期导航UI采用真实生成媒体ID与明确的测试日期元数据，不把这一证据冒充私人图库或iCloud实测。
