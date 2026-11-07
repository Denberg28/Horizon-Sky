"""Verify official release downloads against the vendor SHA512 manifest."""
import hashlib
from pathlib import Path
import sys

manifest = Path(sys.argv[1]).read_text()
for i in range(2, len(sys.argv), 2):
    local, vendor_name = sys.argv[i:i + 2]
    matching = [line.split()[0] for line in manifest.splitlines() if line.split() and line.split()[-1].lstrip('*') == vendor_name]
    if len(matching) != 1:
        raise SystemExit(f'Missing or ambiguous vendor checksum: {vendor_name}')
    with open(local, 'rb') as stream:
        actual = hashlib.file_digest(stream, 'sha512').hexdigest()
    if actual != matching[0]:
        raise SystemExit(f'Checksum mismatch: {vendor_name}')
    print(f'PASS: vendor checksum {vendor_name}')
