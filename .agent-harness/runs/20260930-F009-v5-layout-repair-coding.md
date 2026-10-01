# F009 v5 maximum-type repair

FAST_CODING_EVIDENCE: F009
CODING_PASS: F009

Handoff runs/20260929T170627Z-F009-work-fast-handoff.md; routing/attempt preservation described in runs/20260930-F009-v5-repair-routing.md. Independent rejection runs/20260930-F009-v5-evaluation.md is retained. Previous coding receipt archived intact. Prior full root115 passed but did not satisfy visual acceptance; not claimed as repair validation.

Replaced overlaid status text with production HomePhotoCardContent: title and state/subtitle share the glass caption's vertical flow. Non-image state replaces subtitle rather than duplicating/obscuring it. Minimum card height can grow with Dynamic Type. HomeHeroCardContent now similarly keeps date/status/summary/action in one growing vertical flow with artwork only in its background, eliminating the same hidden-state risk on the hero. Status messages remain distinct and accessible; no accessibilityHidden on meaningful statuses, no font reduction. Existing HomeCoverLoader fetching/cancellation/cache behavior remains unchanged.

Added DEBUG HomeCoverStateTestHost that renders these exact production card components with explicit enum states; no Photos access or writes. HomeCoverStateTests checks maximum AX XXXL empty/loading/downloading/offline/unavailable for both card types (10 combinations), state text, status below title, on-screen bounds/hittability, clipping/description audit and screenshots. Opaque unavailable cases included. This tests presentation only; existing native/domain tests still verify transport/navigation.

Final compact .build/F009-v5-cover-final.xcresult: 5 UI tests passed (new10-state presentation matrix plus existing3 Home and1 continuity/navigation/landscape). Actual normal, large, opaque and offline hero screenshots visually inspected; all state screenshots in docs/design/F009-{cover,hero}-*-maximum-type.png. Repaired real large Home screenshot now has only the readable state within caption, no centered text behind it. Final normal screenshot docs/design/F009-v5-home-photo-cards.png retains tall photo cards and bottom trash. git diff --check passed.

Independent Evaluator must rerun final root (expected80unit/36UI plus native setup), inspect actual maximum-type statuses and accept/reject. Signed pre-repair app is stale and must be rebuilt before any install. No install/commit/push. F018 remains todo, untouched implementation, no further scheduling after F009.
