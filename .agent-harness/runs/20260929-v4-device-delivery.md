# v4 device delivery

2026-09-29, after F022 and F023 independent acceptance. Feature list verified both done/passes=true by orchestrator; Coding Agent did not set acceptance.

- F022: runs/20260929T0838Z-F022-evaluation.md.
- F023: runs/20260929T0957Z-F023-evaluation.md.
- Final independent root: .build/test-run.z8MkgA/Tests.xcresult, 79 unit / 30 UI, zero failures.
- Signed build: .build/v4-device-build-cross.log. Receipt .build/v4-device-build-receipt.json records exact source and signed binary hashes, all rechecked before install.
- Read-only phone check success: .build/v4-device-final-check.json.
- In-place install exit 0: .build/v4-device-install.json info.outcome=success and result.installedApplications includes dev.armstrong.swipego.
- No uninstall/data clear/private photo test/phone database export/commit/push. No device identifiers copied into this record.
- F018 remains incomplete; this is installation and generated-fixture verification, not physical private-library/iCloud acceptance.
- Manual checklist: docs/manual-review-2026-09-29-v4.md.
