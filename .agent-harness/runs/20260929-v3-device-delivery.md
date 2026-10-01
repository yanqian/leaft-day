# v3 device delivery — 2026-09-29

Independent acceptance records:
- F009: `20260929T0356Z-F009-evaluation.md`
- F015: `20260929T0706Z-F015-evaluation.md`
- F021: `20260929T0736Z-F021-evaluation.md`

Final independent root recovery: `.build/test-run.oQJ6Tl/Tests.xcresult`, 71 unit and 23 UI tests, zero failures/skips. F009/F015/F021 are done/passes=true; F018 remains incomplete.

Signed device build succeeded using the configured existing Personal Team. `.build/v3-device-build.log` and `.build/v3-device-build-receipt.json` retain build and binary hash evidence. Source freshness and accepted feature states were checked before installation.

In-place installation exited 0. `.build/v3-device-install.json` records `info.outcome=success` and installed bundle `dev.armstrong.swipego`; `.build/v3-device-install.log` retains tool output. No uninstall, data clear, phone database export, private-photo test deletion, commit, or push occurred. Device identifiers remain only in ignored local build evidence.

Next: user manual acceptance of the installed build, guided by `docs/manual-review-2026-09-29.md`. Simulator acceptance does not close F018 personal-library/iCloud/large-library verification.
