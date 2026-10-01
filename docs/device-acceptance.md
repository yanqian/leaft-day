# F018 真机验收记录

2026-09-28，iPhone 12 Pro / iOS26.6.2 (23G90)，开发者模式开启，免费Personal Team签名。基线提交00a2fcc，当前F018工作区尚未独立验收/提交。

## 已执行

- 恢复命令 `SWIPE_VERIFICATION_MODE=device ./init.sh` 退出0：完整模拟器回归与2项真机内置Vision控制通过；真机结果 `.build/device-vision.owjs7L/Tests.xcresult`。
- 专用真机UI单机流程通过：`.build/device-acceptance.z3g2x5/Tests.xcresult`，日志 `/private/tmp/swipe-F018-device-flow-final.log`。实际回顾、下滑收藏、视频播放/拖动、原生Vision相似组、收藏固定保留、放大比较、待删选择、系统取消、仅生成清单内1张删除与重启。回执：4项初始清单→3项可见/1项收藏/0项待删。截图见design/F018-device-*.png。
- 仅使用本次生成的3张图和1个视频，创建回执资产ID保存在App专用目录 `Application Support/DeviceAcceptance/<run UUID>/manifest.json`，意图数据库也按run隔离。测试不按文件名挑选手机原片。测试素材目前保留在系统图库/最近删除中，未自动清空最近删除。

- 最终 `./init.sh` 退出0：57 XCTest（含新增DeviceScopeTests）、16 XCUITest、Harness及项目检查通过，模拟器安装启动成功；结果 `.build/test-run.XZLraN/Tests.xcresult`，日志 `/private/tmp/swipe-F018-regression.log`。没有SwiftData Unbinding警告。默认模式的DEVICE_VERIFICATION_DEFERRED仅表示此次命令不运行手机步骤；不否定本轮已单独取得的真机证据。

## 小样本性能基线

`.build/device-acceptance.ewrj3K/Tests.xcresult` 两项真机测试通过，日志 `/private/tmp/swipe-F018-device-metrics.log`；再次覆盖完整受控删除流程，并记录以下3次量测：

| 指标 | 原始值 | 均值与限制 |
|---|---|---|
| 首帧可响应启动时间 | 0.301849 / 0.283992 / 0.288581 秒 | 0.291秒；不是第一张照片加载时间，未控制系统磁盘缓存 |
| 浏览时峰值物理内存 | 131844.800 / 131533.504 / 131599.040 kB | 131659.115 kB，约132MB；只含4项生成素材 |
| 自动化浏览一轮时长 | 11.611945 / 11.612553 / 11.559837 秒 | 11.595秒；包含XCUITest点击与等待，不是帧率或用户操作延迟 |

这些数据不证明大图库、iCloud下载、60fps或真实照片质量。生成素材会跨测试轮次保留；每轮只使用独立manifest中的4项，不清理以前轮次或用户原片。

## 运行入口

`scripts/verify-device-acceptance.sh`只运行DeviceAcceptanceTests，不能替换为整套手机UI测试。脚本使用忽略的.build/device-test.json配置或SWIPE_DEVICE_UDID/SWIPE_DEVELOPMENT_TEAM；手机须解锁连接。DEBUG入口 `--device-acceptance=<UUID>` 经明确创建按钮生成素材，Home/Review的assetScope在原生刷新后仍保持白名单，范围回归测试见DeviceScopeTests。正常启动与Release不进入该测试入口。

首轮命令目标参数格式错误，在执行设备操作前退出；随后UI测试误用0起始比较按钮编号，实际控件从1开始。失败证据保留 `.build/device-acceptance.FaH7q4/Tests.xcresult`，修正测试选择器后完整单机流程通过，不修改产品保护收藏行为。

## 尚未完成

- 真正未下载的iCloud照片/Live Photo/视频、离线/取消/重试及跨设备同步。用户2026-09-28确认没有同一图库的第二台设备，要求跨设备验证先pending；该项暂缓，不视为通过；不会自动登录账户或修改iCloud设置。
- 真机部分权限缩减、受设备管理限制、外部编辑/删除、系统回执窗口真实杀进程。
- 声音实际可闻、VoiceOver与系统辅助功能设置、真实照片样本效果和大图库性能。
- 已测启动与内存仅是4项生成素材的小样本基线，不能证明大图库或60fps。

F018保持in_progress/passes=false，以上单机通过不能替代完整验收；不得写CODING_PASS或要求Evaluator接受未完成的云端/硬件项目。
