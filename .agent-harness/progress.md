# Progress

## Current System Status

2026-09-27：F001–F006 已通过独立 Evaluator，F005 已提交272f7d3。F006 已独立验收，真实 iCloud 实测按批准集中到 F018；F007–F018 未开始。用户授权持续完成所有功能，明确 work-fast：当前会话实施，每项独立验收通过后提交，再进入下一项；最后用户统一体验验收。

## Last Completed Feature

F006 照片加载与缓存，独立 Evaluator 已通过；真实设备与iCloud仍在F018待测清单。

## Next Feature

提交F006后，用 make -C .agent-harness work-fast 开始F007视频资源生命周期。

## Known Issues

- iCloud 共享图库成员无法由已核实公开 API 可靠区分；共享相簿/隐藏项已过滤，共享图库明确暂不支持，不能假称排除。用户范围选项尚未回复；F016 不得据此自动执行删除。
- 真机、签名团队和真实 iCloud 未下载素材尚未提供；此前已向用户询问，不能以模拟器替代相关验收。
- 界面目前为权限入口，批准的回顾/玻璃 UI 由 F009–F010 实施。尚无业务删除。
- Harness 有本地 unborn Git startup 修复，见 F001 runs；未来升级需审查。

## Recovery Notes

运行 ./init.sh：Harness（强制 F001 起独立证据）、生成 fixture、Python检查、XcodeGen、模拟器 boot、真实 XCTest/XCUITest、安装启动。使用本地 ad-hoc 模拟器签名，无需证书/团队，避免无签名旧二进制缓存。测试前仅卸载项目 UI runner，不擦除 App 或图库。SWIPE_SIMULATOR_UDID 可指定测试模拟器；DEVELOPER_DIR 不改全局。

SwiftData 使用 ModelActor/DefaultSerialModelExecutor，失败 rollback 后丢弃工作 context；root 拒绝 Unbinding 警告。PhotoKit 跨 actor 只传 Sendable 快照。测试只用生成和模拟器默认素材。

提交历史：F001 6f6d466，F002 22ace0a，F003 7781c42，F004 7fa23ac。当前 commit 以 git log 为准。provider 仅 evaluator_command 启用已授权 --approve-for-me；不运行独立 Coding Agent。
