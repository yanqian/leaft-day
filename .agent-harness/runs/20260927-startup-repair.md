# Initialization repair

## Summary

2026-09-27: user asked to continue; scope now includes F001 via work-fast. No commit or subsequent feature authorized by this run.

## Evidence

- Original make work-fast failed at git log because this repository has no commits.
- Local orchestrator patch accepts a symbolic HEAD whose ref is absent; nonrepository/history failures remain errors. Init and evaluator gates remain required.
- Two regression tests use real temporary Git/non-Git directories; both pass.
- A concurrently running initializer test observed the in-flight file change and reported manifest drift. Local repair with --template-root .agent-harness refreshed installation hashes after the intentional patch; no files overwritten. This is a project-local change, not an upstream 0.3.9 update. Preserve/review it on future upgrades.
- Subsequent full Harness verification passed before provider preflight.
- Sandboxed Codex preflight failed writing its own state_5.sqlite and initializing app-server. Escalated work-fast was requested via tool approval; no model or sandbox bypass flags added to provider config.
- /Applications and ~/Applications Xcode app scans plus Spotlight bundle query returned no Xcode candidates. xcode-select points to CommandLineTools; xcrun cannot find simctl; xcodebuild -version fails. This does not prove no Xcode exists at any custom path.

## Failure Analysis

- Failure domain: agent_workflow_gap
- Harness improvement: tolerate explicitly unborn Git repositories with regression coverage, retaining errors for invalid repositories.
- Follow-up: provider runtime and F001 real toolchain capability; do not claim iOS readiness.
