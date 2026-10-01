# v5 手动验收交付

实现与独立验收已完成，2026-09-30手机恢复连接后，重新核对源码/安装包哈希一致，最终签名包已原位安装成功。安装回执确认 success 且 bundle ID 正确；未卸载或清空数据。人工体验验收仍待反馈。

## 本轮变化

- 首页：增高“去年的今天 / 随机时光”照片卡片，玻璃文字叠层；主卡照片展示空间与日期/回顾按钮重新平衡。垃圾桶待删入口位于内容最底，移除其后的全库可回顾总数。部分授权及待核对提示保留在它上方。
- 删除记录：海岸氛围背景、玻璃记录卡与底部完成；删除结果、时间、数量仍来自真实操作记录。
- 首次授权：同一氛围与玻璃效果，加载/未授权/拒绝状态准确，系统授权弹窗保持原生。已经授权的手机仍直接进入首页。
- 大字号：主卡及双卡的加载、云端加载、离线、不可用、空封面状态按文字流排布，卡片按内容增高，避免被玻璃标题遮住。

## 最终证据

- F024：`.agent-harness/runs/20260929T1529Z-F024-evaluation.md`。
- F025：`.agent-harness/runs/20260930-F025-reevaluation.md`。
- F009：`.agent-harness/runs/20260930-F009-v5-reevaluation.md`。
- 最终独立恢复：`.build/test-run.QKbNHZ/Tests.xcresult`，80 单元 + 36 UI 全通过；原生完整授权前置单独留在同目录 `PermissionSetup.xcresult`。
- 最终小屏：`.build/F009-v5-cover-final.xcresult`，5 UI通过，包含主卡/双卡10种最大字号状态组合。
- 签名构建：`.build/v5-device-final-build.log`；源码/包哈希：`.build/v5-device-build-receipt.json`，安装前已重新核对一致。
- 原位安装成功：`.build/v5-device-reconnect-install.json`，exit 0、outcome success、bundle ID `dev.armstrong.swipego`；连接检查 `.build/v5-reconnect-check.json` 成功。此前离线失败记录 `.build/v5-device-install.json` 与 `.build/v5-device-discovery.json` 保留作为历史。

实际模拟器截图（素材为模拟器样本，实际封面仍使用对应回顾片段中的照片）：

- [首页](design/F009-v5-home-photo-cards.png)
- [首次授权](design/F025-welcome-glass.png)
- [删除记录](design/F024-history-glass-final.png)
- [大字号离线主卡](design/F009-hero-offline-maximum-type.png)
- [大字号离线双卡](design/F009-cover-offline-maximum-type.png)

## 真机复测

安装后检查首页比例、底部待删和垃圾桶图标；进入删除记录确认玻璃风格与完成返回；授权页只在未授权状态展示，无需为了验收卸载现有App。检查大字号下的空照片/离线提示可以完整阅读。人工体验验收仍待反馈。

F018真实iCloud/大图库/性能边界仍未完成；本轮生成素材与模拟器测试不替代它。未提交或推送，未导出手机数据库或测试删除私人照片。
