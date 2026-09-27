# Progress

## Current System Status

2026-09-27：F001–F003 已独立验收完成。F002 恢复脚本可生成 iPhone-only SwiftUI 工程、启动模拟器、执行 XCTest/XCUITest 并启动 App。F004–F018 未开始。用户授权持续推进全部功能，明确使用 work-fast；每项独立 Evaluator 通过后提交，再开始下一项。

## Last Completed Feature

F003 — 可重复媒体测试素材。复验记录：runs/20260927T0938Z-F003-reevaluation.md。素材、导入、重复生成与真实系统验证协议均通过独立验收。

## Next Feature

提交 F003 后使用 make -C .agent-harness work-fast 获取 F004 本地状态持久化 handoff。

## Known Issues

- F002 已生成 SwiftUI 骨架及测试，根 ./init.sh 完整验证并启动模拟器 App。尚未实现照片业务。
- 当前环境 Xcode 26.6、SDK 26.5、iOS 26.5 runtime 可用；真实启动和重开已验证。
- CoreSimulator 与 Codex 子进程需要用户级服务访问，受限沙箱可能失败；只通过外层权限机制处理。
- Harness 本地 unborn Git 补丁及回归测试见 runs/20260927-startup-repair.md；manifest 已通过 local repair 更新，未来 upgrade 需审查补丁。
- 所有 Feature 从 F001 起需要独立 evaluator evidence，不能依赖模板 F027 基线豁免；根入口已强制执行。
- F001 已提交为 6f6d466；F002 已独立验收通过，准备提交。现有截图/设计稿保留。

## Recovery Notes

SPEC 与 docs/architecture.md 为需求架构源。scripts/doctor.sh 只读检查；tests/fixtures/simctl-ios26.json 是裁剪的真实工具输出。F001 handoff 位于 runs/20260926T160332Z-F001-work-fast-handoff.md。模型仍为用户指定 gpt-6-astra，cwd=项目根目录。早期“未安装 Xcode”“只授权规划”的说明已过时。

## F001 独立验收权限恢复

2026-09-27：首次独立验收因 CoreSimulator 沙箱权限失败。自动审批拒绝未经授权的审批配置变更后，用户明确回复“ok”批准为 Evaluator 启用 --approve-for-me，保留沙箱。已仅更新 evaluator_command；常规 coding/runtime check command 未更改。重试时独立 Evaluator 经审批执行只读 doctor，实际访问 CoreSimulator 成功，并留下 EVAL_PASS 证据。orchestrator 正常退出并将 F001 标记 done/passes=true。原失败记录保留作历史；当前无待解决的 F001 阻碍。尚未构建或启动 App，无 Git 提交。

## F002 Coding capability gap (2026-09-27)

Orchestrated Coding role started at 6f6d466; F002 already in_progress, attempts=1. Startup ./init.sh passed all Harness layers. Real ./scripts/doctor.sh failed: CoreSimulatorService connection invalid, log access Operation not permitted, device-set connection refused. This Coding session has approval_policy=never; it cannot request the required outer permission. No security/provider configuration was changed.

Partial change: root init.sh now enforces evaluator evidence from F001. Product project, test targets, build/launch smoke are not implemented; F002 remains passes=false. Resume F002 after the outer runner supplies an authorized Coding environment with CoreSimulator access. Do not restart orchestration from inside the role or proceed to F003. Details: runs/20260927T0900-F002-coding-capability-gap.md.

Failure domain: capability_gap. Harness improvement: apply the documented user-service permission requirement to Coding as well as Evaluator in outer execution configuration; this process cannot change that permission boundary. No examples changed and no commit made.

## Current recovery override

Earlier F002 Coding capability-gap notes are historical. User selected work-fast; current session implemented and approved outer execution verified real simulator. Independent Evaluator passed. No Coding provider security change occurred. F001 commit is 6f6d466; current Git history supersedes earlier unborn notes.
