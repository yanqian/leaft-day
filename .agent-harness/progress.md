# Progress

## Current System Status

2026-09-28：F001–F016独立Evaluator通过。F015提交335f1da；F016随本次提交保存。F016独立root init退出0：51 XCTest/15 XCUITest，无SwiftData跨队列警告，.build/test-run.NrcviG/Tests.xcresult，runs/20260928-F016-evaluation.md。用户拔掉手机，当前完整模拟器模式；真机/iCloud/性能在F018补齐，不称全部完成。

用户工作流：work-fast当前会话实施，每项独立Evaluator通过后提交，再下一项。不运行Coding子进程，不推送。

## Last Completed Feature

F016实际系统删除：固定批次/授权与保留项复查、先日志后系统操作、单次整批回执、取消与未知保留、成功原子清理、重复提交防护。真实模拟器系统取消/成功通过，仅新建可丢弃测试图片。截图docs/design/F016-native-delete-confirmation.png。

## Next Feature

提交F016后通过make -C .agent-harness work-fast获取F017交接，完成图库变化与未完成操作核对；独立验收提交后汇总F018真机待验项。

## Known Issues

- 公开API无法可靠区分iCloud共享照片图库成员。用户在通俗解释后明确确认没有使用该功能，首版按个人图库继续。产品需保留个人图库适用范围，不能伪称API已自动排除共享成员。未授权测试删除用户私人照片；测试只用可丢弃生成素材。
- 本机iOS26.0/26.5模拟器Vision特征异常，产品运行时控制失败则拒绝分组。用户2026-09-28明确拔掉手机，默认root init改为完整模拟器验证；SWIPE_VERIFICATION_MODE=device才强制真机生成素材质量验证，不以模拟器或历史收据代替。完整真实PhotoKit/iCloud/Live Photo/性能验收仍属于F018。
- F017/F018未完成，未决删除当前保留日志并阻止重试，待F017提供用户核对入口。
- Harness picker不检查depends_on；已保留曾提前挑F015的失败/交接记录，F013/F014优先级排序已修复。未来遇到blocked前置项不得跳过依赖实现后续Feature。

## Recovery Notes

免费Personal Team已完成自动签名，不需要付费Apple Developer计划。用户新建的开发证书已能实际签名，旧证书未撤销。iPhone12 Pro/iOS26.6.2已配对、开发者模式开启、开发者App已信任。真机阶段需要连接并解锁手机；当前按用户要求在无手机模式继续。

本地目标配置在忽略的.build/device-test.json（udid/team）；也可用SWIPE_DEVICE_UDID和SWIPE_DEVELOPMENT_TEAM环境变量。不要把个人签名配置或私钥提交。详细步骤docs/verification.md。scripts/verify-device-vision.sh只运行两项内置生成图测试，不在个人手机运行完整图库/UI测试。security -v曾误报零有效身份，以实际xcodebuild签名验证为准。

根./init.sh：Harness检查、生成fixtures、Python检查、XcodeGen、模拟器真实测试/启动；device模式额外执行真机Vision质量门禁，默认simulator明确打印延期。模拟器使用项目ad-hoc签名，测试前只卸载UI runner、不擦除图库；SWIPE_SIMULATOR_UDID可覆盖目标。DEVELOPER_DIR使用完整Xcode，不改全局xcode-select。生成素材默认模拟器1DF82DB5-2A3B-450A-9EB5-098FC4E8F812；26.0隔离探针F31F5C4A-BA53-47E6-958C-0F1932CC61C8没有项目图库fixtures。

SwiftData在F016捕获上下文跨队列警告后改为显式MainActor元数据存储，失败rollback并丢弃工作context。PendingIntent可选comparison载荷兼容旧记录。PhotoKit跨actor只传快照。root检查拒绝SwiftData Unbinding警告。

真实提交状态以git log为准。恢复后遵循逐项work-fast流程，运行状态以当前会话为准。


## 2026-09-28：手机断开期间的验证范围

用户明确要求拔掉手机后先完成不需要手机的功能。默认 `./init.sh`（或 `SWIPE_VERIFICATION_MODE=simulator ./init.sh`）运行完整 Harness、Python、模拟器单元/UI 和启动验证，并明确输出 DEVICE_VERIFICATION_DEFERRED。`SWIPE_VERIFICATION_MODE=device ./init.sh` 另外强制运行两项真机内置 Vision 控制测试；缺少设备必须失败，不自动降级。此调整不更改 F018 验收标准，也不把模拟器 Vision 异常或历史真机通过当成当前真机证据。F015–F017可继续独立Evaluator验收和提交，F018的真实设备、iCloud、性能与体验仍须连接后补齐。

断开前曾有真机内置 Vision 通过记录；这仅覆盖生成图算法控制，不覆盖上表。2026-09-28 F015完整模拟器回归46 XCTest/14 XCUITest通过，随后真机步骤因设备断开退出失败（/private/tmp/swipe-F015-final-gate.log）；保留该失败，不称完整命令通过。

F015 coding完成：46 XCTest/14 XCUITest，root init无手机模式退出0，.build/test-run.ItQGdV/Tests.xcresult。证据runs/20260928-F015-fast-coding.md；等待独立Evaluator，尚未提交。

F016定向测试 .build/F016-focused-final.xcresult：9领域测试和1真实系统UI测试通过。只在模拟器新建纯色可丢弃图片，取消保留/成功整批删除/保留项未变均验证。截图docs/design/F016-native-delete-confirmation.png。完整回归进行中，尚未独立验收。

F016最终root init退出0：51 XCTest/15 XCUITest，.build/test-run.RsZJHs/Tests.xcresult，无SwiftData跨队列警告；fast coding证据runs/20260928-F016-fast-coding.md。现在等待独立Evaluator，尚未提交。
