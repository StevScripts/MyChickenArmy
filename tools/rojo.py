#!/usr/bin/env python3
"""Run the pinned, project-local Rojo CLI. No global PATH changes required."""
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def executable():
    release = json.loads((ROOT / 'tools/rojo-release.json').read_text())
    systems = {'Darwin': 'macos', 'Linux': 'linux', 'Windows': 'windows'}
    machine = platform.machine().lower()
    arch = 'aarch64' if machine in ('arm64', 'aarch64') else 'x86_64' if machine in ('amd64', 'x86_64') else None
    system = systems.get(platform.system())
    if not system or not arch:
        raise RuntimeError(f'Unsupported platform: {platform.system()} {machine}')
    name = 'rojo.exe' if system == 'windows' else 'rojo'
    target = ROOT / '.tools' / name
    version = release['version']
    if target.exists():
        result = subprocess.run([str(target), '--version'], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip() == f'Rojo {version}':
            return target
        raise RuntimeError(f'{target} does not match pinned Rojo {version}; move it aside before reinstalling.')
    asset = release['assets'][f'rojo-{version}-{system}-{arch}.zip']
    print(f'Downloading Rojo {version} from its official release...', flush=True)
    with urllib.request.urlopen(asset['url'], timeout=60) as response:
        data = response.read()
    assert asset['digest'] == 'sha256:' + hashlib.sha256(data).hexdigest(), 'Rojo release checksum mismatch'
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        member = next(p for p in archive.namelist() if Path(p).name == name)
        binary = archive.read(member)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix('.download')
    temporary.write_bytes(binary)
    temporary.chmod(0o755)
    temporary.replace(target)
    return target

def main():
    args = sys.argv[1:]
    if not args:
        print('Usage: python3 tools/rojo.py serve | build | sourcemap | setup | <Rojo arguments>')
        return 0
    binary = executable()
    if args == ['setup']:
        print(f'Ready: {binary}')
        return 0
    if args == ['serve']:
        args += ['default.project.json']
    elif args == ['build']:
        (ROOT / 'build').mkdir(exist_ok=True)
        args += ['default.project.json', '--output', 'build/MyChickenArmy-ScriptsOnly.rbxlx']
    elif args == ['sourcemap']:
        args += ['default.project.json', '--output', 'sourcemap.json']
    os.chdir(ROOT)
    if os.name != 'nt':
        os.execv(str(binary), [str(binary), *args])
    return subprocess.call([str(binary), *args])

if __name__ == '__main__':
    sys.exit(main())
