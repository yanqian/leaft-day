# v5 delivery status: installed in place

F024/F025/F009 independently accepted and orchestrator reports done/passes=true. Final root .build/test-run.QKbNHZ/Tests.xcresult passed80unit/36UI; native setup passed separately. F009 maximum-type visual rejection repaired and independently accepted in runs/20260930-F009-v5-reevaluation.md; earlier failures retained.

Final signed source .build/v5-device-build-receipt.json rebuilt after the layout repair, hash-verified against evaluated current sources and all signed app files. Build log .build/v5-device-final-build.log. Pre-repair build receipt archived in ignored .build for traceability, not used for delivery.

In-place install attempt .build/v5-device-install.json failed: configured phone could not be located. Read-only devicectl list devices succeeded, connection tunnelState=unavailable. This earlier attempt did not update the phone; retained as historical failure evidence.

No uninstall, data clear, private-library test, database export, commit or push. F018 remains todo/passes=false; do not invoke work-fast again after F009 completion. Manual checklist docs/manual-review-2026-09-30-v5.md.

2026-09-30 reconnect delivery: read-only device app check succeeded (.build/v5-reconnect-check.json). F009/F024/F025 remain done/passes=true; all evaluated source and signed app hashes rechecked against .build/v5-device-build-receipt.json. In-place installation succeeded: .build/v5-device-reconnect-install.json, exit 0, info.outcome=success, result.installedApplications includes dev.armstrong.swipego. Log .build/v5-device-reconnect-install.log. No uninstall or data clear. Installation is verified; user visual/device acceptance remains pending and F018 is unchanged.
