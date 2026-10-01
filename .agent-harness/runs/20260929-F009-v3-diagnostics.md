# F009 v3 diagnostics (not coding/evaluation pass)

- Failure domain: agent_workflow_gap
- Harness improvement: serialize simulator UI invocations; do not launch root init until targeted xcodebuild exits. Current root run provides a fresh full verification; partial targeted2 results do not imply whole suite passed.
- Startup baseline: root init exit 0, .build/test-run.x1PUOm/Tests.xcresult (63 unit / 20 UI).
- First targeted run: layout container AX identifier shadowed review.position. Removed parent identifiers; child identifiers remain. Test-only diagnostic overlay moved below new top buttons. Immediate zoom assertion added.
- Targeted2: ReviewGlassTests and both ReviewOrientationTests passed; ReviewTests was interrupted as root suite launched, so targeted2 overall exit 65 is not a pass. Root suite must re-run ReviewTests serially.
- Visual evidence: docs/design/F009-v3-glass-{0,1,2}.png and opaque equivalents exported from actual generated-fixture tests; observed two pills, media remains fitted, native clear material takes backdrop color where media exists. Black letterbox naturally supplies no photo detail; no fake background/crop introduced.
- Initial unprivileged work-fast preflight could not write Codex runtime database; escalated configured provider rerun succeeded and produced F009 handoff. Provider/model unchanged.
- Root .build/test-run.MIsxaG/Tests.xcresult: 63 unit passed; all subsequent UI cases including ReviewTests passed, but first ComparisonUITests interrupted during the invocation overlap. Root exit65 retained. Now rerun root serially; no other simulator process will be started until it exits.
