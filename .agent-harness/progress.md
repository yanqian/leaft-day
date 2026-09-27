# Progress

## Current System Status

2026-09-27：F001 已通过独立 Evaluator 验收，orchestrator 已标记完成。真实工具链和模拟器清单检查通过。F002–F018 未开始。用户已授权持续完成全部 Feature：每项独立 Evaluator 通过后提交，再开始下一项。

## Last Completed Feature

F001 — iOS 工具链与模拟器能力。独立证据：runs/20260927T085100Z-F001-evaluation.md。

## Next Feature

F002 — 可运行 iOS 骨架与项目恢复；按用户授权批量推进，使用 make -C .agent-harness work，每轮只处理一项，验收通过后由主会话提交。

## Known Issues

- 无产品工程；根 ./init.sh 仍为 Harness 验证，F002 将添加产品 build/launch smoke。
- 当前环境 Xcode 26.6、SDK 26.5、iOS 26.5 runtime 可用；真实启动还未验证。
- CoreSimulator 与 Codex 子进程需要用户级服务访问，受限沙箱可能失败；只通过外层权限机制处理。
- Harness 本地 unborn Git 补丁及回归测试见 runs/20260927-startup-repair.md；manifest 已通过 local repair 更新，未来 upgrade 需审查补丁。
- 所有 Feature 从 F001 起需要独立 evaluator evidence，不能依赖模板 F027 基线豁免；F002 将配置入口。
- Git 无提交，未暂存。现有截图/设计稿保留。

## Recovery Notes

SPEC 与 docs/architecture.md 为需求架构源。scripts/doctor.sh 只读检查；tests/fixtures/simctl-ios26.json 是裁剪的真实工具输出。F001 handoff 位于 runs/20260926T160332Z-F001-work-fast-handoff.md。模型仍为用户指定 gpt-6-astra，cwd=项目根目录。早期“未安装 Xcode”“只授权规划”的说明已过时。

## F001 独立验收权限恢复

2026-09-27：首次独立验收因 CoreSimulator 沙箱权限失败。自动审批拒绝未经授权的审批配置变更后，用户明确回复“ok”批准为 Evaluator 启用 --approve-for-me，保留沙箱。已仅更新 evaluator_command；常规 coding/runtime check command 未更改。重试时独立 Evaluator 经审批执行只读 doctor，实际访问 CoreSimulator 成功，并留下 EVAL_PASS 证据。orchestrator 正常退出并将 F001 标记 done/passes=true。原失败记录保留作历史；当前无待解决的 F001 阻碍。尚未构建或启动 App，无 Git 提交。
