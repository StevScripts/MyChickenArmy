"""Cull coincident inward-facing legacy Alien eye box surfaces.

Run after alien_eye_cleanup.py and before export/render. This adjusts only the
Alien material. No textures, geometry, UVs, transforms, or weights are changed.
"""
import bpy
import json
from pathlib import Path

ROOT = Path('/Users/stevin/.codex/artifacts/galaxy-retexture-20261004')
alien = bpy.app.driver_namespace['retexture_models']['alien']
material = alien['base'].data.materials[0]
before = {}
for name, value in (
    ('use_backface_culling', True),
    ('use_backface_culling_shadow', True),
    ('show_transparent_back', False),
):
    if material.bl_rna.properties.get(name) is not None:
        before[name] = getattr(material, name)
        setattr(material, name, value)
report = {'material': material.name, 'before': before,
          'after': {key: getattr(material, key) for key in before}}
(ROOT / 'alien-backface-cleanup.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report))
