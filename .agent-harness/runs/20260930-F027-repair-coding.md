# F027 compact layout repair

FAST_CODING_EVIDENCE: F027
CODING_PASS: F027

Handoff runs/20260930T065606Z-F027-work-fast-handoff.md. Repairs the implementation/test gaps in runs/20260930-F027-evaluation.md; original coding record is preserved under runs/history-before-v8-repair/ and its no-overlap claim is superseded by evaluator evidence.

Settings and Welcome now place clipped scrolling content and bottom actions as separate VStack siblings. This reserves the actual dynamic action height, removes the 112pt assumption, and prevents readable text being composited under transparent glass buttons. Native glass remains unchanged. Added UI assertions checking scroll.maxY <= action.minY and final explanatory text fully inside the scroll viewport at maximum type; settings exercises expanded disclosure, welcome exercises reduced transparency and real native full-access prompt.

Final compact tests: .build/v8-F027.JW8fq7/Tests.xcresult, all 7 UI passed. Prior repair check .build/v8-F027.PZ1kE8 also passed. Screenshots inspected: docs/design/F027-repair-F022-settings-large_0_8D8B6AED-8A35-4F63-9BB4-B6A83679269E.png and docs/design/F027-welcome-readable-final.png. Both show end of guidance above separate bottom action, no overlapping letters. Welcome screenshot moved before accessibility audit because audit itself scrolls to inspect elements; audit still executes and passes. Actual screenshots and manifest in result directories.

Prior independent root was 85 unit/37 UI, .build/test-run.aoAQI9, before this layout repair. Request fresh independent root and visual verification; do not reuse old root as final acceptance. No phone installation, commit or F018 work.
