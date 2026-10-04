import bpy,json
from pathlib import Path
ROOT=Path('/Users/stevin/.codex/artifacts/galaxy-retexture-v2-20261004')
models=bpy.app.driver_namespace['retexture_models']
rows=[]
for ident,c in models.items():
    old=bpy.data.scenes.get('RETEXTURED EXPORT | '+ident)
    if old:
        bpy.context.window.scene=bpy.data.scenes['GALAXY RETEXTURE | Review']
        for ob in list(old.objects):bpy.data.objects.remove(ob,do_unlink=True)
        bpy.data.scenes.remove(old)
    sc=bpy.data.scenes.new('RETEXTURED EXPORT | '+ident);bpy.context.window.scene=sc
    col=bpy.data.collections.new('Retextured runtime | '+ident);sc.collection.children.link(col)
    rig=c['rig'].copy();rig.data=c['rig'].data.copy();rig.animation_data_clear();rig.name='Retextured_'+ident+'_Rig';col.objects.link(rig)
    opaque=[];glass=[]
    for src in c['parts']+c['glass']:
        ob=src.copy();ob.data=src.data.copy();col.objects.link(ob);ob.parent=rig
        # Normalize channel names before joining: all surfaces must sample UV0.
        assert len(ob.data.uv_layers)==1
        ob.data.uv_layers[0].name='UVMap'
        for mod in ob.modifiers:
            if mod.type=='ARMATURE':mod.object=rig
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
        for mod in list(ob.modifiers):
            if mod.type in ('BEVEL','SOLIDIFY'):bpy.ops.object.modifier_apply(modifier=mod.name)
        (glass if src in c['glass'] else opaque).append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in opaque:ob.select_set(True)
    bpy.context.view_layer.objects.active=opaque[0]
    if len(opaque)>1:bpy.ops.object.join()
    body=bpy.context.object;body.name=ident+'_RetexturedBody';body.data.name=body.name
    rig.scale=(.6701631701631702,)*3;bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for ob in [body]+glass:ob.select_set(True)
    rig.select_set(True);bpy.context.view_layer.objects.active=rig
    out=ROOT/'exports';out.mkdir(exist_ok=True)
    fmt='GLB'  # Accepted identifier returned by the live exporter.
    bpy.ops.export_scene.gltf(filepath=str(out/(ident+'.glb')),export_format=fmt,use_selection=True,use_active_scene=True,export_apply=False,export_materials='EXPORT',export_image_format='AUTO',export_texcoords=True,export_normals=True,export_skins=True,export_animations=False,export_cameras=False,export_lights=False,export_yup=True,export_draco_mesh_compression_enable=False,export_extras=True)
    rows.append({'id':ident,'vertices':sum(len(o.data.vertices) for o in [body]+glass),'bones':len(rig.data.bones),'uv_layers':[u.name for u in body.data.uv_layers],'glb':str(out/(ident+'.glb'))})
bpy.context.window.scene=bpy.data.scenes['GALAXY RETEXTURE | Review']
(ROOT/'export-report.json').write_text(json.dumps(rows,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Galaxy-Reference-Matched.blend'))
print(json.dumps(rows))
