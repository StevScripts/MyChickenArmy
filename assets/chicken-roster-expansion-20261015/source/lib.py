"""Roster expansion (October 15, 2026): build, render and export chickens from the
approved Chicken_Master_Rig / Chicken_Skin. Exec inside Blender with exec(open(path).read()).

Every chicken = a new scene `Roster_<ID>` holding a copied rig (18 bones, six clips),
a copied 168-vertex skin with a new pixel atlas, and one optional fitted prop mesh whose
cuboids are rigidly weighted to existing bones. Preview-only objects carry `preview_fx`
and are never exported. Base vertices, weights and proportions are never edited.
"""
import bpy, math, json, struct, zlib, importlib.util, sys
from pathlib import Path
from mathutils import Vector, Matrix, Euler

OUT = Path('/Users/stevin/.codex/artifacts/chicken-roster-expansion-20261015')
BLEND = OUT / 'Chicken-Roster-Expansion.blend'
SOURCE = bpy.data.scenes['Chicken_Master_Rig_v1']
MASTER_RIG = bpy.data.objects['Chicken_Master_Rig']
MASTER_SKIN = bpy.data.objects['Chicken_Skin']
PARTS = ['Body','Neck','Head','Beak','Wattle','Wing_L','Leg_L','Foot_L','Toe_L_1','Toe_L_2','Toe_L_3',
         'Wing_R','Leg_R','Foot_R','Toe_R_1','Toe_R_2','Toe_R_3','Eye_L','Eye_Highlight_L','Eye_R','Eye_Highlight_R']
ALLOWED = ['Chicken_Idle','Chicken_Walk','Chicken_Peck','Chicken_Hit','Chicken_Defeat','Chicken_Celebrate']
BONES = {b.name for b in MASTER_RIG.data.bones}
EYE, GLINT = (9, 11, 12), (255, 255, 251)

def linear(v):
    x = v / 255
    return x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4

def hexrgb(h):
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) if isinstance(h, str) else tuple(h)

def set_enum(owner, prop, choice):
    allowed = [i.identifier for i in owner.bl_rna.properties[prop].enum_items]
    if choice not in allowed:
        raise ValueError((prop, choice, allowed))
    setattr(owner, prop, choice)

def png(path, w, h, pixels, channels=3):
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    scan = b''.join(b'\0' + bytes(pixels[y*w*channels:(y+1)*w*channels]) for y in range(h-1, -1, -1))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6 if channels == 4 else 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(scan, 9)) + chunk(b'IEND', b''))

def solid(name, color, metallic=0, rough=.75, emission=0, alpha=1):
    mat = bpy.data.materials.new('Roster | ' + name); mat.use_nodes = True
    p = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    rgba = tuple(linear(x) for x in hexrgb(color)) + (1,)
    p.inputs['Base Color'].default_value = rgba; p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = rough; p.inputs['Alpha'].default_value = alpha
    if emission:
        p.inputs['Emission Color'].default_value = rgba; p.inputs['Emission Strength'].default_value = emission
    mat.diffuse_color = rgba
    if alpha < 1:
        set_enum(mat, 'surface_render_method', 'DITHERED')
    return mat

# ---------------------------------------------------------------- pixel atlas
def atlas(cid, spec, skin):
    """Paint the skin atlas with spec['paint'](part, normal, pos, x, y, w, h) -> rgb or (rgb, emission_rgb)."""
    mesh = skin.data; uv = mesh.uv_layers.active
    resolution = spec.get('resolution', 512); cell = resolution // 16
    density = spec.get('density', 9)
    rgb = bytearray(resolution * resolution * 4); em = bytearray(resolution * resolution * 3)
    any_em = False
    paint, eye = spec['paint'], spec.get('eye')
    for poly in mesh.polygons:
        part = PARTS[poly.index // 6]; co = [mesh.vertices[i].co for i in poly.vertices]
        normal = tuple(round(c) for c in poly.normal)
        a = co[1] - co[0]; b = co[3] - co[0]
        w = max(1, min(cell - 4, round(a.length * density))); h = max(1, min(cell - 4, round(b.length * density)))
        if part.startswith('Eye'):
            w = h = 1
        ox = poly.index % 16 * cell + 2; oy = poly.index // 16 * cell + 2
        cache = {}
        for j in range(-2, cell - 2):
            for i in range(-2, cell - 2):
                x = max(0, min(w - 1, i)); y = max(0, min(h - 1, j))
                if (x, y) not in cache:
                    pos = co[0] + a * ((x + .5) / w) + b * ((y + .5) / h)
                    if part.startswith('Eye'):
                        out = eye(part) if eye else None
                        if out is None:
                            out = GLINT if 'Highlight' in part else EYE
                    else:
                        out = paint(part, normal, tuple(pos), x, y, w, h)
                    if isinstance(out[0], (tuple, list)):
                        c, e = out
                    else:
                        c, e = out, (0, 0, 0)
                    cache[(x, y)] = (tuple(max(0, min(255, int(round(v)))) for v in c), tuple(int(v) for v in e))
                c, e = cache[(x, y)]
                ix = (oy + j) * resolution + ox + i
                rgb[ix*4:ix*4+4] = bytes(list(c) + [255]); em[ix*3:ix*3+3] = bytes(e)
                if any(e):
                    any_em = True
        for loop, p in zip(poly.loop_indices, [(ox/resolution, oy/resolution), ((ox+w)/resolution, oy/resolution),
                                               ((ox+w)/resolution, (oy+h)/resolution), (ox/resolution, (oy+h)/resolution)]):
            uv.data[loop].uv = p
    colorpath = OUT / 'textures' / f'{cid}-base-color.png'; png(colorpath, resolution, resolution, rgb, 4)
    mat = solid(cid + ' pixel surface', (255, 255, 255), spec.get('metal', 0), spec.get('rough', .78))
    nt = mat.node_tree; p = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    for old in [i for i in bpy.data.images if i.filepath == str(colorpath)]:
        bpy.data.images.remove(old)
    tex = nt.nodes.new('ShaderNodeTexImage'); set_enum(tex, 'interpolation', 'Closest')
    tex.image = bpy.data.images.load(str(colorpath)); tex.image.name = cid + '-base-color'; tex.image.pack()
    nt.links.new(tex.outputs['Color'], p.inputs['Base Color'])
    files = {'baseColor': 'textures/' + colorpath.name}
    if any_em:
        empath = OUT / 'textures' / f'{cid}-emission.png'; png(empath, resolution, resolution, em)
        et = nt.nodes.new('ShaderNodeTexImage'); et.image = bpy.data.images.load(str(empath)); et.image.name = cid + '-emission'
        et.image.pack(); set_enum(et, 'interpolation', 'Closest')
        nt.links.new(et.outputs['Color'], p.inputs['Emission Color']); p.inputs['Emission Strength'].default_value = spec.get('glow', 2.0)
        files['emission'] = 'textures/' + empath.name
    mesh.materials.clear(); mesh.materials.append(mat)
    return files

# ---------------------------------------------------------------- fitted props
class Props:
    """Collect rigid cuboids, then create one skinned accessory mesh."""
    def __init__(self, cid):
        self.cid = cid; self.mats = []; self.matindex = {}; self.boxes = []
    def mat(self, name, color, rough=.7, metal=0, emit=0, alpha=1):
        if name not in self.matindex:
            self.matindex[name] = len(self.mats)
            self.mats.append(solid(f'{self.cid} {name}', color, metal, rough, emit, alpha))
        return name
    def box(self, label, center, size, bone, mat, rot=(0, 0, 0)):
        assert bone in BONES, bone
        self.boxes.append((label, tuple(center), tuple(size), bone, mat, tuple(rot)))
    def seg(self, label, a, b, w, d, bone, mat):
        """Rod from point a to point b (local Z along the rod), w x d cross-section."""
        A, B = Vector(a), Vector(b); D = B - A
        R = D.to_track_quat('Z', 'Y').to_matrix()
        assert bone in BONES, bone
        self.boxes.append((label, tuple((A + B) / 2), (w, d, D.length), bone, mat, R))
    def stack(self, label, base, layers, bone, mat, lean=(0, 0)):
        """Voxel taper: layers = [(w, d, h), ...] bottom-up; lean shifts each layer in x/y."""
        z = base[2]
        for i, (w, d, h) in enumerate(layers):
            self.box(f'{label} {i}', (base[0] + lean[0] * i, base[1] + lean[1] * i, z + h / 2), (w, d, h), bone, mat)
            z += h
    def build(self, scene, rig, collection):
        if not self.boxes:
            return None
        verts, faces, groups, mats = [], [], [], []
        for label, center, size, bone, mat, rot in self.boxes:
            n = len(verts); C = Vector(center); a, b, c = [v / 2 for v in size]
            R = rot if isinstance(rot, Matrix) else Euler([math.radians(r) for r in rot], 'XYZ').to_matrix()
            for i, j, k in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]:
                verts.append(tuple(C + R @ Vector((i*a, j*b, k*c))))
            faces.extend([tuple(n + i for i in f) for f in [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]])
            groups.append(bone); mats.append(self.matindex[mat])
        mesh = bpy.data.meshes.new(f'Roster_{self.cid}_Props'); mesh.from_pydata(verts, [], faces); mesh.update()
        uvl = mesh.uv_layers.new(name='UVMap')
        for loop in mesh.loops:
            uvl.data[loop.index].uv = (.5, .5)
        obj = bpy.data.objects.new(f'Roster_{self.cid}_Props', mesh); collection.objects.link(obj); obj.parent = rig
        for m in self.mats:
            mesh.materials.append(m)
        for i, bone in enumerate(groups):
            g = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            g.add(list(range(i*8, i*8+8)), 1, 'REPLACE')
            for p in list(mesh.polygons)[i*6:i*6+6]:
                p.material_index = mats[i]
        mod = obj.modifiers.new('Approved Chicken Skeleton', 'ARMATURE'); mod.object = rig
        obj['export_accessory'] = True
        return obj

def preview_fx(scene, collection, rig, name, center, size, color, emit=4, bone='Body'):
    """Preview-only glow cube (sparkle, ember, orb). Never exported."""
    mesh = bpy.data.meshes.new(name); x, y, z = center; a, b, c = [v / 2 for v in size]
    mesh.from_pydata([(x+i*a, y+j*b, z+k*c) for i, j, k in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]], [],
                     [(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)])
    obj = bpy.data.objects.new(name, mesh); collection.objects.link(obj)
    obj.parent = rig; obj.parent_type = 'BONE'; obj.parent_bone = bone
    bpy.context.view_layer.update(); obj.matrix_world = Matrix.Identity(4)
    obj.data.materials.append(solid(name, color, 0, .4, emit)); obj['preview_fx'] = True
    return obj

# ---------------------------------------------------------------- scenes
def studio(scene, ortho=6.7):
    for src in SOURCE.objects:
        if src in (MASTER_RIG, MASTER_SKIN):
            continue
        obj = src.copy(); obj.name = scene.name + ' | ' + src.name
        if src.data:
            obj.data = src.data.copy()
        scene.collection.objects.link(obj)
        if src.type == 'CAMERA':
            scene.camera = obj
    scene.world = SOURCE.world.copy(); scene.render.engine = SOURCE.render.engine
    scene.view_settings.view_transform = 'Standard'; scene.view_settings.exposure = -.30
    scene.render.resolution_x = 960; scene.render.resolution_y = 960; scene.render.resolution_percentage = 100
    set_enum(scene.render.image_settings, 'file_format', 'PNG'); scene.render.fps = 30; scene.frame_start = 1; scene.frame_end = 121
    scene.camera.data.ortho_scale = ortho

def load_specs(batch):
    path = OUT / 'source' / f'{batch}.py'
    sys.dont_write_bytecode = True
    for stale in (OUT / 'source' / '__pycache__').glob('*.pyc'):
        stale.unlink()
    sys.modules.pop('pal', None)
    sys.path.insert(0, str(OUT / 'source'))
    spec = importlib.util.spec_from_file_location('roster_' + batch, path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m.SPECS

def objects_of(cid):
    col = bpy.data.collections.get('Roster_' + cid)
    return list(col.objects) if col else []

def remove(cid):
    """Delete a previous build of this roster chicken only (its own scene and collection)."""
    col = bpy.data.collections.get('Roster_' + cid)
    if col:
        for o in list(col.objects):
            data = o.data; bpy.data.objects.remove(o, do_unlink=True)
            if data and data.users == 0 and isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)
        bpy.data.collections.remove(col)
    sc = bpy.data.scenes.get('Roster_' + cid)
    if sc:
        for o in list(sc.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(sc)

def build(cid, spec, render=True):
    remove(cid)
    scene = bpy.data.scenes.new('Roster_' + cid); studio(scene, spec.get('ortho', 6.7))
    bpy.context.window.scene = scene
    col = bpy.data.collections.new('Roster_' + cid); scene.collection.children.link(col)
    rig = MASTER_RIG.copy(); rig.data = MASTER_RIG.data.copy(); rig.name = f'Roster_{cid}_Rig'; col.objects.link(rig)
    rig.data.pose_position = 'POSE'; rig.animation_data_clear(); rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions['Chicken_Idle']; rig.animation_data.action_slot = rig.animation_data.action.slots[0]
    skin = MASTER_SKIN.copy(); skin.data = MASTER_SKIN.data.copy(); skin.name = f'Roster_{cid}_Skin'; skin.data.name = f'Roster_{cid}_Skin'; col.objects.link(skin); skin.parent = rig
    for mod in skin.modifiers:
        if mod.type == 'ARMATURE':
            mod.object = rig
    files = atlas(cid, spec, skin)
    props = None
    if spec.get('props'):
        P = Props(cid); spec['props'](P); props = P.build(scene, rig, col)
    if spec.get('fx'):
        spec['fx'](lambda *a, **k: preview_fx(scene, col, rig, *a, **k))
    rig['variant_name'] = spec['name']; rig['appearance_id'] = cid; rig['concept'] = f'concepts/{cid}.png'
    rig['base_mesh_unchanged'] = True; rig['textures'] = json.dumps(files)
    scene.frame_set(1)
    if render:
        scene.render.filepath = str(OUT / 'previews' / f'{cid}.png'); bpy.ops.render.render(write_still=True)
    return {'id': cid, 'scene': scene.name, 'props': len(props.data.polygons) // 6 if props else 0, 'textures': files}

POSES = {'Chicken_Walk': .3, 'Chicken_Peck': .45, 'Chicken_Celebrate': .5}

def render_poses(cid):
    scene = bpy.data.scenes['Roster_' + cid]; bpy.context.window.scene = scene
    rig = bpy.data.objects[f'Roster_{cid}_Rig']; out = []
    for action, t in POSES.items():
        act = bpy.data.actions[action]; rig.animation_data.action = act; rig.animation_data.action_slot = act.slots[0]
        s, e = act.frame_range; scene.frame_set(int(s + (e - s) * t))
        scene.render.filepath = str(OUT / 'previews' / f'{cid}-{action}.png'); bpy.ops.render.render(write_still=True)
        out.append(f'previews/{cid}-{action}.png')
    act = bpy.data.actions['Chicken_Idle']; rig.animation_data.action = act; rig.animation_data.action_slot = act.slots[0]; scene.frame_set(1)
    return out

def save():
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

# ---------------------------------------------------------------- export + review
def glb_doc(path):
    raw = path.read_bytes(); length = struct.unpack_from('<I', raw, 12)[0]
    return raw, json.loads(raw[20:20+length]), length

def export(cid):
    scene = bpy.data.scenes['Roster_' + cid]; bpy.context.window.scene = scene
    rig = bpy.data.objects[f'Roster_{cid}_Rig']; skin = bpy.data.objects[f'Roster_{cid}_Skin']
    meshes = [skin] + [o for o in objects_of(cid) if o.type == 'MESH' and o.get('export_accessory') and not o.get('preview_fx')]
    for o in scene.objects:
        o.select_set(False)
    for o in [rig] + meshes:
        o.hide_set(False); o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    action = rig.animation_data.action; slot = rig.animation_data.action_slot
    glb = OUT / 'models' / f'{cid}.glb'; fbx = OUT / 'models' / f'{cid}-Bind.fbx'
    try:
        scene.frame_set(1)
        bpy.ops.export_scene.gltf(filepath=str(glb), use_selection=True, use_active_scene=True, export_animations=True,
                                  export_animation_mode='ACTIONS', export_def_bones=False, export_optimize_animation_size=False)
        raw, doc, length = glb_doc(glb)
        doc['animations'] = [a for a in doc.get('animations', []) if a.get('name') in ALLOWED]
        enc = json.dumps(doc, separators=(',', ':')).encode(); enc += b' ' * ((-len(enc)) % 4); tail = raw[20+length:]
        glb.write_bytes(struct.pack('<III', 0x46546c67, 2, 20 + len(enc) + len(tail)) + struct.pack('<II', len(enc), 0x4e4f534a) + enc + tail)
        rig.animation_data.action = None; rig.data.pose_position = 'REST'; scene.frame_set(1)
        bpy.ops.export_scene.fbx(filepath=str(fbx), use_selection=True, add_leaf_bones=False, use_armature_deform_only=False,
                                 bake_anim=False, path_mode='COPY', embed_textures=True)
    finally:
        rig.data.pose_position = 'POSE'; rig.animation_data.action = action; rig.animation_data.action_slot = slot; scene.frame_set(1)
    return review(cid, meshes, rig, skin)

def review(cid, meshes, rig, skin):
    _, doc, _ = glb_doc(OUT / 'models' / f'{cid}.glb')
    names = {n.get('name') for n in doc.get('nodes', [])}
    mesh_nodes = [n for n in doc['nodes'] if 'mesh' in n]
    skinned = all('skin' in n for n in mesh_nodes)
    prims_joints = all('JOINTS_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives'])
    anims = sorted(a['name'] for a in doc.get('animations', []))
    images_embedded = bool(doc.get('images')) and all('bufferView' in i for i in doc['images'])
    preview_leak = [o.name for o in objects_of(cid) if o.get('preview_fx') and o.name in names]
    joints = [len(s['joints']) for s in doc.get('skins', [])]
    base_delta = max((a.co - b.co).length for a, b in zip(MASTER_SKIN.data.vertices, skin.data.vertices))
    unweighted = 0
    for obj in meshes:
        for v in obj.data.vertices:
            if not [g for g in v.groups if g.weight > 0 and obj.vertex_groups[g.group].name in rig.data.bones]:
                unweighted += 1
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    ok = (skinned and prims_joints and anims == sorted(ALLOWED) and images_embedded and not preview_leak
          and joints and all(j == 18 for j in joints) and base_delta == 0 and unweighted == 0
          and len(skin.data.vertices) == 168 and (OUT / 'models' / f'{cid}-Bind.fbx').exists())
    return {'id': cid, 'name': rig['variant_name'], 'ok': ok, 'meshNodes': [n.get('name') for n in mesh_nodes],
            'allMeshesSkinned': skinned and prims_joints, 'jointsPerSkin': joints, 'animations': anims,
            'embeddedImages': len(doc.get('images', [])), 'previewObjectsExported': preview_leak,
            'baseVertices': len(skin.data.vertices), 'baseVertexDelta': base_delta, 'unweightedVertices': unweighted,
            'triangles': tris, 'glb': f'models/{cid}.glb', 'fbx': f'models/{cid}-Bind.fbx',
            'glbBytes': (OUT / 'models' / f'{cid}.glb').stat().st_size}

# ---------------------------------------------------------------- lineup
def lineup(batch, ids, cols=None, label=None):
    name = 'Roster_Lineup_' + batch
    old = bpy.data.scenes.get(name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new(name); studio(scene); bpy.context.window.scene = scene
    cols = cols or min(len(ids), 5); rows = math.ceil(len(ids) / cols); spacing = 4.4
    for k, cid in enumerate(ids):
        r, c = divmod(k, cols)
        inst = bpy.data.objects.new('Lineup ' + cid, None); inst.instance_type = 'COLLECTION'
        inst.instance_collection = bpy.data.collections['Roster_' + cid]
        x = (c - (cols - 1) / 2) * spacing; y = (r - (rows - 1) / 2) * spacing * 1.15
        inst.location = (x, y, 0); scene.collection.objects.link(inst)
        txt = bpy.data.curves.new('Label ' + cid, 'FONT'); txt.body = bpy.data.objects[f'Roster_{cid}_Rig']['variant_name']
        txt.align_x = 'CENTER'; txt.size = .42
        t = bpy.data.objects.new('Label ' + cid, txt); scene.collection.objects.link(t)
        t.location = (x, y - 2.3, .02); t.data.materials.append(solid('Label ink', (40, 44, 52), 0, .8))
    cam = scene.camera
    # Top-down three-quarter framing of the whole grid.
    width = cols * spacing; depth = rows * spacing * 1.15
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(width * 1.05, depth * 1.35) + 1.5
    cam.location = Vector((width * .55, -depth * .9 - 14, 16)); look = Vector((0, 0, 1.6))
    cam.rotation_euler = (look - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.resolution_x = 1800; scene.render.resolution_y = max(900, int(1800 * (rows * 1.2) / cols))
    floor = next((o for o in scene.objects if 'Backdrop' in o.name), None)
    if floor:
        floor.scale = (floor.scale[0] * 4, floor.scale[1] * 4, floor.scale[2])
    path = OUT / 'batches' / f'{batch}-lineup.png'; scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return str(path)

# ---------------------------------------------------------------- batch driver
def run_batch(batch, ids=None, rebuild=True, poses=True):
    specs = load_specs(batch); ids = ids or list(specs)
    entries = []
    for cid in ids:
        spec = specs[cid]
        if rebuild or ('Roster_' + cid) not in bpy.data.scenes:
            build(cid, spec, render=True)
        pose_files = render_poses(cid) if poses else []
        rev = export(cid)
        rig = bpy.data.objects[f'Roster_{cid}_Rig']
        entries.append({'id': cid, 'name': spec['name'], 'rarity': spec.get('rarity'), 'band': spec.get('band'),
                        'zone': spec.get('zone'), 'earn': spec.get('earn', 'normal roll'),
                        'concept': f'concepts/{cid}.png', 'preview': f'previews/{cid}.png', 'poses': pose_files,
                        'textures': json.loads(rig['textures']), 'vfxPlan': spec.get('vfx'), 'review': rev})
        save()
    path = str(OUT / 'batches' / f'{batch}-lineup.png')  # composed by lineup.py from the real renders
    (OUT / 'batches' / f'{batch}-manifest.json').write_text(json.dumps({'batch': batch, 'blend': BLEND.name,
        'lineup': f'batches/{batch}-lineup.png', 'chickens': entries}, indent=2))
    save()
    return {'batch': batch, 'lineup': path, 'ok': all(e['review']['ok'] for e in entries),
            'failed': [e['id'] for e in entries if not e['review']['ok']]}
