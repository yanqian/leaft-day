# F030 robust desktop launch verification repair

FAST_CODING_EVIDENCE: F030
CODING_PASS: F030

Handoff runs/20261001T065925Z-F030-work-fast-handoff.md. Original failure/evaluator and archived coding records retained. This repairs the same F030, not a new feature.

Failure evidence showed five unconditional left scans reached App Library; firstMatch existed but was not tappable, so no desktop screenshot was attached before assertion. Precise duplicate/offscreen root cause cannot be proved from the old hierarchy (not attached). Fix addresses both page/transition and matching assumptions: wait for SpringBoard foreground, press Home to normalize App Library/folder state, poll for a fully on-screen tappable icon among all LeafDay matches on each page, then select that exact visible icon. Capture full screenshot and accessibility hierarchy BEFORE asserting or tapping, so future failure state remains reviewable. Do not replace icon tap with app.launch or weaken tap/launch/relaunch acceptance.

Only LaunchTests.swift changed in repair; approved assets, product/configuration and permission/data code unchanged.

- .build/leafday-launch-repair.xcresult passed1UI on the exact standard fixture simulator that failed full evaluation. Native screenshot and hierarchy show named LeafDay icon fully on the home page; actual icon tap and subsequent cold relaunch passed. Copied docs/design/leafday/F030-LeafDay-home-screen-standard.png.
- .build/leafday-launch-repair-compact.xcresult passed1UI on compact SE, preserving previous supported surface.
- Original target .build/leafday-target.xcresult had1unit/3UI pass and full prior evaluator had85unit/43of44UI, including all welcome/permission tests. These remain historical and do not substitute for final full-root acceptance.
- git diff --check passed. No phone installation, commit or push. F018 remains deferred.

Request independent full root reevaluation on this final test version. No coding self-acceptance.
