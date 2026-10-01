# F015 v3 focused verification and correction

- Failure domain: implementation_gap
- Harness improvement: no harness source change needed. A real disclosure reopen UI regression now covers the entire row hit region rather than only the label. Serialize simulator invocations as documented for F009.
- Initial 6 unit/2 UI target run passed, including native cancel/success on newly generated simulator assets, no frozen list after success, accurate remaining=0 and history.
- New disclosure test failed because the plain HStack center was not a hit region. Added contentShape on disclosure and full-width action surfaces; dedicated .build/F015-v3-disclosure.xcresult passed.
- Screenshot review found forced-white text inadequate on softened pale backgrounds. Shared glass now has an adaptive-ink option used by deletion surfaces; immersive media defaults unchanged. Updated snapshots will come from final root run.
- .build/F015-v3-targeted2.xcresult is an overall failed result and remains preserved; no test failure concealed.
- Full root verification is running; no coding/evaluator verdict yet.
