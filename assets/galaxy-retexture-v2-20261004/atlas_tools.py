"""Repaint the existing galaxy chicken atlases without changing their meshes.

Call from Blender after opening Galaxy-Feather-Wings.blend. Importing this file
does not open, save, export, render, or modify a scene. Shader colors are sRGB;
height is in the authoring mesh's local units. All arrays use Blender's bottom-up
image coordinates. The original visor is deliberately excluded from repainting.
"""

import hashlib
import json
import math
import struct
import zlib
from pathlib import Path

import bpy
import numpy as np


BASE_LABELS = (
    "Body", "Neck", "Head", "Beak", "Wattle", "Wing_L", "Leg_L",
    "Foot_L", "Foot_L", "Foot_L", "Foot_L", "Wing_R", "Leg_R",
    "Foot_R", "Foot_R", "Foot_R", "Foot_R", "Eye", "Glint", "Eye", "Glint",
)


def palette(ident, label):
    if ident == "astronaut":
        if label == "Head":
            return "cosmic"
        if label.startswith("Wing"):
            return "navy"
        return {"Eye": "eye", "Glint": "white_light", "Beak": "yellow",
                "Wattle": "red"}.get(label, "suit")
    if ident == "alien":
        if label.startswith(("Wing", "Foot")) or label == "Beak":
            return "purple"
        return {"Eye": "eye", "Glint": "lime_light", "Wattle": "red"}.get(label, "alien")
    if label in ("Eye", "Glint"):
        return "pink_light"
    if label.startswith(("Wing", "Foot", "Leg")):
        return "dark_purple"
    return {"Beak": "lilac", "Wattle": "magenta"}.get(label, "plasma")


def _socket(node, direction, identifier):
    sockets = getattr(node, direction)
    result = next((s for s in sockets if s.identifier == identifier), None)
    if result is None:
        result = sockets.get(identifier)
    if result is None:
        raise KeyError(f"Missing {node.bl_idname} {direction} socket {identifier!r}")
    return result


def _material_images(material):
    images = {}
    if not material or not material.use_nodes:
        return images
    for node in material.node_tree.nodes:
        if node.bl_idname == "ShaderNodeTexImage" and node.image:
            for key in ("ColorMap", "NormalMap", "ORM", "EmissionColor",
                        "RoughnessMap", "MetalnessMap", "OpacityMap"):
                if node.label == key or node.image.name.rsplit(" | ", 1)[-1] == key:
                    images[key] = node.image
    if "ColorMap" not in images:
        for node in material.node_tree.nodes:
            if node.bl_idname == "ShaderNodeBsdfPrincipled":
                for link in _socket(node, "inputs", "Base Color").links:
                    if link.from_node.bl_idname == "ShaderNodeTexImage" and link.from_node.image:
                        images["ColorMap"] = link.from_node.image
    return images


def reconstruct(manifest_path):
    """Return an id -> model dictionary referencing the currently loaded blend."""
    doc = json.loads(Path(manifest_path).read_text())
    models = {}
    for row in doc["models"]:
        base = bpy.data.objects[row["base"]]
        if len(base.data.vertices) != 504:
            raise ValueError(f"{row['id']}: expected the unchanged 504-vertex base")
        accessories = [bpy.data.objects[name] for name in row["accessories"]]
        glass = [ob for ob in accessories if "Clear fitted visor" in ob.name]
        parts = [base] + [ob for ob in accessories if ob not in glass]
        material = base.data.materials[0]
        images = _material_images(material)
        if "ColorMap" not in images:
            raise ValueError(f"Cannot identify {row['id']}'s current ColorMap")
        models[row["id"]] = dict(
            id=row["id"], name=row["name"], base=base,
            rig=bpy.data.objects[row["rig"]], scene=bpy.data.scenes[row["scene"]],
            parts=parts, accessories=[ob for ob in accessories if ob not in glass],
            glass=glass, material=material, images=images,
            source_color_image=images["ColorMap"], manifest=row,
        )
    return models


def geometry_signature(model):
    """Hash geometry, every UV layer, transforms, weights and rest/pose bones."""
    if isinstance(model, dict):
        objects = model["parts"] + model.get("glass", []) + [model["rig"]]
    elif isinstance(model, bpy.types.Object):
        objects = [model]
    else:
        objects = list(model)
    rows = []
    for ob in sorted(set(objects), key=lambda item: item.name):
        row = dict(name=ob.name, type=ob.type, parent=ob.parent.name if ob.parent else None,
                   matrix=[list(v) for v in ob.matrix_world],
                   parent_inverse=[list(v) for v in ob.matrix_parent_inverse])
        if ob.type == "MESH":
            me = ob.data
            row.update(vertices=[list(v.co) for v in me.vertices],
                       polygons=[list(p.vertices) for p in me.polygons],
                       groups=[g.name for g in ob.vertex_groups],
                       weights=[[(g.group, g.weight) for g in v.groups] for v in me.vertices],
                       uvs=[dict(name=u.name, active_render=u.active_render,
                                 values=[list(v.uv) for v in u.data]) for u in me.uv_layers],
                       uv_active=me.uv_layers.active_index)
        elif ob.type == "ARMATURE":
            row["bones"] = [dict(name=b.name, parent=b.parent.name if b.parent else None,
                                 matrix=[list(v) for v in b.matrix_local],
                                 head=list(b.head_local), tail=list(b.tail_local),
                                 deform=b.use_deform) for b in ob.data.bones]
            row["pose"] = [(p.name, [list(v) for v in p.matrix_basis]) for p in ob.pose.bones]
        rows.append(row)
    return hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


signature = geometry_signature


def _tiles(c):
    for ob in c["parts"]:
        me = ob.data
        uv_layer = me.uv_layers.active
        if uv_layer is None:
            raise ValueError(f"Missing UV layer: {ob.name}")
        groups = {}
        for polygon in me.polygons:
            normal = np.asarray(polygon.normal[:], dtype=np.float64)
            vi = polygon.vertices[0]
            if ob == c["base"]:
                component = vi // 24
                label = BASE_LABELS[component]
                style = palette(c["id"], label)
            else:
                component = 0
                label, style = ob["piece"], ob["surface_style"]
            distance = float(np.dot(np.asarray(me.vertices[vi].co[:]), normal))
            key = (component, tuple(np.round(normal, 4)), round(distance, 4))
            group = groups.setdefault(key, dict(label=label, style=style, N=normal,
                                                loops=[], polygon_loops=[]))
            group["loops"].extend(polygon.loop_indices)
            group["polygon_loops"].append(list(polygon.loop_indices))
        for group in groups.values():
            loops = sorted(set(group.pop("loops")))
            polygons = group.pop("polygon_loops")
            uv = np.array([uv_layer.data[i].uv[:] for i in loops], dtype=np.float64)
            positions = np.array([me.vertices[me.loops[i].vertex_index].co[:] for i in loops])
            design = np.column_stack((uv, np.ones(len(uv))))
            affine, _, rank, _ = np.linalg.lstsq(design, positions, rcond=None)
            if rank == 3 and float(np.max(np.abs(design @ affine - positions))) <= 1e-4:
                yield dict(group, ob=ob, low=uv.min(0), high=uv.max(0), affine=affine)
                continue
            # Rounded coplanar groups can include slightly twisted tube faces.
            # The existing convex polygons can still be painted exactly through
            # triangle interpolation, without triangulating or modifying the mesh.
            for polygon in polygons:
                for i in range(1, len(polygon) - 1):
                    triangle = [polygon[0], polygon[i], polygon[i + 1]]
                    tri_uv = np.array([uv_layer.data[j].uv[:] for j in triangle], dtype=np.float64)
                    tri_pos = np.array([me.vertices[me.loops[j].vertex_index].co[:] for j in triangle])
                    tri_design = np.column_stack((tri_uv, np.ones(3)))
                    if np.linalg.matrix_rank(tri_design) < 3:
                        # A collapsed UV cannot encode a varying material. Keep
                        # its coordinate and supply a representative constant.
                        constant = np.zeros((3, 3), dtype=np.float64)
                        constant[2] = tri_pos.mean(0)
                        yield dict(group, ob=ob, low=tri_uv.min(0), high=tri_uv.max(0),
                                   affine=constant, degenerate=True)
                        continue
                    inverse = np.linalg.inv(tri_design)
                    yield dict(group, ob=ob, low=tri_uv.min(0), high=tri_uv.max(0),
                               affine=inverse @ tri_pos, triangle_uv=tri_uv,
                               triangle_inverse=inverse, shade_low=uv.min(0), shade_high=uv.max(0))


def _read_alpha(image, size):
    if tuple(image.size) != (size, size):
        raise ValueError(f"Preserving alpha requires original {size}x{size} ColorMap; got {tuple(image.size)}")
    values = np.empty(size * size * 4, dtype=np.float32)
    image.pixels.foreach_get(values)
    return values.reshape(size, size, 4)[..., 3].copy()


def _png(path, array):
    arr = np.uint8(np.clip(array, 0, 1) * 255 + 0.5)
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, axis=-1)
    height, width, channels = arr.shape
    if channels not in (3, 4):
        raise ValueError("PNG writer accepts RGB or RGBA")
    def chunk(kind, payload):
        return (struct.pack("!I", len(payload)) + kind + payload
                + struct.pack("!I", zlib.crc32(kind + payload) & 0xffffffff))
    raw = b"".join(b"\0" + row.tobytes() for row in arr[::-1])
    path.write_bytes(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", struct.pack("!2I5B", width, height, 8, 6 if channels == 4 else 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def _enum(owner, property_name, candidates):
    prop = owner.bl_rna.properties.get(property_name)
    if prop is None:
        return False
    identifiers = {item.identifier for item in prop.enum_items} if prop.type == "ENUM" else None
    for candidate in candidates:
        if identifiers and candidate not in identifiers:
            continue
        try:
            setattr(owner, property_name, candidate)
            return True
        except (TypeError, ValueError):
            pass
    return False


def _material(c, arrays, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    paths, images = {}, {}
    for key, arr in arrays.items():
        path = (out_dir / f"{c['id']}_{key}.png").resolve()
        _png(path, arr)
        image = bpy.data.images.load(str(path), check_existing=False)
        image.name = f"Galaxy Retexture 20261004 | {c['id']} | {key}"
        colorspaces = ("sRGB",) if key in ("ColorMap", "EmissionColor") else ("Non-Color", "Raw")
        if not _enum(image.colorspace_settings, "name", colorspaces):
            raise ValueError(f"Cannot configure image color space: {key}")
        image.pack()
        paths[key], images[key] = str(path), image
    material = bpy.data.materials.new(f"Galaxy Retexture 20261004 | {c['name']}")
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    output = nodes.new("ShaderNodeOutputMaterial")
    links.new(_socket(shader, "outputs", "BSDF"), _socket(output, "inputs", "Surface"))
    _socket(shader, "inputs", "Emission Strength").default_value = 1.0
    textures = {}
    for i, key in enumerate(("ColorMap", "ORM", "NormalMap", "EmissionColor")):
        node = nodes.new("ShaderNodeTexImage")
        node.image, node.label, node.location = images[key], key, (-650, 400 - i * 270)
        textures[key] = node
    def connect(key, output_id, target, input_id):
        links.new(_socket(textures[key], "outputs", output_id), _socket(target, "inputs", input_id))
    connect("ColorMap", "Color", shader, "Base Color")
    connect("ColorMap", "Alpha", shader, "Alpha")
    connect("EmissionColor", "Color", shader, "Emission Color")
    split = nodes.new("ShaderNodeSeparateColor")
    _enum(split, "mode", ("RGB",))
    connect("ORM", "Color", split, "Color")
    links.new(_socket(split, "outputs", "Green"), _socket(shader, "inputs", "Roughness"))
    links.new(_socket(split, "outputs", "Blue"), _socket(shader, "inputs", "Metallic"))
    normal = nodes.new("ShaderNodeNormalMap")
    _socket(normal, "inputs", "Strength").default_value = 0.4
    connect("NormalMap", "Color", normal, "Color")
    links.new(_socket(normal, "outputs", "Normal"), _socket(shader, "inputs", "Normal"))
    if not _enum(material, "surface_render_method", ("DITHERED",)):
        _enum(material, "blend_method", ("HASHED", "CLIP"))
    for ob in c["parts"]:
        ob.data.materials.clear()
        ob.data.materials.append(material)
    return paths, images, material


def bake_existing(c, shade, out_dir, size=2048):
    """Paint existing tiles; return paths/images/material/arrays and signatures.

    `out_dir` is the exact directory receiving this model's named map files.
    `UV` passed to shade is normalized within its face tile, matching the old
    shader contract. `P` is authoring local space. No UV coordinates are written.
    Original atlas alpha is retained byte-for-byte, including unused pixels,
    unless c['restrict_alpha'] is true: generated alpha may then only reduce it.
    """
    before = geometry_signature(c)
    alpha = _read_alpha(c.get("source_color_image", c["images"]["ColorMap"]), size)
    generated_alpha = np.ones((size, size), dtype=np.float32)
    color = np.zeros((size, size, 3), dtype=np.float32)
    roughness = np.full((size, size), 0.4, dtype=np.float32)
    metalness = np.zeros((size, size), dtype=np.float32)
    emission = np.zeros((size, size), dtype=np.float32)
    normal = np.empty((size, size, 3), dtype=np.float32)
    normal[:] = (0.5, 0.5, 1.0)
    covered = np.zeros((size, size), dtype=bool)
    tile_count = 0
    triangle_count = 0
    degenerate_count = 0
    for tile in _tiles(c):
        low, high = tile["low"], tile["high"]
        # UV endpoints were authored on integer pixel boundaries. Round tiny
        # float storage noise before expanding by the original four-pixel bleed.
        x0, y0 = np.maximum(0, np.floor(np.round(low * size, 4)).astype(int) - 4)
        x1, y1 = np.minimum(size, np.ceil(np.round(high * size, 4)).astype(int) + 4)
        raw_u, raw_v = np.meshgrid((np.arange(x0, x1) + 0.5) / size,
                                   (np.arange(y0, y1) + 0.5) / size)
        u, v = np.clip(raw_u, low[0], high[0]), np.clip(raw_v, low[1], high[1])
        absolute_uv = np.stack((u, v), axis=-1)
        core = (raw_u >= low[0]) & (raw_u <= high[0]) & (raw_v >= low[1]) & (raw_v <= high[1])
        mask = np.ones(u.shape, dtype=bool)
        if "triangle_uv" in tile:
            raw_uv = np.stack((raw_u, raw_v), axis=-1)
            homogeneous = np.stack((raw_u, raw_v, np.ones_like(raw_u)), axis=-1)
            weights = homogeneous @ tile["triangle_inverse"]
            core = np.min(weights, axis=-1) >= -1e-7
            clamped_weights = np.maximum(weights, 0)
            clamped_weights /= np.maximum(clamped_weights.sum(-1, keepdims=True), 1e-12)
            absolute_uv = clamped_weights @ tile["triangle_uv"]
            distance = np.linalg.norm((raw_uv - absolute_uv) * size, axis=-1)
            mask = core | ((distance <= 4.5) & ~covered[y0:y1, x0:x1])
            u, v = absolute_uv[..., 0], absolute_uv[..., 1]
            triangle_count += 1
        shade_low, shade_high = tile.get("shade_low", low), tile.get("shade_high", high)
        relative_uv = (absolute_uv - shade_low) / np.maximum(shade_high - shade_low, 1e-12)
        if tile.get("degenerate"):
            relative_uv[:] = 0.5
            degenerate_count += 1
        affine = tile["affine"]
        positions = u[..., None] * affine[0] + v[..., None] * affine[1] + affine[2]
        cc, rr, mm, ee, hh, aa = shade(c["id"], tile["style"], positions,
                                      relative_uv, tile["N"], tile["label"])
        shape = u.shape
        color[y0:y1, x0:x1][mask] = np.broadcast_to(cc, shape + (3,))[mask]
        roughness[y0:y1, x0:x1][mask] = np.broadcast_to(rr, shape)[mask]
        metalness[y0:y1, x0:x1][mask] = np.broadcast_to(mm, shape)[mask]
        emission[y0:y1, x0:x1][mask] = np.broadcast_to(ee, shape)[mask]
        generated_alpha[y0:y1, x0:x1][mask] = np.broadcast_to(aa, shape)[mask]
        height = np.broadcast_to(hh, shape)
        spacing_u = max(float(np.linalg.norm(affine[0])) / size, 1e-9)
        spacing_v = max(float(np.linalg.norm(affine[1])) / size, 1e-9)
        dv, du = np.gradient(height, spacing_v, spacing_u)
        n = np.stack((-du, -dv, np.ones_like(du)), axis=-1)
        n /= np.linalg.norm(n, axis=-1)[..., None]
        normal[y0:y1, x0:x1][mask] = (n * 0.5 + 0.5)[mask]
        covered[y0:y1, x0:x1] |= core
        tile_count += 1
    color = np.clip(color, 0, 1)
    roughness = np.clip(roughness, 0, 1)
    metalness = np.clip(metalness, 0, 1)
    linear_color = np.where(color <= 0.04045, color / 12.92, ((color + 0.055) / 1.055) ** 2.4)
    linear_emission = linear_color * np.maximum(emission, 0)[..., None]
    emission_color = np.where(linear_emission <= 0.0031308, linear_emission * 12.92,
                              1.055 * np.maximum(linear_emission, 0) ** (1 / 2.4) - 0.055)
    effective_alpha = np.minimum(alpha, np.clip(generated_alpha, 0, 1)) if c.get("restrict_alpha") else alpha
    arrays = dict(ColorMap=np.concatenate((color, effective_alpha[..., None]), axis=-1),
                  RoughnessMap=roughness, MetalnessMap=metalness, NormalMap=normal,
                  EmissionColor=np.clip(emission_color, 0, 1),
                  ORM=np.stack((np.ones_like(roughness), roughness, metalness), axis=-1))
    for key, array in arrays.items():
        if not np.all(np.isfinite(array)):
            raise ValueError(f"Shader produced non-finite {key} pixels")
    paths, images, material = _material(c, arrays, Path(out_dir))
    after = geometry_signature(c)
    if before != after:
        raise AssertionError("Geometry, UVs, transforms or skin weights changed during repaint")
    c.update(images=images, material=material)
    return dict(paths=paths, images=images, material=material, arrays=arrays,
                before=before, after=after, tile_count=tile_count,
                triangle_fallback_count=triangle_count, degenerate_uv_count=degenerate_count,
                alpha_restricted=bool(c.get("restrict_alpha")),
                alpha_preserved=bool(np.array_equal(arrays["ColorMap"][..., 3], alpha)))
