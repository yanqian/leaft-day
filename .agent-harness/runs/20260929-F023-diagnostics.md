# F023 diagnostics

Initial .build/F023-targeted.xcresult: five PendingAdvance unit tests and six continuity unit tests passed; reduced-motion completion/video/undo/restart UI passed. Standard pending UI failed finding the transient undo affordance after it verified the new count and cursor. The actionable toast used the old 2-second generic feedback lifetime. Extended pending undo feedback to 5 seconds, with persistent toolbar undo still available. Rerun .build/F023-pending-fixed.xcresult.
- Failure domain: implementation_ux_timing
- Harness improvement: keep real gesture plus actionable-undo UI test; no harness runtime change needed. Failed run is retained, not counted as overall pass.

The first added compact orientation assertion in .build/F023-compact-final.xcresult timed out: direct ReviewTestHost root did not rotate. Standard pending flow passed there, and reduced-motion flow reached completion before this added orientation check. Production orientation is entered by Home's fullScreenCover; existing F020 tests also use that path. Replaced the direct-host rotation assertion with an additional real Home -> Continue -> mark all -> completion -> rotate -> undo -> Home pending-count test; no product orientation bypass. Final compact Home run records final completion ScrollView and full toast hit region as well.
- Failure domain: verification_surface_mismatch
- Harness improvement: keep orientation assertions on actual Home/fullScreenCover route rather than direct launch fixtures; retain failed direct-host result for diagnosis.

.build/F023-compact-home.xcresult did not execute tests: SpringBoard rejected the stale UI-test runner with Busy / failed preflight checks. Reinstalled only dev.armstrong.swipego.uitests.xctrunner as recover-ios.sh already does, preserving App and Photos; retry uses a fresh result bundle.
- Failure domain: environment_gap
- Harness improvement: compact ad-hoc runs must follow recover-ios.sh's runner-only reinstall when test code changes; no App/data reset or weakened tests.

Correction to runner recovery: the first uninstall attempt returned SimError405 because the compact device was Shutdown; therefore no runner was removed. The following retry also failed preflight and ran no tests. The next invocation explicitly bootstraps with simctl bootstatus -b before runner-only uninstall, matching the complete recover-ios.sh sequence; .build/F023-compact-recovered.xcresult is the new result. Repeated environment failure led to this concrete workflow correction, not a product workaround.

## Independent rejection repair

Independent root N9LZHL passed 76 unit/26 UI, but source review rejected completion navigation and hidden undo/save failures. No install occurred. Repair navigates directly through session state, presents a visible undo-failure alert, separates successful unmark from failed cursor restoration, offers a retry, and restores a terminal unmarked photo on restart. DEBUG-only fault wrapper delegates real disk operations and injects one failure.

Targeted `.build/F023-repair-targeted.xcresult` passed 7 PendingAdvanceTests and 3 new PendingUITests. Screenshots exported and visually inspected: completion undo failure alert and position recovery with reduced pending count. The recovery button hit-area refinement is included in the subsequent full root run. Prior failed evidence is retained.
