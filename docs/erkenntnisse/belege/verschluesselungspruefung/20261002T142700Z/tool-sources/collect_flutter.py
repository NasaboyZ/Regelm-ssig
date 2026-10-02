"""Copy evidence from a successful Flutter simulator run before reinstalling the app."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil


def collect(log_path, output):
    log = log_path.read_text()
    if 'All tests passed!' not in log:
        raise ValueError('Flutter success marker missing; do not treat an aborted test as evidence')
    paths = re.findall(r'^REGELMAESSIG_EVIDENCE_PATH=(.+)$', log, re.MULTILINE)
    if len(paths) != 1:
        raise ValueError('Expected exactly one Flutter evidence path')
    source = Path(paths[0].strip()).resolve()
    manifest = json.loads((source / 'manifest.json').read_text())
    if manifest.get('scope') != 'Actual Flutter storage; invented data; public debug keys':
        raise ValueError('Not the invented Flutter fixture')
    names = ['manifest.json']
    for artifact in manifest['artifacts']:
        name = artifact['file']
        if Path(name).name != name or not name.startswith(('open-flutter.db', 'closed-flutter.db')):
            raise ValueError('Unexpected artifact filename')
        file = source / name
        if file.exists() != artifact['exists']:
            raise ValueError('Incomplete Flutter evidence: ' + name)
        if artifact['exists']:
            if file.stat().st_size != artifact['bytes']:
                raise ValueError('Changed Flutter evidence: ' + name)
            names.append(name)
    output.mkdir(parents=True, exist_ok=False)
    hashes = {}
    for name in names:
        original = (source / name).read_bytes()
        shutil.copyfile(source / name, output / name)
        digest = hashlib.sha256(original).hexdigest()
        if hashlib.sha256((output / name).read_bytes()).hexdigest() != digest:
            raise ValueError('Copy mismatch: ' + name)
        hashes[name] = digest
    (output / 'collection.json').write_text(json.dumps({'source': str(source), 'sha256': hashes}, indent=2) + '\n')
    print(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--log', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='New directory; must not exist')
    args = parser.parse_args()
    collect(args.log, args.output)
