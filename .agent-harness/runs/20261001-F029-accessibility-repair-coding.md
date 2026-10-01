# F029 maximum Dynamic Type landscape repair

FAST_CODING_EVIDENCE: F029
CODING_PASS: F029

Handoff: runs/20260930T163459Z-F029-work-fast-handoff.md. This follows Coding self-audit, not user feedback. Prior independent 85 unit/42 UI acceptance remains historical; current source requires separate reevaluation.

Reproduced maximum-type compact-landscape completion viewport of 24pt, below one 67pt title line, in .build/v8-F029-max-landscape-repro.xcresult. Cap accessible landscape toolbar at 45% of viewport (140–360pt bounds), retaining separately scrollable controls. Photo/unavailable retry scrolls receive identifiers. Video nonready states no longer reserve an extra 80pt or show unusable playback controls; playable video lifecycle and transport remain unchanged.

Added two durable UI regressions: maximum-type landscape completion must fit a complete text line and scroll its full return button into view; photo/video/unavailable failures with disclosed controls must fit a text line and expose full retry actions. DEBUG host presents through a real fullScreenCover after tap and synthesizes completed state using local pending intent; no private assets. An initial test locator failed because photo accessibility correctly owns the inner scroll identifier (review.photo); exported hierarchy confirmed 118.5pt viewport and locator was corrected without weakening geometry.

Verification:
- .build/v8-F029-max-landscape-fix.xcresult: original state matrix, both actual-media orientation tests, completed regression and real video lifecycle passed; sole failure was the documented photo locator.
- .build/v8-F029-max-landscape-final.xcresult: both new regressions passed.
- .build/v8-F029-max-landscape-screen.xcresult: both passed with full-screen landscape captures. XCTest app-only screenshots clipped rotation, so evidence uses XCUIScreen.main.screenshot as existing orientation suite does.
- Inspected final completion return/photo retry/video retry screenshots; actions fully visible above independent scrollable toolbar. docs/design/v8-F029-*-largest-landscape*.png and corresponding attachment manifest are retained.

No domain deletion/permission changes. F018 stays deferred. Request cold Evaluator with full root recovery and final visual/geometry checks. No self-acceptance, phone install, commit or push.
