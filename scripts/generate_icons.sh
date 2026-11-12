#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ModuleCache App/Assets.xcassets/AppIcon.appiconset
xcrun swiftc -module-cache-path build/ModuleCache scripts/generate_icon.swift -o build/generate-icon
build/generate-icon build/AppIcon-1024.png
python3 - <<'PY'
import json, pathlib, subprocess
folder = pathlib.Path('App/Assets.xcassets/AppIcon.appiconset')
images = []
for size in [16, 32, 128, 256, 512]:
    for scale in [1, 2]:
        pixels = size * scale
        name = f'icon_{size}_{scale}x.png'
        subprocess.run(['sips', '-z', str(pixels), str(pixels), 'build/AppIcon-1024.png', '--out', str(folder / name)], check=True, stdout=subprocess.DEVNULL)
        images.append({'idiom': 'mac', 'size': f'{size}x{size}', 'scale': f'{scale}x', 'filename': name})
(folder / 'Contents.json').write_text(json.dumps({'images': images, 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
pathlib.Path('App/Assets.xcassets/Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
PY
