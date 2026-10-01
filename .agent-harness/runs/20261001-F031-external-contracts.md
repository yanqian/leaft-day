# F031 外部行为与编码阶段证据

- Role: Coding Agent；本记录不是独立验收结论。
- Startup完整旧入口通过：`.build/F031-startup.log`，`.build/test-run.j3fZwZ/Tests.xcresult`，85单元/44 UI；仅启动基线，不代替最终实现验证。
- 实际命令契约：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path <bundle>`；`get test-results tests`；`export attachments --help/--schema`。系统默认xcode-select指向CommandLineTools，首次无DEVELOPER_DIR时工具不存在；沿用原doctor的完整Xcode选择，不切换全局设置。
- fixtures/xcresult-summary-passed.json 来自 `.build/test-run.AUYR9H/Tests.xcresult`，129 passed。
- fixtures/xcresult-summary-failed.json 来自 `.build/test-run.AVqOFg/Tests.xcresult`，128 passed/1 failed，真实LaunchTests失败对象字段。
- fixtures/xcresult-tests.json 来自 AUYR9H 的实际测试树；85 SwipeGoTests + 44 SwipeGoUITests。
- fixtures/xcresult-attachments.json 来自该bundle的LaunchTests/testColdLaunchAndRelaunchShowRoot()导出，保留真实manifest格式。
- 全量实际附件导出 `.build/F031-all-attachments/`：96附件、95个唯一语义截图key解析成功。
- 原生 `sips -s format bmp` 对实际1206×2622截图输出 BMP BITMAPINFOHEADER 40、24bit、无压缩、top-down；reader处理行对齐/正反高度并拒绝未知格式。AppIcon原生sips解码也进入Python测试。
- `.build/F031-visual-probe/` 只作真实截图基准自比较探针，结果passed；没有批准或覆盖产品默认视觉基准。
- 首次非提权work-fast provider runtime因Codex本地状态只读失败；正式提权后runtime check和handoff成功。未更改provider。
- `.build/verification/20261001T164207-7cwlav_n/` 是主动中断的早期候选：预检期间脚本修改可能导致执行版本与指纹不一致，停止该进程及其子进程并保留failed/Interrupted报告。新增启动到预检结束的输入保护及契约测试，不重试掩盖证据。
- 最终编码候选真实 `./verify.sh --changed` 自动回退full正在执行，日志 `.build/F031-verification-final.log`。完成后另写handoff；当前不写编码完成标记。
