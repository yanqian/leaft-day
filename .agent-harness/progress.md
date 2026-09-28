# Progress

## Current System Status

2026-09-28：F001–F013均已独立Evaluator通过；F013待本次提交。免费Personal Team与iPhone12 Pro/iOS26.6.2真机信任就绪。独立root init通过38 XCTest、12 XCUITest、2真机Vision测试，证据runs/20260928-F013-evaluation.md；模拟器Vision异常由fail-closed路径处理，真实质量由每次root init强制真机门禁证明。

仍遵循用户授权：work-fast当前会话实施，每项独立Evaluator通过后提交，再进入下一项。F013已有独立Evaluator Pass；F014–F018没有实施，不得伪称所有Feature完成。

## Last Completed Feature

F013 片段内保守相似分析、缓存与取消，独立Evaluator通过。此前F012提交91a62fb、F011提交7a87c47。

## Next Feature

提交F013后通过make -C .agent-harness work-fast进入F014人工比较。真机配置位于忽略的.build/device-test.json，使用见docs/verification.md。不要在个人手机运行完整图库/UI测试。

新增iOS26.0隔离探针设备F31F5C4A-BA53-47E6-958C-0F1932CC61C8，不含项目Photos fixture；原26.5 fixture设备1DF82DB5-2A3B-450A-9EB5-098FC4E8F812保留。诊断证据runs/20260928-F013-diagnostics.md。运行中的命令以当前会话为准。

## Known Issues

- iCloud 共享图库成员无法由已核实公开 API 可靠区分；共享相簿/隐藏项已过滤，共享图库明确暂不支持，不能假称排除。用户2026-09-28在通俗解释后确认没有使用iCloud共享照片图库，首版按个人图库继续。F016仍需产品内明确适用范围与人工复核/系统确认；此声明不是API自动识别，也不是授权测试删除个人照片。
- 免费Personal Team签名/手机信任已完成，内置Vision真机测试通过；真实iCloud未下载素材仍待F018。设备前检见runs/20260928-F013-device-preflight.md。
- 首页已接实际图库/会话与原生玻璃，F010已接入沉浸手势；F011已接系统收藏，F012本地待删已验收；尚无业务删除。
- Harness 有本地 unborn Git startup 修复，见 F001 runs；未来升级需审查。

## Recovery Notes

运行 ./init.sh：Harness（强制 F001 起独立证据）、生成 fixture、Python检查、XcodeGen、模拟器 boot、真实 XCTest/XCUITest、安装启动。使用本地 ad-hoc 模拟器签名，无需证书/团队，避免无签名旧二进制缓存。测试前仅卸载项目 UI runner，不擦除 App 或图库。SWIPE_SIMULATOR_UDID 可指定测试模拟器；DEVELOPER_DIR 不改全局。

SwiftData 使用 ModelActor/DefaultSerialModelExecutor，失败 rollback 后丢弃工作 context；root 拒绝 Unbinding 警告。PhotoKit 跨 actor 只传 Sendable 快照。测试只用生成和模拟器默认素材。

提交历史：F001 6f6d466，F002 22ace0a，F003 7781c42，F004 7fa23ac。当前 commit 以 git log 为准。provider 仅 evaluator_command 启用已授权 --approve-for-me；不运行独立 Coding Agent。
