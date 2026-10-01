"""Optional reviewed screenshot baselines; native sips decoding, stdlib comparison."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile

DEFAULT_POLICY = {'maxDimension': 512, 'channelTolerance': 24, 'changedFraction': 0.01,
                  'ignoreTopFraction': 0.05}


def image_key(item):
    # xcresulttool adds a repetition index + UUID to the user-given attachment name.
    name = re.sub(r'_\d+_[0-9A-Fa-f-]{36}(?=\.png$)', '', item['name'])
    return item['test'] + '/' + name


def screenshots(items):
    images = {}
    for item in items:
        if Path(item['path']).suffix.lower() == '.png':
            key = image_key(item)
            if key in images:
                raise ValueError(f'Duplicate screenshot key; name each attachment distinctly: {key}')
            images[key] = Path(item['path'])
    return images


def validate_policy(policy):
    if (type(policy.get('maxDimension')) is not int or not 64 <= policy['maxDimension'] <= 2048 or
            type(policy.get('channelTolerance')) is not int or not 0 <= policy['channelTolerance'] <= 255 or
            not isinstance(policy.get('changedFraction'), (int, float)) or not 0 <= policy['changedFraction'] < 1 or
            not isinstance(policy.get('ignoreTopFraction'), (int, float)) or not 0 <= policy['ignoreTopFraction'] <= 0.1):
        raise ValueError('Invalid visual comparison policy')


def read_bmp(data):
    if data[:2] != b'BM' or len(data) < 54:
        raise ValueError('Invalid BMP')
    offset = struct.unpack_from('<I', data, 10)[0]
    header, width, height, planes, bits, compression = struct.unpack_from('<IiiHHI', data, 14)
    if header != 40 or width <= 0 or height == 0 or planes != 1 or bits != 24 or compression != 0:
        raise ValueError('Unsupported native sips BMP schema')
    stride = (width * 3 + 3) // 4 * 4
    if len(data) < offset + stride * abs(height):
        raise ValueError('Truncated BMP')
    rows = [data[offset + y * stride:offset + y * stride + width * 3] for y in range(abs(height))]
    if height > 0:
        rows.reverse()
    return width, abs(height), b''.join(rows)


def decode(path, dimension):
    with tempfile.TemporaryDirectory() as tmp:
        output = Path(tmp) / 'pixels.bmp'
        proc = subprocess.run(['sips', '-Z', str(dimension), '-s', 'format', 'bmp', str(path), '--out', str(output)],
                              capture_output=True, text=True, timeout=60)
        if proc.returncode:
            raise ValueError(f'sips failed to decode {path}: {proc.stderr}')
        return read_bmp(output.read_bytes())


def compare_pixels(left, right, policy):
    if left[:2] != right[:2]:
        return {'status': 'changed', 'reason': 'image dimensions changed', 'changedFraction': 1.0}
    width, height, a = left
    b = right[2]
    start = int(height * policy['ignoreTopFraction']) * width * 3
    changed = sum(max(abs(a[i] - b[i]), abs(a[i + 1] - b[i + 1]), abs(a[i + 2] - b[i + 2])) > policy['channelTolerance']
                  for i in range(start, len(a), 3))
    ratio = changed / ((len(a) - start) // 3)
    return {'status': 'changed' if ratio > policy['changedFraction'] else 'unchanged',
            'changedFraction': ratio, 'comparisonSize': [width, height]}


def accept_baseline(summary, directory):
    """Only called by the user's explicit acceptance command, never by a test run."""
    report = json.loads(Path(summary).read_text())
    if 'details' in report:
        details = json.loads(Path(report['details']).read_text())
        if details.get('status') != report.get('status') or details.get('counts') != report.get('counts'):
            raise ValueError('Summary and detailed receipt disagree')
        report = details
    # A visual-only failure may be intentionally approved; behavior failures may not.
    if report.get('status') != 'passed' and report.get('error') != 'Visual baseline needs review':
        raise ValueError('Cannot accept baseline from a failed behavioral/build verification')
    if report.get('counts', {}).get('result') != 'Passed' or not report.get('attachments'):
        raise ValueError('No successful test screenshot evidence')
    images = screenshots(report['attachments'])
    if not images:
        raise ValueError('No PNG screenshots to approve')
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    manifest_path = directory / 'baseline.json'
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        if manifest.get('version') != 1:
            raise ValueError('Unknown baseline version')
    else:
        manifest = {'version': 1, 'policy': DEFAULT_POLICY.copy(), 'images': {}}
    validate_policy(manifest['policy'])
    if report.get('mode') == 'full':
        manifest['images'] = {}
    for key, source in images.items():
        payload = source.read_bytes()
        sha = hashlib.sha256(payload).hexdigest()
        filename = sha + '.png'
        (directory / filename).write_bytes(payload)
        manifest['images'][key] = {'file': filename, 'sha256': sha}
    manifest['approvedFrom'] = str(Path(summary).resolve())
    # Targeted reports merge; explicit full approval also accepts removed screenshots.
    temporary = directory / 'baseline.json.tmp'
    temporary.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(manifest_path)
    return len(images)


def compare(items, baseline, output, *, complete=False, exercised=()):
    baseline, output = Path(baseline), Path(output)
    if not (baseline / 'baseline.json').exists():
        return {'status': 'not_configured', 'items': [], 'note': 'Review screenshots, then explicitly accept a baseline.'}
    manifest = json.loads((baseline / 'baseline.json').read_text())
    if manifest.get('version') != 1 or not isinstance(manifest.get('images'), dict):
        raise ValueError('Unknown visual baseline schema')
    policy = manifest['policy']; validate_policy(policy)
    current = screenshots(items)
    output.mkdir(parents=True, exist_ok=True)
    rows = []
    for key, path in current.items():
        expected = manifest['images'].get(key)
        entry = {'key': key, 'actual': str(path)}
        if expected is None:
            entry.update(status='new', reason='No approved baseline')
        else:
            filename = expected['file']
            if Path(filename).name != filename:
                raise ValueError('Invalid baseline image path')
            source = baseline / filename
            if hashlib.sha256(source.read_bytes()).hexdigest() != expected['sha256']:
                raise ValueError(f'Baseline image changed without approval: {key}')
            # Preserve an immutable copy for reports, even if baseline changes later.
            saved = output / filename
            shutil.copyfile(source, saved)
            entry['baseline'] = str(saved)
            entry.update(compare_pixels(decode(source, policy['maxDimension']), decode(path, policy['maxDimension']), policy))
        rows.append(entry)
    rows += [{'key': key, 'status': 'missing', 'reason': 'Approved screenshot was not produced'}
             for key in sorted(set(manifest['images']) - set(current))
             if complete or any(key.startswith(case + '/') for case in exercised)]
    return {'status': 'needs_review' if any(r['status'] != 'unchanged' for r in rows) else 'passed',
            'policy': policy, 'items': rows}
