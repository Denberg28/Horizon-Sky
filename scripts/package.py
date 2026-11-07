"""Package an exported Windows binary, data and operator documentation."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--commit', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
version = re.search(r'config/version="([^"]+)"', (root / 'project.godot').read_text())[1]
exe, pck = root / 'build/HorizonSky.exe', root / 'build/HorizonSky.pck'
assert exe.stat().st_size > 1000000 and pck.stat().st_size > 1000
with exe.open('rb') as file:
    assert file.read(2) == b'MZ', 'Not a Windows PE executable'
    file.seek(0x3C)
    pe = struct.unpack('<I', file.read(4))[0]
    file.seek(pe)
    assert file.read(4) == b'PE\0\0'
    assert struct.unpack('<H', file.read(2))[0] == 0x8664, 'Expected x86_64'
info = {'version': version, 'commit': args.commit, 'engine': 'Godot 4.6.3 stable', 'platform': 'Windows x86_64', 'tier': 'TEST CANDIDATE', 'hardware_validation': 'BLOCKED — no physical USB radio available', 'signing': 'unsigned'}
artifact = root / f'build/HorizonSky-{version}-windows-x86_64.zip'
with zipfile.ZipFile(artifact, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in [exe, pck, root / 'README.md', root / 'CHANGELOG.md', root / 'LICENSE', root / 'THIRD_PARTY_NOTICES.md']:
        archive.write(path, path.name)
    for path in (root / 'docs').glob('*.md'):
        archive.write(path, f'docs/{path.name}')
    archive.write(root / 'scripts/windows_hil.ps1', 'scripts/windows_hil.ps1')
    archive.writestr('BUILD_INFO.json', json.dumps(info, indent=2))
    checksums = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [exe, pck]}
    archive.writestr('FILE_SHA256.json', json.dumps(checksums, indent=2))
with artifact.open('rb') as stream:
    checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
(root / 'build/SHA256SUMS.txt').write_text(f'{checksum}  {artifact.name}\n')
with zipfile.ZipFile(artifact) as archive:
    assert archive.testzip() is None
    assert archive.read('HorizonSky.exe')[:2] == b'MZ'
print(f'PASS: packaged and verified {artifact.name} SHA256 {checksum}')
