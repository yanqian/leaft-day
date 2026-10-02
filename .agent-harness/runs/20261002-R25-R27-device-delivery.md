# F032–F034 authorized commit and device delivery

- User requested local commit and installation on the configured phone. No push requested.
- Submission recovery passed: `.build/verification/20261002T114757-sopo4m69/summary.json`; live simulator recovery succeeded and reused intact independent fresh evidence from `.build/verification/20261002T013445-sehcf3yf/receipt.json` (91 unit + 45 UI, 136 passed, zero failed/skipped).
- Script `.build/R25-R27-install.py` built Debug for generic iOS using the configured signing team, verified the signature, and checked source fingerprints before and after delivery against the independent evaluation receipt.
- Existing app presence was confirmed before an in-place installation. No uninstall or data-clear command was performed.
- Device installation, normal launch, and post-install application query all succeeded. JSON receipts: `.build/R25-R27-device-install.json`, `.build/R25-R27-device-launch.json`, `.build/R25-R27-device-postinstall.json`. Identity confirmed as `dev.armstrong.swipego`, displayed as `LeafDay`.
- Package and source receipt: `.build/R25-R27-device-build-receipt.json`. Package digest: `54b77bb420879b53c400d1bb5b94563fd7e9c41320413ea11ee06be0c3e16004`.
- Final script result: `DEVICE_DELIVERY_PASSED: in-place install and normal launch; package/source fingerprints match`.
- This proves installation and process launch, not private-library functional acceptance. F018 remains deferred and was not scheduled. Local commit includes F032/F033/F034 and their harness evidence; no push.
