# F022 diagnostics

Initial `.build/F022-compact.xcresult` failed. Two preexisting Home cases failed at authorization/home transition before Settings; screenshot hierarchy retained an unrequested permission page, so this is not evidence that Settings passed. A third real Settings case reached the glass UI and disclosure, but accessibility audit found a too-small button hit area: frame applied outside Button did not expand the label's target. Fixed by framing/contentShape inside close/done labels with plain style. Home/Settings tests now terminate an old app before resetting authorization, following PermissionTests' existing lifecycle.
- Failure domain: implementation_and_test_lifecycle
- Harness improvement: retain small-screen accessibility audit and real authorization tests; no generic harness change needed. Keep failed result, rerun serially for authoritative evidence.

The first F022 root run compiled before the hit-area fix was written. It was stopped at test startup and is not counted as a pass; `.build/F022-final-root.log` is the subsequent final-source serial verification. Original interrupted-turn baseline completed successfully at `.build/test-run.Zm4WVu/Tests.xcresult` before product changes were built.
