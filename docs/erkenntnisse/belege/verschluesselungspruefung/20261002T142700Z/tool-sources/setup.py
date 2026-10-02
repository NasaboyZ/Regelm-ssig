"""Install isolated lab dependencies on macOS; never change the Flutter project."""
import hashlib
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import venv

ROOT = Path(__file__).resolve().parent
VENDOR = ROOT / 'vendor'
APP = ROOT.parent / 'regelmaessig'


def run(*args):
    subprocess.run([str(a) for a in args], check=True, cwd=ROOT)


def copy_vendor_source(source, destination):
    # CocoaPods sources can be read-only. Replace our copy instead of opening
    # the previous read-only file for writing when setup runs a second time.
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as tmp:
        temporary = Path(tmp.name)
    try:
        shutil.copyfile(source, temporary)
        temporary.chmod(0o644)
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    if sys.platform != 'darwin':
        raise SystemExit('This build recipe uses macOS CommonCrypto and Xcode command line tools.')
    VENDOR.mkdir(exist_ok=True)
    source = APP / 'macos/Pods/SQLCipher'
    if not (source / 'sqlite3.c').exists():
        raise SystemExit('Expected existing SQLCipher sources in ../regelmaessig/macos/Pods/SQLCipher')
    copied = VENDOR / 'SQLCipher'
    copied.mkdir(exist_ok=True)
    for name in ('sqlite3.c', 'sqlite3.h'):
        copy_vendor_source(source / name, copied / name)
    for path in source.glob('*'):
        if path.is_file() and ('license' in path.name.lower() or 'copyright' in path.name.lower()):
            copy_vendor_source(path, copied / path.name)
    flags = ['-dynamiclib', '-O2', '-DSQLITE_HAS_CODEC', '-DSQLITE_TEMP_STORE=2',
             '-DSQLITE_THREADSAFE=1', '-DSQLCIPHER_CRYPTO_CC',
             '-DSQLITE_EXTRA_INIT=sqlcipher_extra_init',
             '-DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown']
    run('clang', *flags, copied / 'sqlite3.c', '-framework', 'Security', '-framework', 'CoreFoundation',
        '-o', VENDOR / 'libsqlcipher.dylib')
    checkout = VENDOR / 'sqlmap'
    lock_path = ROOT / 'sqlmap.lock'
    if not checkout.exists():
        run('git', 'clone', 'https://github.com/sqlmapproject/sqlmap.git', checkout)
    if lock_path.exists():
        commit = lock_path.read_text().strip()
        run('git', '-C', checkout, 'checkout', '--detach', commit)
    else:
        commit = subprocess.check_output(['git', '-C', str(checkout), 'rev-parse', 'HEAD'], text=True).strip()
        lock_path.write_text(commit + '\n')
    venv.EnvBuilder(with_pip=True).create(ROOT / '.venv')
    python = ROOT / '.venv/bin/python'
    requirements = ROOT / 'requirements.lock'
    run(python, '-m', 'pip', 'install', '-r', requirements)
    requirements.write_text(subprocess.check_output([str(python), '-m', 'pip', 'freeze'], text=True))
    manifest = {
        'platform': platform.platform(), 'python': sys.version, 'sqlmap_commit': commit,
        'sqlcipher_source_sha256': hashlib.sha256((copied / 'sqlite3.c').read_bytes()).hexdigest(),
        'build_flags': flags, 'source': str(source),
    }
    (VENDOR / 'build.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Bereit: .venv/bin/python run.py')


if __name__ == '__main__':
    main()
