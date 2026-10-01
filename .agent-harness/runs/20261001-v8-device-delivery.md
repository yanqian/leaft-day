# v8 authorized finalization and physical-device delivery

User explicitly requested commit and installation, then confirmed the configured iPhone connected. Existing related v2–v8 source, test, design and harness evidence changes are the reviewed delivery scope; F018 partial test tooling/evidence remains explicitly incomplete. No unrelated project files or signing configuration are included.

- Independent source baseline: runs/20261001-F029-reevaluation.md, 85 unit/44 UI passed. All 112 inventoried product/test/script hashes matched before build and immediately before installation.
- Signed build succeeded with the existing development team, Debug generic iOS, separate .build/v8-device-derived. Signing trust verification passed with approved system certificate access. No signing identity or bundle identifier change.
- .build/v8-device-build-receipt.json records 112 source hashes and all 12 signed package file hashes. Both sets rechecked before installation. Build log: .build/v8-device-build.log.
- Configured iPhone iOS26.6.2 was reached by read-only app lookup despite initial discovery reporting disconnected. Existing dev.armstrong.swipego confirmed.
- In-place install succeeded, exit0 and JSON info.outcome=success; installedApplications confirms dev.armstrong.swipego. Receipt .build/v8-device-install.json; log .build/v8-device-install.log.
- Normal app launch succeeded without test arguments; .build/v8-device-launch.json reports success and processIdentifier34430.
- No uninstall, data clear, private-photo operation, device test suite or push. Installation/launch is not F018 real iCloud/private-library/large-library acceptance; F018 stays todo/false.

Commit-time ./init.sh completed successfully: 85 unit/44 UI, zero failures, simulator install/launch passed. Result .build/test-run.TmNGKu/Tests.xcresult; log .build/v8-finalize-init.log. Final source hashes still match the installed package receipt. User-authorized local batch commit includes accumulated related F009/F010/F015/F018–F029 implementation, regression and evidence; F018 remains incomplete, and no push is requested.
