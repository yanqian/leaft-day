# F015 resume provider capability recovery

After user reboot/resume, root ./init.sh passed42 XCTest/13 XCUITest/2 physical Vision tests. First work-fast failed before F015 state mutation: configured old desktop CLI /Applications/ChatGPT.app/Contents/Resources/codex no longer exists. New installed bundle contains codex-cli/bin/codex, real --version reports0.158.0-alpha.2.1; exec help confirms stdin, model, ephemeral and approve-for-me flags.

Updated ignored agent-provider.json command/evaluator_command/runtime_check_command executable only; retained cwd=.., gpt-6-astra and the previously authorized evaluator approval flag. From canonical .agent-harness cwd, python3 scripts/run-agent-provider.py --role evaluator --check exits0 and reports both configuration/runtime checks OK. Log /private/tmp/swipe-F015-provider-check.log. An initial root-cwd invocation reported no config and made no state change; corrected cwd, no credential mutation.

Failure domain capability_gap: installed application changed executable location. Durable recovery note added to docs/development.md. Official noninteractive usage checked at https://learn.chatgpt.com/docs/non-interactive-mode; actual installed CLI help/runtime are authoritative for this build. No coding child launched, no evaluator bypass, no feature pass asserted.
