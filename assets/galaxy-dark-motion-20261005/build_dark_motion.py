"""Run in Blender after opening the approved Galaxy-Reference-Matched.blend.

This uses Blender's renderer to author the atlas. It never reads or writes image
pixels in Python. Only the new export objects' UV coordinates are changed.
The original review objects, original images, geometry and skin weights remain.
"""

import bpy
import hashlib
import importlib.util
import json
import math
import struct
from pathlib import Path

ROOT = Path('/Users/stevin/.codex/artifacts/galaxy-dark-motion-20261005')
SOURCE = Path('/Users/stevin/.codex/artifacts/galaxy-retexture-v2-20261004')
MANIFEST = Path('/Users/stevin/.codex/artifacts/galaxy-retexture-20261004/source-manifest.json')
PLASMA = Path('/Users/stevin/.codex/artifacts/galaxy-reference-textures/generated-textures/plasma.png')
SIZE = 2048
ROOT.mkdir(parents=True, exist_ok=True)
(ROOT / 'exports').mkdir(exist_ok=True)


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


atlas = load_module('dark_motion_atlas_tools', SOURCE / 'atlas_tools.py')
models = atlas.reconstruct(str(MANIFEST))
c = models['dark-matter']
original_signature = atlas.geometry_signature(c)
assert len(c['rig'].data.bones) == 18
original_scene = bpy.context.window.scene


def select_enum(owner, key, values):
    """Check RNA when it lists identifiers; dynamic enum sets need assignment."""
    prop = owner.bl_rna.properties.get(key)
    identifiers = {v.identifier for v in prop.enum_items} if prop and prop.type == 'ENUM' else set()
    # Dynamically registered render engines and OCIO transforms can be absent
    # from enum_items even though the current Blender process accepts them.
    for value in values:
        try:
            setattr(owner, key, value)
            return value
        except (TypeError, ValueError):
            pass
    raise RuntimeError(f'No supported {key}: {values}; RNA={sorted(identifiers)}')


def socket(node, kind, name):
    coll = getattr(node, kind)
    return next((s for s in coll if s.identifier == name), None) or coll.get(name)


def srgb(v):
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4


def math_node(nodes, links, operation, a, b=None):
    node = nodes.new('ShaderNodeMath')
    select_enum(node, 'operation', (operation,))
    for value, inp in ((a, node.inputs[0]), (b, node.inputs[1])):
        if value is None:
            continue
        if isinstance(value, (int, float)):
            inp.default_value = value
        else:
            links.new(value, inp)
    return node.outputs[0]


def combine(nodes, links, x, y, z=0):
    node = nodes.new('ShaderNodeCombineXYZ')
    for value, inp in zip((x, y, z), node.inputs):
        if isinstance(value, (int, float)):
            inp.default_value = value
        else:
            links.new(value, inp)
    return node.outputs[0]


def tex(nodes, links, image, vector):
    node = nodes.new('ShaderNodeTexImage')
    node.image = image
    select_enum(node, 'extension', ('EXTEND',))
    select_enum(node, 'interpolation', ('Linear',))
    links.new(vector, socket(node, 'inputs', 'Vector'))
    return node


def mix_value(nodes, links, a, b, factor):
    # ShaderNodeMixRGB consistently handles vector, float and constant colors.
    node = nodes.new('ShaderNodeMixRGB')
    select_enum(node, 'blend_type', ('MIX',))
    links.new(factor, node.inputs[0])
    for value, inp in ((a, node.inputs[1]), (b, node.inputs[2])):
        if isinstance(value, (int, float)):
            inp.default_value = (value, value, value, 1)
        elif isinstance(value, tuple):
            inp.default_value = value
        else:
            links.new(value, inp)
    return node.outputs[0]


# An orthographic emission-only render is a native lossless layout operation:
# original static atlas in the bottom half, two identical mirrored plasma tiles
# in the top half. Film transparency preserves eye cutouts and unused pixels.
sc = bpy.data.scenes.new('DARK MOTION | Atlas renderer')
bpy.context.window.scene = sc
select_enum(sc.render, 'engine', ('CYCLES',))
sc.cycles.samples = 1
sc.cycles.use_denoising = False
sc.render.resolution_x = sc.render.resolution_y = SIZE
sc.render.resolution_percentage = 100
sc.render.film_transparent = True
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
sc.render.image_settings.color_depth = '8'
sc.render.image_settings.compression = 15
sc.view_settings.exposure = 0
sc.view_settings.gamma = 1
select_enum(sc.display_settings, 'display_device', ('sRGB',))
select_enum(sc.view_settings, 'look', ('None',))
world = bpy.data.worlds.new('Dark motion atlas black world')
world.use_nodes = True
for node in world.node_tree.nodes:
    if node.bl_idname == 'ShaderNodeBackground':
        socket(node, 'inputs', 'Strength').default_value = 0
sc.world = world
camera_data = bpy.data.cameras.new('Dark motion atlas orthographic')
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 2
camera = bpy.data.objects.new('Dark motion atlas camera', camera_data)
sc.collection.objects.link(camera)
camera.location = (0, 0, 3)
sc.camera = camera
plane_mesh = bpy.data.meshes.new('Dark motion atlas render plane')
plane_mesh.from_pydata([(-1,-1,0),(1,-1,0),(1,1,0),(-1,1,0)], [], [(0,1,2,3)])
uv = plane_mesh.uv_layers.new(name='UVMap')
for loop, value in zip(uv.data, [(0,0),(1,0),(1,1),(0,1)]):
    loop.uv = value
plane = bpy.data.objects.new('Dark motion atlas render plane', plane_mesh)
sc.collection.objects.link(plane)
layout_material = bpy.data.materials.new('Dark motion native atlas layout')
layout_material.use_nodes = True
plane.data.materials.append(layout_material)
plasma_image = bpy.data.images.load(str(PLASMA), check_existing=False)
plasma_image.colorspace_settings.name = 'sRGB'
plasma_image.pack()
images = {}


def render_atlas(key):
    nodes, links = layout_material.node_tree.nodes, layout_material.node_tree.links
    nodes.clear()
    uvn = nodes.new('ShaderNodeTexCoord')
    split = nodes.new('ShaderNodeSeparateXYZ')
    links.new(socket(uvn, 'outputs', 'UV'), split.inputs[0])
    u, v = split.outputs['X'], split.outputs['Y']
    upper = math_node(nodes, links, 'GREATER_THAN', v, .5)
    static_vector = combine(nodes, links, u, math_node(nodes, links, 'MULTIPLY', v, 2))
    # Ping-pong creates a continuous, horizontally mirrored tile with period .5.
    # This removes both the source seam and the 8-second runtime wrap seam.
    phase = math_node(nodes, links, 'MULTIPLY', u, 4)
    mirrored = math_node(nodes, links, 'PINGPONG', phase, 1)
    pv = math_node(nodes, links, 'SUBTRACT', math_node(nodes, links, 'MULTIPLY', v, 2), 1)
    plasma_node = tex(nodes, links, plasma_image, combine(nodes, links, mirrored, pv))
    rgb = nodes.new('ShaderNodeSeparateColor')
    select_enum(rgb, 'mode', ('RGB',))
    links.new(plasma_node.outputs['Color'], rgb.inputs['Color'])
    channels = []
    for index, channel in enumerate(('Red','Green','Blue')):
        value = math_node(nodes, links, 'POWER', rgb.outputs[channel], 1.15)
        if index == 1:
            value = math_node(nodes, links, 'MULTIPLY', value, .72)
        value = math_node(nodes, links, 'MAXIMUM', value, srgb((44,7,91)[index] / 255))
        channels.append(value)
    plasma_color = combine(nodes, links, *channels)
    hot = math_node(nodes, links, 'SUBTRACT', channels[0], .20)
    hot = math_node(nodes, links, 'DIVIDE', hot, .50)
    hot = math_node(nodes, links, 'MAXIMUM', hot, 0)
    hot = math_node(nodes, links, 'MINIMUM', hot, 1)
    rough = math_node(nodes, links, 'SUBTRACT', .32, math_node(nodes, links, 'MULTIPLY', hot, .10))
    if key == 'ColorMap':
        top = plasma_color
    elif key == 'EmissionColor':
        strength = math_node(nodes, links, 'ADD', .035, math_node(nodes, links, 'MULTIPLY', hot, 1.12))
        top = combine(nodes, links, *[math_node(nodes, links, 'MULTIPLY', channel, strength) for channel in channels])
    elif key == 'NormalMap':
        top = (.5,.5,1,1)
    elif key == 'RoughnessMap':
        top = rough
    elif key == 'MetalnessMap':
        top = .03
    elif key == 'ORM':
        top = combine(nodes, links, 1, rough, .03)
    else:
        raise ValueError(key)
    source_image = c['images'].get(key)
    if source_image is None:
        source_image = bpy.data.images.load(str(SOURCE / ('dark-matter_' + key + '.png')), check_existing=False)
        source_image.colorspace_settings.name = 'sRGB' if key in ('ColorMap','EmissionColor') else 'Non-Color'
    static = tex(nodes, links, source_image, static_vector)
    color = mix_value(nodes, links, static.outputs['Color'], top, upper)
    alpha = mix_value(nodes, links, static.outputs['Alpha'], 1, upper) if key == 'ColorMap' else 1
    emission = nodes.new('ShaderNodeEmission')
    links.new(color, emission.inputs['Color'])
    emission.inputs['Strength'].default_value = 1
    output = nodes.new('ShaderNodeOutputMaterial')
    if key == 'ColorMap':
        transparent = nodes.new('ShaderNodeBsdfTransparent')
        mix = nodes.new('ShaderNodeMixShader')
        links.new(alpha, mix.inputs[0])
        links.new(transparent.outputs[0], mix.inputs[1])
        links.new(emission.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], output.inputs['Surface'])
    else:
        links.new(emission.outputs[0], output.inputs['Surface'])
    select_enum(sc.view_settings, 'view_transform', ('Standard',) if key in ('ColorMap','EmissionColor') else ('Raw',))
    path = ROOT / ('dark-matter_' + key + '.png')
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(str(path), check_existing=False)
    image.name = 'Dark Matter Motion 20261005 | ' + key
    image.colorspace_settings.name = 'sRGB' if key in ('ColorMap','EmissionColor') else 'Non-Color'
    image.pack()
    images[key] = image
    print('Rendered dark motion atlas: ' + key, flush=True)


for key in ('ColorMap','NormalMap','RoughnessMap','MetalnessMap','ORM','EmissionColor'):
    render_atlas(key)


material = bpy.data.materials.new('Dark Matter | Flowing plasma and static details')
material.use_nodes = True
material.use_backface_culling = True
select_enum(material, 'surface_render_method', ('DITHERED',))
nodes, links = material.node_tree.nodes, material.node_tree.links
nodes.clear()
shader = nodes.new('ShaderNodeBsdfPrincipled')
output = nodes.new('ShaderNodeOutputMaterial')
links.new(shader.outputs['BSDF'], output.inputs['Surface'])
shader.inputs['Emission Strength'].default_value = 2.2
texture_nodes = {}
for i, key in enumerate(('ColorMap','NormalMap','ORM','EmissionColor')):
    node = nodes.new('ShaderNodeTexImage')
    node.image = images[key]
    node.label = key
    node.location = (-600, 350 - i * 250)
    texture_nodes[key] = node
links.new(texture_nodes['ColorMap'].outputs['Color'], shader.inputs['Base Color'])
links.new(texture_nodes['ColorMap'].outputs['Alpha'], shader.inputs['Alpha'])
links.new(texture_nodes['EmissionColor'].outputs['Color'], shader.inputs['Emission Color'])
split = nodes.new('ShaderNodeSeparateColor')
select_enum(split, 'mode', ('RGB',))
links.new(texture_nodes['ORM'].outputs['Color'], split.inputs['Color'])
links.new(split.outputs['Green'], shader.inputs['Roughness'])
links.new(split.outputs['Blue'], shader.inputs['Metallic'])
normal = nodes.new('ShaderNodeNormalMap')
normal.inputs['Strength'].default_value = .4
links.new(texture_nodes['NormalMap'].outputs['Color'], normal.inputs['Color'])
links.new(normal.outputs['Normal'], shader.inputs['Normal'])


# The approved source objects are untouched. Export copies keep their transforms,
# vertex positions, modifiers, vertex groups and bone data.
export_scene = bpy.data.scenes.new('DARK MOTION | Runtime export')
bpy.context.window.scene = export_scene
collection = bpy.data.collections.new('Dark Matter runtime export')
export_scene.collection.children.link(collection)
rig = c['rig'].copy()
rig.data = c['rig'].data.copy()
rig.animation_data_clear()
rig.name = 'DarkMatter_Flow_Rig'
collection.objects.link(rig)
parts = []
moving_loops = 0
protected_loops = 0
for source in c['parts']:
    ob = source.copy()
    ob.data = source.data.copy()
    collection.objects.link(ob)
    ob.parent = rig
    assert len(ob.data.uv_layers) == 1
    layer = ob.data.uv_layers[0]
    layer.name = 'UVMap'
    for polygon in ob.data.polygons:
        moving = source == c['base'] and polygon.vertices[0] < 72
        for loop_index in polygon.loop_indices:
            item = layer.data[loop_index]
            if moving:
                vertex = ob.data.vertices[ob.data.loops[loop_index].vertex_index].co
                x, y, z = vertex
                # Prior continuous oblique projection, shared by all six faces.
                pu = .5 + .19 * (.70710678*x - .70710678*y)
                pv = .5 + .19 * (.40824829*x + .40824829*y + .81649658*(z-2.3))
                assert .002 < pu < .998 and .002 < pv < .998, (source.name, tuple(vertex), pu, pv)
                item.uv = (.5*pu, .5 + .5*pv)
                moving_loops += 1
            else:
                item.uv = (item.uv.x, item.uv.y*.5)
                protected_loops += 1
    ob.data.materials.clear()
    ob.data.materials.append(material)
    for mod in ob.modifiers:
        if mod.type == 'ARMATURE':
            mod.object = rig
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    for mod in list(ob.modifiers):
        if mod.type in ('BEVEL','SOLIDIFY'):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    parts.append(ob)
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
if len(parts) > 1:
    bpy.ops.object.join()
body = bpy.context.object
body.name = 'Body'
body.data.name = 'DarkMatter_Flow_Body'
rig.scale = (.6701631701631702,)*3
rig['GalaxyTextureMotion'] = 'DarkMatter'
body['GalaxyTextureAtlasVersion'] = 1
bpy.context.view_layer.update()
assert len(body.data.vertices) == 672, len(body.data.vertices)
assert len(rig.data.bones) == 18
assert original_signature == atlas.geometry_signature(c), 'Approved source was modified'
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
glb_path = ROOT / 'exports' / 'dark-matter-flow.glb'
bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format='GLB', use_selection=True,
    use_active_scene=True, export_apply=False, export_materials='EXPORT', export_image_format='AUTO',
    export_texcoords=True, export_normals=True, export_skins=True, export_animations=False,
    export_cameras=False, export_lights=False, export_yup=True,
    export_draco_mesh_compression_enable=False, export_extras=True)


# Inspect the actual glTF UV accessor (the exporter flips V). This is the
# contract the Roblox UV animator sees, not an assumption from Blender's UVs.
raw = glb_path.read_bytes()
offset = 12
chunks = {}
while offset < len(raw):
    length, kind = struct.unpack_from('<II', raw, offset)
    offset += 8
    chunks[kind] = raw[offset:offset+length]
    offset += length
doc = json.loads(chunks[0x4E4F534A].decode('utf8').rstrip('\0 '))
binary = chunks[0x004E4942]
moving_uvs = []
static_uvs = []
for mesh in doc['meshes']:
    for primitive in mesh['primitives']:
        accessor = doc['accessors'][primitive['attributes']['TEXCOORD_0']]
        view = doc['bufferViews'][accessor['bufferView']]
        assert accessor['componentType'] == 5126 and accessor['type'] == 'VEC2'
        base = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        stride = view.get('byteStride', 8)
        for i in range(accessor['count']):
            uv = struct.unpack_from('<2f', binary, base+i*stride)
            (moving_uvs if uv[1] < .5 else static_uvs).append(uv)
assert moving_uvs and static_uvs
assert all(0 < u < .5 and 0 < v < .5 for u,v in moving_uvs)
assert all(v >= .5 for u,v in static_uvs)
assert all(len(skin['joints']) == 18 for skin in doc['skins'])
report = {
    'glb': str(glb_path), 'blend': str(ROOT / 'Galaxy-Dark-Matter-Motion.blend'),
    'vertices': len(body.data.vertices), 'bones': len(rig.data.bones),
    'source_unchanged': original_signature == atlas.geometry_signature(c),
    'source_signature': original_signature, 'moving_authoring_loops': moving_loops,
    'protected_authoring_loops': protected_loops, 'moving_gltf_uvs': len(moving_uvs),
    'protected_gltf_uvs': len(static_uvs),
    'moving_uv_bounds': [[min(x[i] for x in moving_uvs), max(x[i] for x in moving_uvs)] for i in (0,1)],
    'static_min_v': min(v for u,v in static_uvs), 'atlas_size': [SIZE,SIZE],
    'runtime': {'model_attribute': {'GalaxyTextureMotion': 'DarkMatter'}, 'mesh_name': 'Body',
        'animated_region': 'UV V < 0.5; initial U,V strictly within 0..0.5',
        'protected_region': 'UV V >= 0.5', 'offset_u': [0,.5], 'period_seconds': 8,
        'loop': 'Linear TweenService repeat; identical mirrored tiles; no reset seam'},
    'maps': {key: str(ROOT / ('dark-matter_' + key + '.png')) for key in images},
    'notes': ['All geometry and 18 bones preserved.',
        'Body, Neck, Head flow; eyes, beak, comb, feet and feather wings remain fixed.',
        'Atlas authored with native Blender emission renders, not Python pixel editing.']
}
(ROOT / 'motion-export-report.json').write_text(json.dumps(report, indent=2))
# Leave the native file on its dedicated export scene, with imported model selected.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'Galaxy-Dark-Matter-Motion.blend'))
print(json.dumps(report, indent=2), flush=True)
