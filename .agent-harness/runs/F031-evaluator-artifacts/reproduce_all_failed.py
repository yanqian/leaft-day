"""Evaluator contract probe; no native failing XCTest is claimed by this probe."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
import verification as v

out = Path(__file__).resolve().parent
raw = json.loads((ROOT / 'tests/fixtures/xcresult-summary-failed.json').read_text())
# Preserve the captured failure object/schema, model a one-case failing run.
raw.update(totalTestCount=1, passedTests=0, failedTests=1,
           skippedTests=0, expectedFailures=0)
(out / 'all-failed-input.json').write_text(json.dumps(raw, indent=2) + '\n')
report = {'version': v.VERSION, 'status': 'failed', 'mode': 'full',
          'steps': [], 'seconds': 0}
try:
    # Same assignment/order as execute(), before attachments are exported.
    report['preflightCounts'] = v.parse_summary(raw)
    report['exportReached'] = True
except ValueError as error:
    report['error'] = str(error)
v.write_report(out, report)
assert 'preflightCounts' not in report
assert 'exportReached' not in report
assert '0 passed / 0 failed' in (out / 'report.md').read_text()
print('BUG REPRODUCED: one failed test loses counts and stops before attachment export')
