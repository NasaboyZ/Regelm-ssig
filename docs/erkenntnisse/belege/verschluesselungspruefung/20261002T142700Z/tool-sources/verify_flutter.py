"""Read-only verification of the invented fixture exported by Flutter, never user DBs."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sqlite3
import sys

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import cryptography
from sqlcipher_db import Database, DatabaseError

DB_KEY = 'regelmaessig-debug-test-key-v1'
DATA_KEY = bytes(range(32))
TABLES = ('day_entries', 'custom_categories', 'tracking_metadata')


def decode(payload, table, row_id, key=DATA_KEY):
    if len(payload) < 29 or payload[0] != 1:
        raise ValueError('Unsupported or truncated payload')
    aad = json.dumps(['regelmaessig.tracking', 1, table, row_id], separators=(',', ':')).encode()
    return AESGCM(key).decrypt(payload[1:13], payload[13:], aad)


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def rejected(action, errors):
    try:
        action()
    except errors as error:
        return type(error).__name__
    raise AssertionError('Unexpectedly accepted')


def hashes(directory):
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(directory.iterdir()) if p.is_file()}


def verify(evidence, output):
    output.mkdir(parents=True, exist_ok=False)
    results = []

    def check(name, action, ready=True):
        if not ready:
            results.append({'test': name, 'status': 'NOT_TESTED', 'detail': 'Required positive control failed'})
            return False
        try:
            detail = action()
            results.append({'test': name, 'status': 'PASS', 'detail': detail})
            return True
        except AssertionError as error:
            results.append({'test': name, 'status': 'FAIL', 'detail': str(error)})
        except Exception as error:
            results.append({'test': name, 'status': 'NOT_TESTED', 'detail': type(error).__name__ + ': ' + str(error)})
        return False

    before = hashes(evidence)
    manifest = {}
    rows = {}
    path = evidence / 'closed-flutter.db'

    def preflight():
        manifest.update(json.loads((evidence / 'manifest.json').read_text()))
        require(manifest['scope'] == 'Actual Flutter storage; invented data; public debug keys', 'Unexpected evidence scope')
        require(manifest['database_key'] == DB_KEY and manifest['data_key_hex'] == DATA_KEY.hex(), 'Not the public fixture keys')
        require(manifest['roundtrip_after_reopen'] is True, 'Flutter roundtrip missing')
        require(path.is_file() and path.stat().st_size > 0, 'Closed database missing or empty')
        for artifact in manifest['artifacts']:
            name = artifact['file']
            require(Path(name).name == name, 'Invalid artifact filename')
            file = evidence / name
            require(file.exists() == artifact['exists'], 'Artifact presence mismatch: ' + name)
            if artifact['exists']:
                require(file.stat().st_size == artifact['bytes'], 'Artifact size mismatch: ' + name)
        return 'Complete Flutter fixture manifest and database present'

    valid = check('Flutter evidence is complete', preflight)

    def positive_control():
        with Database(path, DB_KEY, readonly=True) as db:
            require(db.query('PRAGMA user_version') == [[2]], 'Expected schema 2')
            require(db.query('PRAGMA integrity_check') == [['ok']], 'SQLite integrity check failed')
            for table in TABLES:
                columns = db.query('PRAGMA table_info(' + table + ')')
                require([c[1] for c in columns] == ['id', 'payload'], 'Unexpected columns')
                rows[table] = db.query('SELECT id, payload FROM ' + table + ' ORDER BY id')
            (output / 'sqlcipher.json').write_text(json.dumps({
                name: db.query('PRAGMA ' + name) for name in ('cipher_version', 'user_version', 'cipher_integrity_check')
            }, indent=2) + '\n')
        days = [json.loads(decode(blob, 'day_entries', row_id)) for row_id, blob in rows['day_entries']]
        categories = [json.loads(decode(blob, 'custom_categories', row_id)) for row_id, blob in rows['custom_categories']]
        actual = {'version': 1, 'days': days, 'categories': {c['id']: c['name'] for c in categories}}
        require(actual == manifest['expected_snapshot'], 'Decrypted snapshot differs from Flutter fixture')
        require(rows['tracking_metadata'] and len(rows['tracking_metadata']) == 1, 'Missing metadata')
        row_id, blob = rows['tracking_metadata'][0]
        require(row_id == 1 and decode(blob, 'tracking_metadata', 1) == b'regelmaessig-tracking-data-key-v1', 'Wrong metadata')
        (output / 'decrypted-public-fixture.json').write_text(json.dumps(actual, indent=2, ensure_ascii=False) + '\n')
        return 'All fields and metadata independently decrypted with both public keys; exact Flutter snapshot match'

    readable = check('Both public keys decrypt actual Flutter database', positive_control, valid)

    def query_with_key(key):
        with Database(path, key, readonly=True) as db:
            return db.query('SELECT * FROM day_entries')

    for label, key in [('No SQLCipher key', None), ('Wrong SQLCipher key', 'incorrect-key')]:
        check(label + ' rejected', lambda key=key: rejected(lambda: query_with_key(key), (DatabaseError,)), readable)

    def ordinary_sqlite():
        db = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True)
        try:
            return rejected(lambda: db.execute('SELECT * FROM day_entries').fetchall(), (sqlite3.DatabaseError,))
        finally:
            db.close()
    check('Ordinary SQLite cannot query database', ordinary_sqlite, readable)

    markers = []
    def collect(value):
        if isinstance(value, str) and 'ERFUNDEN' in value:
            markers.append(value.encode())
        elif isinstance(value, dict):
            for child in value.values():
                collect(child)
        elif isinstance(value, list):
            for child in value:
                collect(child)
    collect(manifest.get('expected_snapshot', {}))

    def outer_only():
        require(markers, 'Missing plaintext control markers')
        for table in TABLES:
            for _, blob in rows[table]:
                require(isinstance(blob, bytes) and len(blob) >= 29 and blob[0] == 1, 'Not an encrypted payload')
                require(not any(marker in blob for marker in markers), 'Plaintext marker in payload')
        return 'Only technical IDs and encrypted BLOBs; row counts, ordering and lengths remain visible'
    check('SQLCipher key alone exposes encrypted payloads', outer_only, readable)

    def scan():
        require(markers, 'Missing plaintext control markers')
        scanned = []
        for artifact in manifest['artifacts']:
            if not artifact['exists']:
                continue
            raw = (evidence / artifact['file']).read_bytes()
            require(not any(marker in raw for marker in markers), 'Plaintext marker in ' + artifact['file'])
            if artifact['file'].endswith('.db'):
                require(not raw.startswith(b'SQLite format 3\x00'), 'Plain SQLite header')
            scanned.append(artifact['file'])
        return {'scanned': scanned, 'marker_count': len(markers), 'limitation': 'Known-marker scan only; absent sidecars not tested'}
    check('Known plaintext markers absent from captured DB files', scan, readable)

    if readable:
        row_id, payload = rows['day_entries'][0]
        check('Wrong AES key rejected', lambda: rejected(lambda: decode(payload, 'day_entries', row_id, bytes([43]) * 32), (InvalidTag,)))
        for label, index in [('Nonce', 1), ('Ciphertext', 13), ('Tag', len(payload) - 1)]:
            changed = bytearray(payload)
            changed[index] ^= 1
            check(label + ' manipulation rejected', lambda changed=bytes(changed): rejected(lambda: decode(changed, 'day_entries', row_id), (InvalidTag,)))
        check('Changed table binding rejected', lambda: rejected(lambda: decode(payload, 'custom_categories', row_id), (InvalidTag,)))
        check('Changed row binding rejected', lambda: rejected(lambda: decode(payload, 'day_entries', row_id + 1), (InvalidTag,)))
        check('Unknown payload version rejected', lambda: rejected(lambda: decode(b'\x02' + payload[1:], 'day_entries', row_id), (ValueError,)))
        check('Truncated payload rejected', lambda: rejected(lambda: decode(payload[:10], 'day_entries', row_id), (ValueError,)))
    else:
        check('AES manipulation controls', lambda: None, False)

    def unchanged():
        require(hashes(evidence) == before, 'Evidence files changed')
        return 'SHA-256 and file inventory unchanged; mutations used in-memory byte copies only'
    check('Source evidence unchanged', unchanged)
    (output / 'checks.json').write_text(json.dumps(results, indent=2, ensure_ascii=False) + '\n')
    (output / 'environment.json').write_text(json.dumps({
        'timestamp_utc': datetime.now(timezone.utc).isoformat(), 'python': sys.version,
        'cryptography': cryptography.__version__, 'source_hashes': before,
        'verifier_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'command': sys.argv, 'scope': 'Read-only exported Flutter fixture; public keys; no production key security claim',
    }, indent=2) + '\n')
    passed = sum(r['status'] == 'PASS' for r in results)
    report = ['# Flutter-Dateiprüfung', '', 'PASS bedeutet erwartetes Verhalten, keine Sicherheitszertifizierung.', '',
              '| Prüfung | Status | Beobachtung |', '| --- | --- | --- |']
    for result in results:
        detail = str(result['detail']).replace('|', '\\|').replace('\n', ' ')
        report.append(f"| {result['test']} | {result['status']} | {detail} |")
    report += ['', f'{passed}/{len(results)} PASS. Details: [checks.json](checks.json).']
    (output / 'bericht.md').write_text('\n'.join(report) + '\n')
    print(f'{passed}/{len(results)} PASS; {output / "bericht.md"}')
    return 0 if passed == len(results) else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, required=True, help='Copied Flutter evidence directory with manifest.json')
    parser.add_argument('--output', type=Path, required=True, help='New report directory (must not exist)')
    args = parser.parse_args()
    raise SystemExit(verify(args.evidence.resolve(), args.output.resolve()))
