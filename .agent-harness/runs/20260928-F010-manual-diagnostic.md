# F010 pre-repair diagnosis

- User clarified affected path: home Continue -> full-screen review.
- Observed current source failure using a Foundation-only runner copied from ReviewGesture.swift into ignored .build/F010-router-repro.swift: update(2,19), update(-160,25), end(-160,25), asset unchanged, blocked=false => nil. The final translation is plainly horizontal but 18pt early vertical lock suppresses navigation.
- Command: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift .build/F010-router-repro.swift
- Result: expected=next; actual=nil. No device assets read or mutated.
- Failure domain: implementation_gap
- Harness improvement: add this trace to unit regression and full home-presentation photo/video navigation to UI coverage; original test host does not prove production presentation.
- Limitation: this reproduces a real source defect, not the exact user's touch trace. Current paired phone tunnel reports disconnected, so no live incident attribution or device pass is claimed.
- No coding/evaluator verdict in this diagnostic.

Connectivity correction: a later targeted `devicectl device info apps --bundle-id dev.armstrong.swipego` succeeded. The earlier disconnected tunnel snapshot was not conclusive proof of continued inaccessibility. A proposed copy of app session store/WAL/SHM to ignored local diagnostics was rejected by automatic approval review for potentially sensitive data without specific export authorization. That command did not execute and will not be bypassed. Diagnosis continues using synthetic gesture inputs and simulator test sessions; no actual device session/asset attribution is claimed.
