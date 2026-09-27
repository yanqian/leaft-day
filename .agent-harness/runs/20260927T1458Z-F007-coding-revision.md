# F007 evaluator feedback correction

FAST_CODING_EVIDENCE: F007

Previous evaluator rejection was a real UI/lifecycle test gap. Added DEBUG-only VideoTestHost and VideoTests using the real VideoReviewView, real PhotoKit video, AVPlayer currentTime, system permission UI, Home/activate, close/reopen, and playing session replacement. Normal product navigation unchanged; F010 integrates the immersive review.

The UI asserts: actual autoplay event, pause and mute, seek updates real player time, media surface drag callback increments while Slider interaction does not, retiring session clears its player, background/close release counters increase, foreground/reopen loads anew. Root recovery passed with 6 UI tests plus unit/harness/Python tests: .build/test-run.hVgqm9/Tests.xcresult; log /private/tmp/swipe-F007-final-init.log. Final targeted run after adding playback-before-session-switch also passed: DerivedData/Logs/Test/Test-SwipeGo-2026.09.27_22-57-33-+0800.xcresult, /private/tmp/swipe-F007-video-ui-final.log. No actual PhotoKit video skip.

Debugging evidence: initial test host reused one controller across old/new views and had shifting controls after closing. Fixed per-session ownership and stable control layout. Short 2-second fixture requires actual event/time assertions instead of assuming still playing when XCTest snapshots. Actual failure screen recording exported from 22-51-44 bundle showed video remained hidden and Open button not activated after layout movement; fixed placeholder preserves layout. SwiftUI scene active checks avoid duplicate foreground opens; lifecycle opens on appearance/asset change and stops on disappearance/inactive. Stale generation guards remain.

Failure domain: agent_workflow_gap for original missing integration tests; corrected with durable project UI host/tests and verification guidance. Repeated local test failures were test-fixture/layout integration issues, not reasons to weaken evaluator criteria or change harness. No new harness feature required. All intermediate failures remain in local xcresults and the original evaluator verdict remains unchanged. F018 real hardware/cloud remains unexecuted.

CODING_PASS: F007
