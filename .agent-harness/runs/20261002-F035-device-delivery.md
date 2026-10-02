# F035 commit and phone delivery — 2026-10-02

- User explicitly requested commit, push to the configured remote, and installation on the configured phone.
- Precommit recovery exited 0: `.build/verification/20261002T145213-fez7763s/report.md`; reused intact independent fresh evidence (105 unit + 45 UI, 150 passed, zero failures/skips), with live simulator installation/launch.
- `.build/F035-install.py` reused the established signing/install workflow with F035 evaluator receipt `.build/verification/20261002T142417-b6m6zn9l/receipt.json`. Source hashes verified before build, after build and after installation. Product source unchanged from acceptance.
- Existing LeafDay presence confirmed on configured phone; Debug device build, strict signature verification, in-place installation, normal launch and post-install app query succeeded. No uninstall or app data-clear operation.
- Identity: LeafDay / dev.armstrong.swipego. Package digest: eb2246c55581444a354eced378b62d09f80c05ce21ca4e0ec910519dd0a8cfcd.
- JSON receipts: `.build/F035-phone-preflight.json`, `.build/F035-device-build-receipt.json`, `.build/F035-device-install.json`, `.build/F035-device-launch.json`, `.build/F035-device-postinstall.json`.
- This is installation and launch evidence, not private-library/iCloud acceptance. F018 remains deferred; no device acceptance test suite was run.
- Authorized commit scope is F035 source/tests/generated project/docs and canonical workflow evidence. Push destination: https://github.com/yanqian/leaft-day.git, main.
