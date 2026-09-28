# Progress

## Current System Status

2026-09-28：F001–F017全部独立Evaluator通过。F015提交335f1da，F016提交06f0431；F017随本次提交保存，真实SHA以git log为准。F017独立root init退出0：56 XCTest、16 XCUITest、Harness和6项项目Python检查通过，无SwiftData Unbinding警告；模拟器安装启动成功。证据runs/20260928-F017-evaluation.md，结果.build/test-run.CyopYr/Tests.xcresult。

用户2026-09-28拔掉手机，明确要求先完成不需要手机的功能。本轮F015–F017均按work-fast当前会话实施→独立冷启动Evaluator→逐项提交完成；未运行Coding子进程、未推送。F018真机/iCloud/性能验收仍todo，不得宣称整个项目已全部验收。

## Last Completed Feature

F017图库变化与未完成操作核对：图库观察/前台刷新传播到会话、照片/视频与相似缓存；重启遗留操作显示未知，不以不可见推断成功、不自动删除；进程内活动排除、CAS防覆盖；用户核对仅记录reviewedAt，保留原结果与待删意图，再删除必须重新复核。实际截图docs/design/F017-reconciliation.png。

F015集中复核、F016系统整批删除已完成，真实模拟器生成素材取消/成功测试通过。仅删除测试入口现场创建的可丢弃图片，未删除用户私人照片。

## Next Feature

F018需要手机重新连接及真实iCloud场景，当前不启动依赖手机的步骤。手机可用后重新读取状态、git log和root init，再通过make -C .agent-harness work-fast获取交接。按docs/deferred-device-verification.md和docs/verification.md完成真机回顾、视频、收藏、比较、复核、取消/受控删除、权限、iCloud未下载/离线/同步、重启窗口、性能及辅助功能；发现缺陷修复对应功能。缺少能力必须记录未执行，不能用模拟器或历史收据替代。

## Known Issues

- 公开API无法可靠区分iCloud共享照片图库成员。用户已明确没有使用该功能，首版个人图库范围；实际删除前产品要求确认，不宣称自动排除共享成员。未授权测试删除私人照片。
- 本机iOS26.0/26.5模拟器Vision特征异常，运行时控制失败则拒绝分组。历史F013/F014真机内置生成图质量测试通过，仅覆盖算法控制，不等于F018真实图库/iCloud/性能通过。
- SwiftData意图元数据在F016修复为显式MainActor隔离。媒体下载和Vision仍走异步服务；大量历史记录的主线程延迟尚需F018量测。
- Harness picker不检查depends_on；已有提前挑F015失败记录已保留，优先级已修复。不可跳过未完成依赖。

## Recovery Notes

默认./init.sh或SWIPE_VERIFICATION_MODE=simulator ./init.sh：Harness、fixtures、Python、XcodeGen、完整模拟器单元/UI、安装启动，明确打印DEVICE_VERIFICATION_DEFERRED。SWIPE_VERIFICATION_MODE=device ./init.sh额外强制真机内置Vision测试；缺少设备或签名必须失败，不自动降级。F018仍必须真实设备验收。

当前provider可执行文件/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex（桌面更新后的路径），gpt-6-astra与cwd=..保持用户配置；真实预检已通过，见runs/20260928-F015-provider-recovery.md。规范配置为忽略的.agent-harness/agent-provider.json，不提交凭据。

免费Personal Team已实际签名成功，无需付费Apple Developer计划。用户新证书可用、旧证书未撤销；手机此前已配对、打开开发者模式并信任App。设备配置为忽略的.build/device-test.json或SWIPE_DEVICE_UDID/SWIPE_DEVELOPMENT_TEAM。不提交个人签名/私钥，不在个人手机运行完整模拟器测试套件。scripts/verify-device-vision.sh只运行两项内置生成图测试。

DEVELOPER_DIR指向完整Xcode，不修改全局xcode-select。默认fixtures模拟器1DF82DB5-2A3B-450A-9EB5-098FC4E8F812，可用SWIPE_SIMULATOR_UDID覆盖；隔离26.0探针F31F5C4A-BA53-47E6-958C-0F1932CC61C8没有fixtures。测试不擦除图库。实际运行Xcode/CoreSimulator受外层sandbox限制时申请对应执行权限；不能把权限失败称通过。

SwiftData失败rollback并丢弃工作context，DTO为Sendable；可选comparison/deletion/outcome/reviewedAt兼容旧JSON，SwiftData实体schema仍V1。操作日志保留未知历史；无后台自动重试删除。root严格拒绝跨队列警告。
