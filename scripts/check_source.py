"""Focused configuration / accidental secret checks; no third-party packages."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
for file in root.rglob('*'):
    if not file.is_file() or any(p in {'.git', '.godot', 'build'} for p in file.relative_to(root).parts):
        continue
    content = file.read_text(errors='replace')
    for pattern in (r'gh[pousr]_[A-Za-z0-9]{30,}', r'-----BEGIN (?:RSA |OPENSSH )?PRIVATE KEY-----', r'AKIA[0-9A-Z]{16}'):
        if re.search(pattern, content):
            raise SystemExit(f'Potential secret in {file.relative_to(root)}')
assert 'codesign/enable=false' in (root / 'export_presets.cfg').read_text()
assert '4.6.3' in (root / '.github/workflows/candidate.yml').read_text()
version = re.search(r'config/version="([^"]+)"', (root / 'project.godot').read_text())[1]
assert f'const VERSION = "{version}"' in (root / 'scripts/main.gd').read_text()
assert 'Input.get_joy_axis' in (root / 'scripts/radio_input.gd').read_text()
print('PASS: source/configuration/accidental-secret checks')
