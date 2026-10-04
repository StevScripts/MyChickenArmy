"""Run in the current Blender session: suppress redundant Alien eye overlays.

The Head shader already paints both eyes. The separate legacy eye/glint boxes
are preserved geometrically but receive zero opacity, avoiding overlapping
surfaces at the head plane. Only Alien is rebaked; root owns export and preview.
"""
import importlib.util
import json
from pathlib import Path

import bpy
import numpy as np

ROOT = Path('/Users/stevin/.codex/artifacts/galaxy-retexture-20261004')


def load_module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


atlas = load_module('alien_cleanup_atlas', 'atlas_tools.py')
design = load_module('alien_cleanup_design', 'material_design.py')
alien = bpy.app.driver_namespace['retexture_models']['alien']


def clean_eye_shade(ident, style, positions, uv, normal, label):
    result = design.shade(ident, style, positions, uv, normal, label)
    if ident == 'alien' and label in ('Eye', 'Glint'):
        color, roughness, metalness, emission, height, alpha = result
        return color, roughness, metalness, emission, height, np.zeros_like(alpha)
    return result


alien['restrict_alpha'] = True
result = atlas.bake_existing(alien, clean_eye_shade, ROOT)
report = {key: result[key] for key in (
    'before', 'after', 'tile_count', 'triangle_fallback_count',
    'degenerate_uv_count', 'alpha_restricted', 'alpha_preserved',
)}
report.update(id='alien', eye_treatment='Head-painted eyes; transparent legacy Eye/Glint overlays',
              paths=result['paths'])
(ROOT / 'alien-eye-cleanup-validation.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report))
