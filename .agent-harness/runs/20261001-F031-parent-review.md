# F031 additional parent review — reuse scope

During the independent run, the final native suite passed. Parent compared the actual final receipt's PATH with the parent tool environment without modifying sources.

Observed difference: evaluator adds only `/Users/armstrong/.codex/tmp/arg0/codex-arg0GPDEj6`; the parent has no extra entries. Both contexts otherwise use the same project/toolchain. Current fingerprint compares the entire literal PATH, so its full receipt will not be reusable by a later parent/commit session solely due to a provider's temporary alias directory. This is conservative (no false pass), but undermines the intended cross-stage recovery/commit savings.

Before final delivery, evaluate/fix fingerprinting to compare resolved tools actually used by the verification workflow instead of the entire search-path string. Real tool changes must continue to invalidate reuse. Add a contract for irrelevant PATH-prefix equivalence versus executable shadowing. Keep sources frozen until the current independent process completes; do not weaken fresh Evaluator execution. This finding is not an evaluator pass or permission to skip required verification.
