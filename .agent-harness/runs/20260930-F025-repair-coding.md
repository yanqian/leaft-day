# F025 recovery repair and coding evidence

FAST_CODING_EVIDENCE: F025
CODING_PASS: F025

Repair handoff runs/20260929T155713Z-F025-work-fast-handoff.md. Original welcome implementation and compact6UI evidence described in history-before-manual-review/20260929-F025-coding.md, preserved byte-for-byte. First independent evaluation rejected missing fixture permission precondition. See runs/20260929T1552Z-F025-evaluation.md.

Durable repair in project scripts/recover-ios.sh now clean-boots the selected test simulator, builds the host/tests, runs the existing native full-access UI case as an explicit required permission setup, then runs the complete suite. Native matrix still resets and requests normally. No private device/library changes; no Simulator erase. docs/verification.md documents reproducibility and real runtime probes. Query test logs host bundle for diagnosis.

Evidence: simple simctl grants did not resolve PhotoKit readWrite on this runtime (raw logs retained, rejected approach). Native setup1UI followed by query2tests proved full access to63 generated fixture records. Full root .build/test-run.eOHGYO/Tests.xcresult then passed80unit/31of35UI; remaining4 all rotation event timeouts. After selected-simulator restart, the exact unchanged binaries passed all4 in .build/F025-rotation-reboot.xcresult. This established the clean-boot repair added to final root. bash syntax and git diff --check passed.

No final whole-root pass is claimed for Coding: prior failed roots remain failed. Independent Evaluator must now run the final complete recovery with both durable preconditions and pass all80unit/35UI plus native setup. If any fails, reject; targeted evidence is not independent acceptance. No product rotation source changed, no lowered assertions, no installation/commit. F009 home repair pending and F018 incomplete.
