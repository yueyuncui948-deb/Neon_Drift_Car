#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p docs/play
godot --headless --editor --path . --import
godot --headless --path . --export-release Web docs/play/index.html
godot --headless --path . --script tools/write_licenses.gd
python3 - <<'PY'
from pathlib import Path
import hashlib,json
root=Path('docs/play')
html=root/'index.html'
html.write_text(html.read_text().rstrip()+'\n')
required=['index.html','index.js','index.wasm','index.pck']
for name in required:
    assert (root/name).stat().st_size>0, f'Missing export: {name}'
files={p.name: {'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
       for p in sorted(root.iterdir()) if p.is_file() and p.name!='build-manifest.json'}
(root/'build-manifest.json').write_text(json.dumps({'godot':'4.6.3.stable','renderer':'gl_compatibility','threads':False,'files':files},indent=2)+'\n')
print('Web export verified:',len(files),'files')
PY
