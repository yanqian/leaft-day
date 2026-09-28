# F013 in-progress diagnostics (not coding pass)

Base: 91a62fb. F013 fast handoff exists; feature remains in_progress, unaccepted.

## Scheduling

The picker ignores depends_on. It prematurely selected P0 F015 ahead of P1 prerequisites F013/F014. No F015 coding happened. Existing orchestrator mark_failed recorded failure without resetting attempts; prerequisite priorities are now P0 with existing topological feature order. Both invalid handoff records are retained. First recovery invocation used wrong cwd and failed before writing, then was corrected in the hidden harness directory. No acceptance requirements or evaluator gates weakened.

## Real Vision failure investigation

- iOS 26.5 simulator, Xcode 26.6; only generated media.
- Default revision 2 failed to create espresso context.
- Explicit supported CPU devices enabled execution but returned effectively identical vectors for distinct fixtures. Repeat, near and unrelated distances ~0.0017805373; smile/frown 0.0. Failed expected negative controls.
- Exported normalized 512px PNGs visually inspected: actual correct distinct drawings; landscape and exact copy have identical SHA256 40b5c43852c118cdac41560db22a1d6a6620db408a45a2641f6b4c39660d051d.
- Direct native observation distances equal archived/unarchived distances; serialization is not the cause.
- Standard-range rendering, PNG data input, and default scaleFill still failed. Legacy revision 1 usesCPUOnly returned nondeterministic distances, including ~19.738 between byte-identical normalized inputs; not a valid alternative.
- Modern Swift GenerateImageFeaturePrintRequest directly on bundled originals also failed the expression negative control (distance 0), removing PhotoKit/normalization/legacy API from that minimal reproduction.
- Same original fixtures in minimal macOS native Vision CPU revision 2: exact 0.0, near 0.035100292, expression 0.32738093, unrelated 0.15041101. This diagnoses environment variation; it is NOT iOS acceptance evidence.
- Public request revision/compute-device APIs verified against installed SDK headers/interfaces; Apple's documentation: https://developer.apple.com/documentation/vision/analyzing-image-similarity-with-feature-print . No third-party workaround treated as proof.
- Failed result bundles: .build/F013-analysis*, F013-diagnostics, F013-direct, F013-standard, F013-image-data, F013-revision1, F013-cpu-legacy, F013-modern2, F013-fill .xcresult. Logs /private/tmp/swipe-F013-*.log.
- simctl has only iOS26.5; devicectl reports no devices. Installing official iOS26.0 arm64 runtime (23A343, 7.99GB) for an isolated minimum-version comparison via xcodebuild -downloadPlatform iOS -buildVersion 26.0 -architectureVariant arm64. Awaiting result; no unverified pass.

Current source includes temporary diagnostics and a failing regression test; must clean up and pass actual iOS verification before coding/evaluator pass. Features F014 onward not implemented.

## Second-runtime result and safe boundary

Official iOS26.0 runtime installed successfully; isolated probe device F31F5C4A-BA53-47E6-958C-0F1932CC61C8. Modern Swift API probe could not load due missing setComputeDevice symbol in 26.0 despite SDK availability annotations. Compatible VNRequest CPU revision2 on directly bundled original images again failed: exact 0.0017805373, expression 0.0, unrelated 0.0017805373 (.build/F013-runtime260-legacy.xcresult). No fixture PhotoKit mutations on the new device.

Temporary debug image exports/native observation retention removed from product. Native printer returns to explicit supported CPU revision2 and now tests contrasting generated controls once per instance; unreliable runtime throws runtimeUnavailable, propagated by the engine, so no groups are published. The original positive/negative acceptance tests remain and still must pass before F013 can complete; fail-closed behavior alone is not a substitute.

No connected device from devicectl. User was asked to connect an iOS26+ phone (disposable test assets only, signing team may require Xcode setup). Shared-library deletion scope also remains an unanswered product question. F014-F018 must not be treated as done or begun through the dependency-blind picker while required F013 proof is unavailable.

## Final recovery

Final ./init.sh exit65; .build/test-run.v3dfHX/Tests.xcresult, log /private/tmp/swipe-F013-blocked-init.log. 39 unit tests executed: 34 existing and 3 F013 controlled-domain tests pass; 2 native Vision tests fail (4 assertions/errors). All 12 UI tests pass, including real favorite, pending cancel/confirm, home, permissions, gestures and video. Thus previous features remain verified while F013 acceptance is honestly blocked. No F013 Coding Pass, no evaluator pass, no commit. Native self-check actually returned runtimeUnavailable in the PhotoKit acceptance test; unreliable groups cannot publish. No outstanding processes.
