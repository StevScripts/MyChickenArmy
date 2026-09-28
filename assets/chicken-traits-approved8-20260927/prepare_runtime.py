import bpy,bmesh,json,math
from mathutils import Matrix,Vector
from pathlib import Path
ns=bpy.app.driver_namespace['T8V2'];OUT=ns['OUT'];(OUT/'runtime').mkdir(exist_ok=True)
scene=bpy.data.scenes.new('ROBLOX | Eight approved traits');bpy.context.window.scene=scene
meta={};export_objects=[]
def srgb(v):return 12.92*v if v<=.0031308 else 1.055*max(0,v)**(1/2.4)-.055
for ix,(id,c) in enumerate(ns['MODELS'].items()):
 name=c['name'].replace(' ','');rig=c['rig'].copy();rig.data=c['rig'].data.copy();rig.name=name+'_Rig';scene.collection.objects.link(rig)
 rig.animation_data_clear();rig.matrix_world=Matrix.Identity(4);rig.data.pose_position='REST'
 palette=[]
 for o in c['parts']:
  for m in o.data.materials:
   if m not in palette:palette.append(m)
 im=bpy.data.images.new(name+'_Palette',width=128,height=128,alpha=True)
 im.colorspace_settings.name='sRGB';pixels=[]
 for y in range(128):
  for x in range(128):
   idx=(y//32)*4+x//32;m=palette[min(idx,len(palette)-1)]
   pixels.extend([srgb(v) for v in m.diffuse_color[:3]]+[1])
 im.pixels=pixels;im.filepath_raw=str(OUT/'runtime'/(name+'.png'));im.file_format='PNG';im.save();im.pack()
 mat=bpy.data.materials.new(name+'_Runtime');mat.use_nodes=True;p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 p.inputs['Roughness'].default_value=.35
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;tex.interpolation='Closest';mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 verts=[];faces=[];uvs=[];groups={}
 for original in c['parts']:
  o=original.copy();o.data=original.data.copy();scene.collection.objects.link(o)
  for mod in list(o.modifiers):
   if mod.type=='ARMATURE':o.modifiers.remove(mod)
   elif mod.type=='BEVEL':mod.segments=1
  dep=bpy.context.evaluated_depsgraph_get();ev=o.evaluated_get(dep);mesh=ev.to_mesh()
  off=len(verts);verts.extend(tuple(v.co) for v in mesh.vertices)
  bn=original['attachment_bone'];groups.setdefault(bn,[]).extend(range(off,len(verts)))
  for poly in mesh.polygons:
   faces.append(tuple(off+i for i in poly.vertices));mi=palette.index(original.data.materials[poly.material_index]);u=(mi%4+.5)/4;v=(mi//4+.5)/4
   uvs.append([(u+(.01 if j%2 else -.01),v+(.01 if j//2%2 else -.01)) for j in range(len(poly.vertices))])
  ev.to_mesh_clear();bpy.data.objects.remove(o,do_unlink=True)
 mesh=bpy.data.meshes.new(name+'_Mesh');mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(mat)
 skin=bpy.data.objects.new(name+'_Body',mesh);scene.collection.objects.link(skin);skin.parent=rig;skin.matrix_parent_inverse=Matrix.Identity(4)
 uv=mesh.uv_layers.new(name='UVMap')
 for poly,coords in zip(mesh.polygons,uvs):
  for li,co in zip(poly.loop_indices,coords):uv.data[li].uv=co
 for bn,ids in groups.items():skin.vertex_groups.new(name=name+'_'+bn).add(ids,1,'REPLACE')
 for bone in rig.data.bones:bone.name=name+'_'+bone.name
 arm=skin.modifiers.new('Rigid chicken skin','ARMATURE');arm.object=rig
 # Explicit triangulation makes concave wave/bat faces deterministic across importers.
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
 meta[name]={'id':id,'vertices':len(mesh.vertices),'triangles':len(mesh.polygons),'bones':len(rig.data.bones),'bonePrefix':name+'_','rig':rig.name,'mesh':skin.name,'paletteColors':len(palette)}
 assert len(mesh.polygons)<20000
 assert all(v.groups for v in mesh.vertices)
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);skin.select_set(True);bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(OUT/'runtime'/(name+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_skins=True,export_yup=True,export_materials='EXPORT',export_def_bones=False)
 rig.location=(ix*7,0,0);export_objects.extend([rig,skin])
bpy.ops.object.select_all(action='DESELECT')
for o in export_objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'runtime/Approved8-Runtime.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_skins=True,export_yup=True,export_materials='EXPORT',export_def_bones=False)
(OUT/'runtime/manifest.json').write_text(json.dumps(meta,indent=2))
ns['RUNTIME']=meta;ns['RUNTIME_SCENE']=scene
bpy.context.window.scene=ns['MODELS']['water']['scene']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Chicken-Traits-Approved8-v2.blend'))
print(json.dumps(meta))
