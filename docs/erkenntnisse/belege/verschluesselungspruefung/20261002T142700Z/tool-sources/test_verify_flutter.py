"""Failure-path checks against a copy of actual, successfully exported Flutter evidence."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent


class VerifierFailureTests(unittest.TestCase):
    evidence = None

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.copy = self.root / 'evidence'
        shutil.copytree(self.evidence, self.copy)

    def run_verifier(self):
        result = subprocess.run([sys.executable, str(ROOT / 'verify_flutter.py'),
                                 '--evidence', str(self.copy), '--output', str(self.root / 'report')],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        checks = json.loads((self.root / 'report/checks.json').read_text())
        for check in checks:
            if 'key rejected' in check['test'] or check['test'] == 'Ordinary SQLite cannot query database':
                self.assertEqual(check['status'], 'NOT_TESTED', checks)
        return checks

    def test_missing_database_is_not_protection(self):
        (self.copy / 'closed-flutter.db').unlink()
        checks = self.run_verifier()
        self.assertEqual(checks[0]['status'], 'FAIL')

    def test_corrupt_database_is_not_protection(self):
        path = self.copy / 'closed-flutter.db'
        path.write_bytes(bytes(path.stat().st_size))
        checks = self.run_verifier()
        self.assertEqual(checks[1]['status'], 'NOT_TESTED')

    def test_wrong_fixture_is_not_a_successful_decryption(self):
        path = self.copy / 'manifest.json'
        manifest = json.loads(path.read_text())
        manifest['expected_snapshot']['days'][0]['note'] = 'ERFUNDEN-WRONG-EXPECTED-NOTE'
        path.write_text(json.dumps(manifest))
        checks = self.run_verifier()
        self.assertEqual(checks[1]['status'], 'FAIL')

    def test_collector_rejects_aborted_flutter_run(self):
        log = self.root / 'aborted.txt'
        log.write_text('REGELMAESSIG_EVIDENCE_PATH=' + str(self.copy) + '\n')
        result = subprocess.run([sys.executable, str(ROOT / 'collect_flutter.py'),
                                 '--log', str(log), '--output', str(self.root / 'collected')],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Flutter success marker missing', result.stderr)
        self.assertFalse((self.root / 'collected').exists())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args()
    VerifierFailureTests.evidence = args.evidence.resolve()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(VerifierFailureTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)
