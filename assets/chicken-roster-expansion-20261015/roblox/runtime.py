"""Roblox runtime export: one rigid-skinned mesh + one texture per chicken, prefixed bones.
Same route as the September 27 approved-eight import (one skin, `<ID>_` bone names, no clips;
the game reuses the master clips through src/animations aliases).
Exec after lib.py: RUNTIME(cid) -> dict. Writes runtime/<ID>.glb and runtime/<ID>.png.
"""
import bpy, bmesh, json, struct, zlib
from pathlib import Path
from mathutils import Matrix

RT = OUT / 'runtime'
RT.mkdir(exist_ok=True)

def _read_png_rgba(path):
    img = bpy.data.images.load(str(path), check_existing=False)
    w, h = img.size; px = list(img.pixels); bpy.data.images.remove(img)
    return w, h, px  # float RGBA, bottom-up

def _srgb_byte(lin):
    v = 12.92 * lin if lin <= .0031308 else 1.055 * max(0, lin) ** (1 / 2.4) - .055
    return max(0, min(255, round(v * 255)))

def RUNTIME(cid):
    src_rig = bpy.data.objects[f'Roster_{cid}_Rig']; src_skin = bpy.data.objects[f'Roster_{cid}_Skin']
    src_props = bpy.data.objects.get(f'Roster_{cid}_Props')
    name = 'RT_' + cid
    old = bpy.data.scenes.get(name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new(name); bpy.context.window.scene = scene
    rig = src_rig.copy(); rig.data = src_rig.data.copy(); rig.name = f'{cid}_Rig'; scene.collection.objects.link(rig)
    rig.animation_data_clear(); rig.matrix_world = Matrix.Identity(4); rig.data.pose_position = 'REST'
    for b in rig.data.bones:
        b.name = f'{cid}_{b.name}'
    # Atlas: the painted skin texture, plus each prop material as a solid cell in the unused upper cells.
    w, h, px = _read_png_rgba(OUT / 'textures' / f'{cid}-base-color.png')
    res = w; cell = res // 16
    rgba = bytearray(res * res * 4)
    for y in range(res):
        for x in range(res):
            i = ((y * res) + x) * 4
            rgba[i:i + 4] = bytes(max(0, min(255, round(c * 255))) if k < 3 else 255 for k, c in enumerate(px[i:i + 4]))  # 8-bit PNG pixels are stored sRGB
    objs = []
    skin = src_skin.copy(); skin.data = src_skin.data.copy(); scene.collection.objects.link(skin); objs.append(skin)
    prop_cells = {}
    if src_props:
        props = src_props.copy(); props.data = src_props.data.copy(); scene.collection.objects.link(props); objs.append(props)
        first_free = len(src_skin.data.polygons)  # skin uses cells 0..125
        for mi, mat in enumerate(props.data.materials):
            p = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            col = [_srgb_byte(c) for c in p.inputs['Base Color'].default_value[:3]]
            idx = first_free + mi; cx, cy = idx % 16 * cell, idx // 16 * cell
            for yy in range(cy, cy + cell):
                for xx in range(cx, cx + cell):
                    j = (yy * res + xx) * 4; rgba[j:j + 4] = bytes(col + [255])
            prop_cells[mi] = ((cx + cell / 2) / res, (cy + cell / 2) / res)
        uv = props.data.uv_layers.active
        uv.name = skin.data.uv_layers.active.name  # join merges UV layers by name
        for poly in props.data.polygons:
            u, v = prop_cells[poly.material_index]
            for k, li in enumerate(poly.loop_indices):
                uv.data[li].uv = (u + (.006 if k % 2 else -.006), v + (.006 if k // 2 % 2 else -.006))
    for o in objs:
        o.parent = rig; o.matrix_parent_inverse = Matrix.Identity(4); o.matrix_world = Matrix.Identity(4)
        for vg in o.vertex_groups:
            if not vg.name.startswith(cid + '_'):
                vg.name = f'{cid}_{vg.name}'
        for m in list(o.modifiers):
            o.modifiers.remove(m)
    # Join into one mesh.
    for o in scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs, selected_objects=objs):
        bpy.ops.object.join()
    body = objs[0]; body.name = f'{cid}_Body'; body.data.name = f'{cid}_Body'
    png_path = RT / f'{cid}.png'
    _write_png(png_path, res, rgba)
    mat = bpy.data.materials.new(f'{cid}_Runtime'); mat.use_nodes = True
    p = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'); p.inputs['Roughness'].default_value = .5
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(str(png_path), check_existing=False)
    tex.interpolation = 'Closest'; mat.node_tree.links.new(tex.outputs['Color'], p.inputs['Base Color'])
    body.data.materials.clear(); body.data.materials.append(mat)
    for poly in body.data.polygons:
        poly.material_index = 0
    bm = bmesh.new(); bm.from_mesh(body.data)
    bmesh.ops.triangulate(bm, faces=list(bm.faces)); bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(body.data); bm.free(); body.data.update()
    arm = body.modifiers.new('Rigid chicken skin', 'ARMATURE'); arm.object = rig
    unweighted = sum(1 for v in body.data.vertices if not [g for g in v.groups if g.weight > 0])
    for o in scene.objects:
        o.select_set(False)
    rig.select_set(True); body.select_set(True); bpy.context.view_layer.objects.active = rig
    glb = RT / f'{cid}.glb'
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True, use_active_scene=True,
                              export_animations=False, export_skins=True, export_yup=True, export_materials='EXPORT',
                              export_def_bones=False)
    return {'id': cid, 'vertices': len(body.data.vertices), 'triangles': len(body.data.polygons), 'bones': len(rig.data.bones),
            'propMaterials': len(prop_cells), 'unweighted': unweighted, 'bonePrefix': cid + '_'}

def _write_png(path, res, rgba_topdown_flipped):
    # Blender pixels are bottom-up; PNG rows are top-down.
    rows = [bytes(rgba_topdown_flipped[(res - 1 - y) * res * 4:(res - y) * res * 4]) for y in range(res)]
    raw = b''.join(b'\0' + r for r in rows)
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', res, res, 8, 6, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
