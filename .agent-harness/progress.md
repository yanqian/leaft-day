# Progress

## Current System Status

2026-09-28：F001–F014已全部独立Evaluator通过。F013提交9eb51fe；F014人工比较已获EVAL_PASS，随本次提交保存。F014独立root init退出0：42 XCTest、13 XCUITest、2真机Vision测试。证据runs/20260928-F014-evaluation.md；模拟器结果.build/test-run.KcNRBb/Tests.xcresult，真机结果.build/device-vision.Py4pEC/Tests.xcresult。

**已按用户要求暂停：F014验收并提交后等待用户重启电脑。不启动F015，不运行后台任务。只有用户明确要求继续才恢复。**

用户工作流继续有效：work-fast当前会话实施每项Feature；独立冷启动Evaluator通过后提交，再进入下一项。不运行Coding子进程，不推送远端。F015–F018尚未实施，不得宣称全部功能完成。

## Last Completed Feature

F014 人工相似比较：全选保留默认、收藏固定保留、多选、放大/平移、全部保留、跳过、至少留一项；确认仅原子保存本地待删与组/保留上下文，重新校验资产，旧JSON兼容。实际截图docs/design/F014-comparison.png。独立验收见runs/20260928-F014-evaluation.md。

## Next Feature

用户重启后明确继续，再读取本文件/feature_list、git log并运行根./init.sh，然后通过make -C .agent-harness work-fast获取F015交接。F015接入首页弱待删入口、有效计数、集中复核、保留项对照、视频确认与撤回、固定确认集合及iCloud文案；真实删除由F016实现。

## Known Issues

- 公开API无法可靠区分iCloud共享照片图库成员。用户在通俗解释后明确确认没有使用该功能，首版按个人图库继续。产品需保留个人图库适用范围，不能伪称API已自动排除共享成员。未授权测试删除用户私人照片；测试只用可丢弃生成素材。
- 本机iOS26.0/26.5模拟器Vision特征异常，产品运行时控制失败则拒绝分组。根init强制真机生成素材质量验证，不以模拟器或历史收据代替。完整真实PhotoKit/iCloud/Live Photo/性能验收仍属于F018。
- F015–F018未完成，当前没有业务删除入口。
- Harness picker不检查depends_on；已保留曾提前挑F015的失败/交接记录，F013/F014优先级排序已修复。未来遇到blocked前置项不得跳过依赖实现后续Feature。

## Recovery Notes

免费Personal Team已完成自动签名，不需要付费Apple Developer计划。用户新建的开发证书已能实际签名，旧证书未撤销。iPhone12 Pro/iOS26.6.2已配对、开发者模式开启、开发者App已信任。重启后连接并解锁手机；测试需要它保持可用。

本地目标配置在忽略的.build/device-test.json（udid/team）；也可用SWIPE_DEVICE_UDID和SWIPE_DEVELOPMENT_TEAM环境变量。不要把个人签名配置或私钥提交。详细步骤docs/verification.md。scripts/verify-device-vision.sh只运行两项内置生成图测试，不在个人手机运行完整图库/UI测试。security -v曾误报零有效身份，以实际xcodebuild签名验证为准。

根./init.sh：Harness检查、生成fixtures、Python检查、XcodeGen、模拟器真实测试/启动、真机Vision质量门禁。模拟器使用项目ad-hoc签名，测试前只卸载UI runner、不擦除图库；SWIPE_SIMULATOR_UDID可覆盖目标。DEVELOPER_DIR使用完整Xcode，不改全局xcode-select。生成素材默认模拟器1DF82DB5-2A3B-450A-9EB5-098FC4E8F812；26.0隔离探针F31F5C4A-BA53-47E6-958C-0F1932CC61C8没有项目图库fixtures。

SwiftData采用ModelActor/DefaultSerialModelExecutor，失败rollback并丢弃工作context。PendingIntent可选comparison载荷兼容旧记录。PhotoKit跨actor只传快照。root检查拒绝SwiftData Unbinding警告。

真实提交状态以git log为准。暂停后没有计划中的Coding/Evaluator进程或自动化继续工作。
