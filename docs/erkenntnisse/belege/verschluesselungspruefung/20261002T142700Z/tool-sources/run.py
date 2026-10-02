"""Reproducible local-only experiment with invented data. No external target option."""
import csv
import argparse
from datetime import datetime, timezone
import hashlib
from html import escape
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import threading
from urllib.parse import parse_qs, urlsplit
from urllib.request import ProxyHandler, build_opener

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import cryptography
from sqlcipher_db import Database, DatabaseError

ROOT = Path(__file__).resolve().parent
# Public fixtures already present in the app; NEVER production secrets.
DB_KEY = 'regelmaessig-debug-test-key-v1'
DATA_KEY = bytes(range(32))
NOTE = 'ERFUNDEN-LABOR-KEINE-PERSONENDATEN-20260928'
TABLES = ('day_entries', 'custom_categories', 'tracking_metadata')


def json_bytes(value):
    return json.dumps(value, separators=(',', ':'), ensure_ascii=False).encode()


def context(table, row_id):
    return json_bytes(['regelmaessig.tracking', 1, table, row_id])


def encrypt(raw, table='day_entries', row_id=1):
    nonce = os.urandom(12)
    return b'\x01' + nonce + AESGCM(DATA_KEY).encrypt(nonce, raw, context(table, row_id))


def decrypt(payload, key=DATA_KEY, table='day_entries', row_id=1):
    if len(payload) < 29 or payload[0] != 1:
        raise ValueError('Unsupported or truncated payload')
    return AESGCM(key).decrypt(payload[1:13], payload[13:], context(table, row_id))


def create_fixture(path, inner_encryption):
    fixture = {'date': '2026-09-28', 'selections': {}, 'customValues': {},
               'appointments': [], 'note': NOTE, 'temperature': 36.7, 'weight': None}
    clear = json_bytes(fixture)
    rows = {
        'day_entries': [clear, json_bytes({**fixture, 'date': '2026-09-29', 'note': 'Sichtbarer Kontrolldatensatz'})],
        'custom_categories': [json_bytes({'id': 'labor', 'name': 'Erfundene Kategorie'})],
        'tracking_metadata': [b'regelmaessig-tracking-data-key-v1'],
    }
    with Database(path, DB_KEY) as db:
        db.query('PRAGMA user_version = 2')
        for table in TABLES:
            db.query(f'CREATE TABLE {table} (id INTEGER PRIMARY KEY NOT NULL, payload BLOB NOT NULL)')
            for row_id, raw in enumerate(rows[table], 1):
                payload = encrypt(raw, table, row_id) if inner_encryption else raw
                db.query(f'INSERT INTO {table} (id, payload) VALUES (?, ?)', (row_id, payload))
        metadata = {name: db.query('PRAGMA ' + name) for name in (
            'cipher_version', 'cipher_provider', 'cipher_provider_version', 'cipher_page_size',
            'kdf_iter', 'cipher_hmac_algorithm', 'cipher_kdf_algorithm', 'cipher_use_hmac',
            'temp_store', 'journal_mode', 'secure_delete', 'user_version', 'compile_options')}
        if not metadata['cipher_version']:
            raise RuntimeError('SQLCipher not available')
        payload = db.query('SELECT payload FROM day_entries WHERE id=1')[0][0]
    return clear, payload, metadata


def server_for(paths, http_log):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format_string, *args):
            with http_log.open('a') as log:
                log.write(f'{self.log_date_time_string()} {format_string % args}\n')

        def do_GET(self):
            url = urlsplit(self.path)
            if url.path not in ('/vulnerable/plain', '/vulnerable/encrypted', '/safe/encrypted'):
                self.send_error(404)
                return
            row_id = parse_qs(url.query).get('id', ['2'])[0]
            kind = 'plain' if url.path.endswith('/plain') else 'encrypted'
            try:
                db = self.server.connections[kind]
                query = 'SELECT id, payload FROM day_entries WHERE id = '
                # Deliberate lab vulnerability, confined to a read-only fixture.
                rows = db.query(query + '?', (row_id,)) if url.path.startswith('/safe/') else db.query(query + row_id)
                rendered = []
                for row in rows:
                    cells = []
                    for value in row:
                        if isinstance(value, bytes):
                            value = value.hex() if kind == 'encrypted' else value.decode('utf-8', errors='replace')
                        cells.append('<td>' + escape(str(value)) + '</td>')
                    rendered.append('<tr>' + ''.join(cells) + '</tr>')
                body = ('<html><body><h1>Lokales SQL-Labor</h1><table>' + ''.join(rendered) + '</table></body></html>').encode()
                self.send_response(200)
            except DatabaseError:
                # Stable error response; never write plaintext values into error messages.
                body = b'<html><body>SQL query rejected</body></html>'
                self.send_response(500)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = HTTPServer(('127.0.0.1', 0), Handler)
    server.connections = {kind: Database(path, DB_KEY, readonly=True) for kind, path in paths.items()}
    return server


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def expect_rejection(call, errors):
    try:
        call()
    except errors as error:
        return type(error).__name__ + ': ' + (str(error) or 'Authentication rejected')
    raise AssertionError('Unexpectedly accepted')


def run_sqlmap(command, log_path, live):
    with log_path.open('w') as log:
        if not live:
            return subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180, cwd=ROOT).returncode
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, cwd=ROOT) as process:
            def tee():
                for line in process.stdout:
                    log.write(line)
                    log.flush()
                    print(line, end='', flush=True)
            reader = threading.Thread(target=tee)
            reader.start()
            try:
                return process.wait(timeout=180)
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait()
                reader.join()


def main(live=False):
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    output = ROOT / 'results' / stamp
    output.mkdir(parents=True)
    print(f'Belege: {output}', flush=True)
    results = []

    def check(name, action):
        print(name, flush=True)
        try:
            detail = action()
            results.append({'test': name, 'status': 'PASS', 'detail': detail})
        except AssertionError as error:
            results.append({'test': name, 'status': 'FAIL', 'detail': f'{type(error).__name__}: {error}'})
        except Exception as error:
            results.append({'test': name, 'status': 'NOT_TESTED', 'detail': f'{type(error).__name__}: {error}'})
        print('  ' + results[-1]['status'], flush=True)
        (output / 'checks.json').write_text(json.dumps(results, indent=2, ensure_ascii=False) + '\n')

    paths = {kind: output / f'{kind}.db' for kind in ('plain', 'encrypted')}
    clear, plain_payload, plain_meta = create_fixture(paths['plain'], False)
    _, encrypted_payload, encrypted_meta = create_fixture(paths['encrypted'], True)
    copied = output / 'stolen-copy.db'
    shutil.copy2(paths['encrypted'], copied)
    hashes_before = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in (*paths.values(), copied)}
    sqlmap = ROOT / 'vendor/sqlmap/sqlmap.py'
    manifest = {
        'timestamp_utc': stamp, 'python': sys.version, 'cryptography': cryptography.__version__,
        'sqlmap_version': subprocess.check_output([sys.executable, str(sqlmap), '--version'], text=True).strip(),
        'build': json.loads((ROOT / 'vendor/build.json').read_text()),
        'database_pragmas': {'plain': plain_meta, 'encrypted': encrypted_meta},
        'fixture_hashes': hashes_before,
        'scope': 'Python lab reproduction of app schema/format, NOT the running Flutter application',
        'app_sources_sha256': {str(p.relative_to(ROOT.parent)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in [ROOT.parent / 'regelmaessig/lib/services' / name for name in
                                        ('tracking_payload_cipher.dart', 'sqlcipher_tracking_storage.dart', 'debug_tracking_keys.dart')]},
    }
    (output / 'environment.json').write_text(json.dumps(manifest, indent=2) + '\n')

    def read_copy(key):
        with Database(copied, key, readonly=True) as db:
            return db.query('SELECT * FROM day_entries')

    check('Dateikopie ohne SQLCipher-Schlüssel abgewiesen',
          lambda: expect_rejection(lambda: read_copy(None), (DatabaseError,)))
    check('Dateikopie mit falschem SQLCipher-Schlüssel abgewiesen',
          lambda: expect_rejection(lambda: read_copy('incorrect-key'), (DatabaseError,)))

    def ordinary_sqlite():
        db = sqlite3.connect(copied.as_uri() + '?mode=ro', uri=True)
        try:
            return expect_rejection(lambda: db.execute('SELECT * FROM day_entries').fetchall(), (sqlite3.DatabaseError,))
        finally:
            db.close()
    check('Gewöhnliches SQLite kann die Dateikopie nicht lesen', ordinary_sqlite)

    def file_scan():
        for path in paths.values():
            raw = path.read_bytes()
            require(not raw.startswith(b'SQLite format 3\x00'), 'Unencrypted SQLite header')
            for token in (NOTE.encode(), b'day_entries', b'Erfundene Kategorie'):
                require(token not in raw, 'Plaintext token found in ' + path.name)
        return 'Kein SQLite-Klartextheader und keine Testmarker; nur ergänzende Indizien.'
    check('Dateien enthalten keine bekannten Klartextmarker', file_scan)

    def outer_key_only():
        rows = read_copy(DB_KEY)
        require(rows[0][1] == encrypted_payload, 'Unexpected payload')
        require(NOTE.encode() not in rows[0][1], 'Plaintext exposed')
        return 'Korrekte Passphrase öffnet Tabellen; id und AES-BLOB sind sichtbar.'
    check('Nur Datenbankschlüssel: verschlüsselte Payload lesbar', outer_key_only)

    def both_keys():
        require(decrypt(read_copy(DB_KEY)[0][1]) == clear, 'Roundtrip mismatch')
        return 'Dateikopie mit beiden öffentlichen Debug-Schlüsseln vollständig entschlüsselt.'
    check('Beide Debug-Schlüssel: Testeintrag entschlüsselt', both_keys)
    check('Falscher AES-Schlüssel abgewiesen', lambda: expect_rejection(
        lambda: decrypt(encrypted_payload, key=bytes([43]) * 32), (InvalidTag,)))
    for name, index in [('Nonce', 1), ('Ciphertext', 13), ('Tag', len(encrypted_payload) - 1)]:
        changed = bytearray(encrypted_payload)
        changed[index] ^= 1
        check(f'Manipulation an {name} abgewiesen', lambda changed=bytes(changed): expect_rejection(
            lambda: decrypt(changed), (InvalidTag,)))
    check('Vertauschte Tabellenbindung abgewiesen', lambda: expect_rejection(
        lambda: decrypt(encrypted_payload, table='custom_categories'), (InvalidTag,)))
    check('Vertauschte Zeilenbindung abgewiesen', lambda: expect_rejection(
        lambda: decrypt(encrypted_payload, row_id=2), (InvalidTag,)))
    check('Unbekannte Payloadversion abgewiesen', lambda: expect_rejection(
        lambda: decrypt(b'\x02' + encrypted_payload[1:]), (ValueError,)))
    check('Abgeschnittene Payload abgewiesen', lambda: expect_rejection(lambda: decrypt(b'\x01'), (ValueError,)))

    server = server_for(paths, output / 'http.log')
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f'http://127.0.0.1:{server.server_port}'
    opener = build_opener(ProxyHandler({}))
    try:
        def controls():
            for route in ('vulnerable/plain', 'vulnerable/encrypted', 'safe/encrypted'):
                response = opener.open(base + '/' + route + '?id=2', timeout=5)
                body = response.read()
                require(response.status == 200 and b'<td>2</td>' in body, 'Baseline unavailable')
                require(NOTE.encode() not in body and encrypted_payload.hex().encode() not in body,
                        'Hidden row already in baseline response')
            return 'Alle drei Routen erreichbar; Baseline liefert nur Kontrollzeile 2.'
        check('HTTP-Gegenproben vor sqlmap', controls)

        for kind, route, expected in (
            ('plain', 'vulnerable/plain', plain_payload),
            ('encrypted', 'vulnerable/encrypted', encrypted_payload),
            ('safe', 'safe/encrypted', None),
        ):
            def sqlmap_check(kind=kind, route=route, expected=expected):
                folder = output / ('sqlmap-' + kind)
                folder.mkdir()
                command = [sys.executable, str(sqlmap), '-u', base + '/' + route + '?id=2', '-p', 'id',
                           '--dbms=SQLite', '--batch', '--level=1', '--risk=1', '--technique=BU',
                           '--threads=1', '--timeout=5', '--retries=0', '--ignore-proxy', '--ignore-redirects',
                           '--flush-session', '--disable-coloring', '--output-dir=' + str(folder)]
                if expected is not None:
                    command += ['--sql-query=SELECT hex(payload) FROM day_entries WHERE id=1']
                (folder / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
                log_path = folder / 'console.log'
                try:
                    returncode = run_sqlmap(command, log_path, live)
                except subprocess.TimeoutExpired:
                    raise RuntimeError('sqlmap timeout; Ergebnis nicht als Schutz werten')
                text = log_path.read_text()
                evidence = text + '\n' + '\n'.join(p.read_text(errors='replace') for p in folder.rglob('log'))
                detected = 'Parameter: id (GET)' in evidence
                if returncode != 0:
                    raise RuntimeError('sqlmap exited with ' + str(returncode))
                if expected is None:
                    require(not detected, 'Safe endpoint was reported vulnerable')
                    if 'all tested parameters do not appear to be injectable' not in evidence:
                        raise RuntimeError('No conclusive negative result in sqlmap log')
                    return 'Keine Injection im Umfang level=1, risk=1, technique=BU erkannt; kein allgemeiner Sicherheitsbeweis.'
                require(detected, 'No confirmed injection in sqlmap log')
                # Read the actually extracted hex string, not a value supplied to sqlmap.
                candidates = re.findall(r'(?<![0-9a-fA-F])[0-9a-fA-F]{100,}(?![0-9a-fA-F])', evidence)
                recovered = next((bytes.fromhex(value) for value in candidates if len(value) % 2 == 0
                                  and bytes.fromhex(value) == expected), None)
                require(recovered is not None, 'sqlmap did not extract the complete expected row')
                (folder / 'extracted-payload.hex').write_text(recovered.hex() + '\n')
                if kind == 'plain':
                    require(json.loads(recovered)['note'] == NOTE, 'Wrong plaintext fixture')
                    return 'sqlmap extrahiert Zeile 1 im Klartext trotz SQLCipher-Dateiverschlüsselung (Hex ist nur Transportdarstellung).'
                require(NOTE.encode() not in recovered, 'Unexpected plaintext payload')
                require(decrypt(recovered) == clear, 'Extracted payload could not be decrypted with public key')
                (folder / 'decrypted-with-public-debug-key.json').write_text(
                    json.dumps(json.loads(decrypt(recovered)), indent=2, ensure_ascii=False) + '\n')
                return 'sqlmap extrahiert AES-BLOB. Separater Schritt mit öffentlichem Debug-AES-Schlüssel entschlüsselt den Testeintrag.'
            check('sqlmap: ' + route, sqlmap_check)
    finally:
        server.shutdown()
        thread.join(timeout=5)
        server.server_close()
        for db in server.connections.values():
            db.close()

    def unchanged():
        for path in (*paths.values(), copied):
            require(hashlib.sha256(path.read_bytes()).hexdigest() == hashes_before[path.name], 'Database changed')
        return 'SHA-256 aller drei geschlossenen Datenbankdateien unverändert.'
    check('Angriffsversuche verändern keine Datenbankdatei', unchanged)
    failed = [r for r in results if r['status'] != 'PASS']
    report = ['# Versuchsergebnisse', '', f'Durchlauf: `{stamp}` (UTC)', '',
              'PASS bedeutet: Das erwartete Versuchsergebnis ist eingetreten. Es bedeutet nicht, dass die App sicher ist.', '',
              '| Prüfung | Status | Beobachtung |', '| --- | --- | --- |']
    for result in results:
        detail = str(result['detail']).replace('|', '\\|').replace('\n', ' ')
        report.append(f"| {result['test']} | {result['status']} | {detail} |")
    report += ['', f'{len(results) - len(failed)}/{len(results)} Prüfungen entsprechen der Erwartung.', '',
               'Konfiguration: [environment.json](environment.json). Rohdaten: [checks.json](checks.json).',
               'sqlmap-Protokolle: [Klartext](sqlmap-plain/console.log), [AES-Payload](sqlmap-encrypted/console.log), '
               '[parametrisierte Abfrage](sqlmap-safe/console.log).', '',
               'Keine bestehende App-Datenbank wurde gelesen oder verändert. Nur eine lokale Labornachbildung wurde angegriffen.']
    (output / 'bericht.md').write_text('\n'.join(report) + '\n')
    (ROOT / 'results/LATEST.txt').write_text(stamp + '\n')
    print(f'Ergebnis: {len(results) - len(failed)}/{len(results)} PASS; {output / "bericht.md"}', flush=True)
    return 1 if failed else 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live', action='store_true', help='Show sqlmap output live and retain the same log files')
    raise SystemExit(main(live=parser.parse_args().live))
