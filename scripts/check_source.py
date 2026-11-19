"""Focused configuration / accidental secret checks; no third-party packages."""
from pathlib import Path
import re
import json
import hashlib

root = Path(__file__).resolve().parents[1]
for file in root.rglob('*'):
    if not file.is_file() or any(p in {'.git', '.godot', 'build'} for p in file.relative_to(root).parts):
        continue
    if file.suffix in ('.ogg', '.wav'):
        continue
    content = file.read_text(errors='replace')
    for pattern in (r'gh[pousr]_[A-Za-z0-9]{30,}', r'-----BEGIN (?:RSA |OPENSSH )?PRIVATE KEY-----', r'AKIA[0-9A-Z]{16}'):
        if re.search(pattern, content):
            raise SystemExit(f'Potential secret in {file.relative_to(root)}')
assert 'codesign/enable=false' in (root / 'export_presets.cfg').read_text()
assert '4.6.3' in (root / '.github/workflows/candidate.yml').read_text()
version = re.search(r'config/version="([^"]+)"', (root / 'project.godot').read_text())[1]
assert f'const VERSION = "{version}"' in (root / 'scripts/main.gd').read_text()
assert f'version/name="{version}"' in (root / 'export_presets.cfg').read_text(), 'Android version must match game version'
assert 'Input.get_joy_axis' in (root / 'scripts/radio_input.gd').read_text()
print('PASS: source/configuration/accidental-secret checks')

# Pinned asset inventory prevents missing/uncredited or silently changed audio in exports.
audio = root / 'assets/audio'
manifest = json.loads((audio / 'manifest.json').read_text())
assert {x['file'] for x in manifest} == {p.name for p in audio.glob('*.ogg')}
for entry in manifest:
    assert Path(entry['file']).name == entry['file']
    content = (audio / entry['file']).read_bytes()
    assert content[:4] == b'OggS' and hashlib.sha256(content).hexdigest() == entry['sha256']
    assert entry['license'] in {'CC0-1.0', 'CC-BY-4.0'}
    assert entry['author'] in (audio / 'CREDITS.txt').read_text()
print('PASS: bundled audio inventory, attribution and source SHA256 checks')

# Original synthesized Focus Suite: Git blob hashes, no external samples.
import wave
focus_blobs = {
    'focus_1.wav': 'dd120dbf5913a76d5043b59952644216aec55447',
    'focus_2.wav': '5fda5be27b6de8a8850ec6954600667cd4b27e05',
    'focus_3.wav': 'd47b0b573a204ad433a0a8fc94c62a32637a2d11',
}
assert {p.name for p in audio.glob('*.wav')} == set(focus_blobs)
for filename, expected in focus_blobs.items():
    payload = (audio / filename).read_bytes()
    blob = hashlib.sha1(b'blob ' + str(len(payload)).encode() + bytes([0]) + payload).hexdigest()
    assert blob == expected, f'Focus soundtrack modified: {filename}'
    with wave.open(str(audio / filename), 'rb') as wav:
        assert wav.getnchannels() == 1 and wav.getframerate() == 12000
        assert wav.getsampwidth() == 2 and wav.getnframes() == 288000
print('PASS: original focus music pinned and valid PCM WAV')

