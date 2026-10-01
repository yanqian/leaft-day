# Reopened-feature evidence recovery

- Result: recovered; no implementation or evaluation completed.
- Failure domain: agent_workflow_gap
- Failure summary: work-fast reads all historic coding passes even after Human Eval reopening, causing premature evaluation. Stopped this invocation before verdict.
- Harness improvement: preserve old coding receipts byte-for-byte under runs/history-before-manual-review, leaving evaluator receipts unchanged. Fresh top-level receipts will represent this reopened cycle. No harness code change in product feature. General freshness guard is deferred, not claimed fixed.
- Follow-up feature: not scheduled; track general Harness freshness upstream.
- Archived coding receipts: 20260927T1549Z-F009-coding.md, 20260927T1609Z-F010-coding.md
