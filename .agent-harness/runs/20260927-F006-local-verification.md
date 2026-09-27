# F006 local implementation and outstanding capability

Base commit272f7d3. work-fast handoff20260927T102730Z-F006-work-fast-handoff.md. Current session implements F006, no Coding child.

## Implementation

PhotoRequestKey includes asset/version/pixel size. NativePhotoTransport uses public PHImageManager highQualityFormat/aspectFit, bounded target dimensions, explicit network permission and progress. MainActor PhotoLoader binds callbacks to generation+asset, cancels current and <=2 prefetched requests, prefetch network=false. Own LRU cache max12 items/32MiB decoded pixel cost, oversize images not cached, explicit invalidation and release. PhotoContentView scaledToFit. Isolated deinits cancel pending native/transport requests.

## Verified

Read local iOS26.5 Photos PHImageManager.h for real callback multiplicity, cancellation (callback may never run), error/progress/inCloud/degraded keys. Real simulator local image request succeeded with network disabled. Controlled transport regressions verify bounded prefetch, stale results ignored, offline/retry and cancellation; cache LRU/budget/version tested. These tests are NOT real iCloud network verification.

Initial full ./init.sh passed, xcresult .build/test-run.8ZDMoS/Tests.xcresult, log /private/tmp/swipe-F006-init.log. Final full recovery including deinit cancellation regression exited0: .build/test-run.efz0t7/Tests.xcresult, log /private/tmp/swipe-F006-final-local.log. All 5 PhotoLoader tests actually ran, including native local loading; no skip in this run. This does not fulfill outstanding real-cloud criteria.

## Capability gap

Read-only `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl list devices` returned `No devices found.` No signed test device or confirmed undownloaded iCloud fixture supplied. F006 acceptance includes real cloud behavior evidence; cannot claim complete from local photos or injected offline events. No CODING_PASS/EVAL_PASS recorded, no feature completion or commit.

User was asked whether to supply device under existing criteria or explicitly consolidate real-device/iCloud evidence at F018 while retaining per-feature implementation and independent evaluation/commit. No answer yet; acceptance has NOT been changed. Await this decision before marking coding ready for independent evaluation or moving to F007.

Failure domain capability_gap. No generic harness change required: existing acceptance correctly prevents replacing real platform evidence with fakes. Durable verification protocols already exist in docs/verification.md.

## User-approved verification allocation

User explicitly approved consolidating real-device/iCloud verification into F018 and continuing per-feature independent evaluation/commit. SPEC normalization, F006/F007 verification wording and F018 acceptance updated without changing IDs or prior feature status. docs/deferred-device-verification.md tracks every deferred item as unexecuted. Earlier blocker text above is historical; no claim that cloud behavior is verified.

Resumed full ./init.sh exited0, all local loader tests and prior real system checks passed; .build/test-run.PtWCGB/Tests.xcresult, /private/tmp/swipe-resume-F006.log. Implementation ready for independent evaluation under the user-approved acceptance allocation.

FAST_CODING_EVIDENCE: F006
CODING_PASS: F006
