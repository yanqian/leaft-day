# F018 partial physical-device evidence — not completion

Date: 2026-09-28. Base: 00a2fcc. Work-fast handoff: 20260928T064158Z-F018-work-fast-handoff.md. F018 remains in_progress, passes=false. No coding completion marker, evaluator acceptance or commit is asserted.

## Execution

- User reconnected/unlocked iPhone 12 Pro, iOS26.6.2 (23G90), existing free Personal Team. No paid enrollment or account changes.
- Initial `SWIPE_VERIFICATION_MODE=device ./init.sh` exit0; simulator 56 unit/16 UI plus physical bundled Vision 2 tests. Physical result `.build/device-vision.owjs7L/Tests.xcresult`.
- `scripts/verify-device-acceptance.sh` latest exit0, two physical tests: `.build/device-acceptance.ewrj3K/Tests.xcresult`, `/private/tmp/swipe-F018-device-metrics.log`. Earlier full flow `.build/device-acceptance.z3g2x5/Tests.xcresult`, run AAB22583-ECAF-42E3-AB8A-64D8F181098F. Screenshots copied to docs/design/F018-device-*.png.
- Real favorite, immersive review, local video seek, native Vision comparison, favorite protection, zoom, pending review, native cancellation, native deletion of one generated asset, receipt and process restart pass. Each batch starts with 4 generated assets and ends 3 visible, 1 favorite, 0 pending.
- Launch responsive first frame seconds [0.301849, 0.283992, 0.288581]; average 0.291. Peak physical memory kB [131844.800, 131533.504, 131599.040]; average 131659.115. Only four synthetic assets, not large-library/first-photo/FPS evidence. Automated loop walltime includes test-driver waits.

## Implementation / boundaries

DEBUG DeviceAcceptanceHost creates bundled generated resources and durably records exact placeholder IDs per UUID; isolated intent store. Home/Review assetScope survives native refresh, covered by DeviceScopeTests. No filename lookup or personal photo substitution. Never run generic simulator UI suite on personal phone. Generated leftovers remain; no Recently Deleted clearing. Native deletion tested only after explicit UI review and system confirmation within generated scope.

Project-owned changes: App host/entry, ReviewSession optional scope, Home scope forwarding, resources, UI/unit tests and physical-only script. No harness workflow logic change.

## Failures retained

First physical command used invalid destination separator and failed before executing device operations. Next run used zero-based comparison selector; UI uses one-based indices, failed before deletion. Corrected selector preserves protected favorite semantics. `.build/device-acceptance.FaH7q4/Tests.xcresult` retained. Failure domain: implementation/test adapter. No harness change needed: real XCTest failure already stopped acceptance; repaired project-owned invocation/selector.

## Remaining required evidence

Cloud-only photos/Live Photo/video, offline/cancellation/retry and second-device synchronization; actual limited permission/restriction/external edits; interruption at system receipt window; audible playback, VoiceOver/dynamic type/reduced motion/transparency; volunteered real sample quality and large-library/cache performance. User confirmed on 2026-09-28 that no second device shares the library and requested cross-device verification remain pending. This item is deferred, not accepted; do not alter user's iCloud/account settings. See docs/device-acceptance.md and deferred-device-verification.md. Do not submit incomplete F018 to Evaluator or mark done.

最终 `./init.sh` 退出0：57 XCTest（含新增DeviceScopeTests）、16 XCUITest、Harness及项目检查通过，模拟器安装启动成功；结果 `.build/test-run.XZLraN/Tests.xcresult`，日志 `/private/tmp/swipe-F018-regression.log`。没有SwiftData Unbinding警告。默认模式的DEVICE_VERIFICATION_DEFERRED仅表示此次命令不运行手机步骤；不否定本轮已单独取得的真机证据。
