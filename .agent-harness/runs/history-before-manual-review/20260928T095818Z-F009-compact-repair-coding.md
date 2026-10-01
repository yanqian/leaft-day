# F009 compact audit repair coding

- Failure domain: implementation_gap
- Harness improvement: no runtime change required; added durable compact-home verification script and matrix after evaluator caught the missing surface.
- Failure summary: original compact continue-label clipping resolved; initial reevaluation dispatch stopped on this receipt missing its mandatory improvement field, now supplied without changing test outcomes.
- Follow-up feature: none; corrected within F009.
- Original independent failure: runs/20260928T083100Z-F009-evaluation.md and compact audit attachments are preserved.
- Correction: hero continue Label now uses fixedSize(horizontal: false, vertical: true), allowing its ideal untruncated text height. No audit filters, hidden text, smaller font or weakened acceptance.
- Durable matrix: scripts/verify-compact-home.sh discovers/validates a dedicated iPhone SE3 on iOS26+ and runs unfiltered HomeTests, with unique result bundle; docs/verification.md explains setup. Dedicated compact simulator retained as SwipeGo Z compact home (same evaluator-created ID), shut down after testing to free resources and preserve the original default simulator selection.
- Compact exact-failure reproduction after fix: .build/compact-home.K7BdFe/Tests.xcresult, 3/3 HomeTests passed; screenshots inspected and stored docs/design/F009-compact-home-v2.png and F009-compact-opaque-v2.png.
- Final-source full recovery: SWIPE_SIMULATOR_UDID=1DF82DB5-2A3B-450A-9EB5-098FC4E8F812 ./init.sh exit 0, .build/test-run.siwoaq/Tests.xcresult; 61 unit +16 UI pass, APP_READY, physical/iCloud deferred. No source changes after this run started.
- Previous complete implementation evidence remains runs/history-before-manual-review/20260928T083000Z-F009-manual-coding.md; archive only removes stale receipt from active-cycle scanning, retaining bytes. F018 original work preserved, no commits, no private library mutation.
- git diff --check clean. Independent reevaluation still required.

FAST_CODING_EVIDENCE: F009
CODING_PASS: F009
