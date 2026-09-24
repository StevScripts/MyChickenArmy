#!/usr/bin/env python3
"""Verify the ORIGINAL migration snapshot; intentional later source edits cause drift."""
from pathlib import Path
import collections
import hashlib
import json
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'docs/migration/source-manifest.json').read_text())
entries = manifest['scripts']
assert len(entries) == manifest['identity']['scriptCount'] == 327
assert len({entry['file'] for entry in entries}) == len(entries), 'Export filenames collide'
errors = []
for entry in entries:
    path = ROOT / entry['file']
    if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
        errors.append(f"Changed/missing export: {entry['file']}")

def inspect_build(filename):
    root = ET.parse(filename).getroot()
    result = {}
    def visit(item, prefix):
        props = item.find('Properties')
        name = props.find("*[@name='Name']").text
        path = '.'.join([*prefix, name])
        if item.attrib['class'] in ('ModuleScript', 'Script', 'LocalScript'):
            result[path] = (item.attrib['class'], props.find("*[@name='Source']").text or '')
        for child in item.findall('Item'):
            visit(child, [*prefix, name])
    for item in root.findall('Item'):
        visit(item, [])
    return result

def check(project_file, scopes, output):
    project = json.loads((ROOT / project_file).read_text())
    assert project['servePlaceIds'] == [96683186622050], 'Wrong place allowlist'
    def preservation(node):
        assert node.get('$ignoreUnknownInstances') is True, 'Every mapped node must preserve unknown instances'
        for key, value in node.items():
            if not key.startswith('$') and isinstance(value, dict):
                preservation(value)
    preservation(project['tree'])
    assert 'Workspace' not in project['tree'], 'The map must not be owned by this code mapping'
    assert 'StarterGui' not in project['tree'], 'Studio-owned GUI assets must remain unmapped'
    (ROOT / 'build').mkdir(exist_ok=True)
    subprocess.run([sys.executable, 'tools/rojo.py', 'build', project_file, '--output', output], cwd=ROOT, check=True)
    actual = inspect_build(ROOT / output)
    expected = {e['path']:e for e in entries if e['scope'] in scopes}
    if set(actual) != set(expected):
        errors.append(f'{project_file}: instance paths differ: {set(actual) ^ set(expected)}')
    for path, entry in expected.items():
        cls, source = actual.get(path, ('missing', ''))
        if cls != entry['className'] or hashlib.sha256(source.encode()).hexdigest() != entry['sha256']:
            errors.append(f'{project_file}: changed class/source: {path}')
    return len(actual)

counts = {
    'defaultBuiltScripts': check('default.project.json', {'active'}, 'build/MyChickenArmy-ScriptsOnly.rbxlx'),
    'optionalBuiltScripts': check('tests.project.json', {'active', 'test'}, 'build/MyChickenArmy-ScriptsAndTests.rbxlx'),
}
report = {'ok': not errors, 'exportedScripts': len(entries), 'scopes': dict(collections.Counter(e['scope'] for e in entries)), **counts, 'errors': errors, 'scope': 'Source/class preservation and Rojo packaging; not a gameplay test or full-place backup.'}
print(json.dumps(report, indent=2))
sys.exit(0 if report['ok'] else 1)
