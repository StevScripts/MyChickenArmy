import bpy,json,pathlib,traceback
out=pathlib.Path('/Users/stevin/Documents/Projects/MyChickenArmy/assets/dragon-attack-20261006')
s=bpy.context.scene
rig=bpy.data.objects['Dragon | Flight Rig']; mesh=bpy.data.objects['Dragon | Skinned mesh']
state={'start':s.frame_start,'end':s.frame_end,'frame':s.frame_current,'active':bpy.context.view_layer.objects.active,'selection':list(bpy.context.selected_objects)}
imgs=[]; copies=[]
try:
 if bpy.context.screen and bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
 if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
 r=rig.copy(); r.data=rig.data.copy();s.collection.objects.link(r);r.name='DragonFlightRig';copies.append(r)
 m=mesh.copy();m.data=mesh.data.copy();s.collection.objects.link(m);m.name='DragonChickenMesh';copies.append(m);m.parent=r
 for mod in m.modifiers:
  if mod.type=='ARMATURE':mod.object=r;mod.use_deform_preserve_volume=False
 trimmed=0;maxloss=0
 for v in m.data.vertices:
  gs=sorted([(g.group,g.weight) for g in v.groups if g.weight>0],key=lambda x:x[1],reverse=True)
  keep=gs[:4];loss=sum(w for _,w in gs[4:]);maxloss=max(maxloss,loss)
  if len(gs)>4:trimmed+=1
  for gi,w in gs[4:]:m.vertex_groups[gi].remove([v.index])
  total=sum(w for _,w in keep)
  for gi,w in keep:m.vertex_groups[gi].add([v.index],w/total,'REPLACE')
 for slot in m.material_slots:
  for node in slot.material.node_tree.nodes:
   if node.type=='TEX_IMAGE' and node.image and node.image not in [i[0] for i in imgs]:
    im=node.image;imgs.append((im,im.filepath));p=out/im.name
    if im.packed_file:p.write_bytes(im.packed_file.data)
    else:
     import shutil
     shutil.copyfile(bpy.path.abspath(im.filepath),p)
    im.filepath=str(p)
 bpy.ops.object.select_all(action='DESELECT');r.select_set(True);m.select_set(True);bpy.context.view_layer.objects.active=r
 s.frame_start=1;s.frame_end=85;s.frame_set(1)
 kw=dict(use_selection=True,object_types={'ARMATURE','MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',add_leaf_bones=False,use_armature_deform_only=False,armature_nodetype='NULL',path_mode='COPY',embed_textures=True,bake_anim_use_nla_strips=False,bake_anim_use_all_actions=False,bake_anim_step=1,bake_anim_simplify_factor=0)
 bpy.ops.export_scene.fbx(filepath=str(out/'GalaxyDragon-Attack.fbx'),bake_anim=True,**kw)
 # Direct evaluated local bone matrices retain the exact cycle for native KeyframeSequence packaging.
 bones=[{'name':b.name,'parent':b.parent.name if b.parent else None,'rest':[list(row) for row in b.matrix_local]} for b in rig.data.bones]
 frames=[]
 for frame in range(1,86):
  s.frame_set(frame);p={}
  for b in rig.pose.bones:
   mat=b.parent.matrix.inverted()@b.matrix if b.parent else b.matrix
   rest=b.bone.parent.matrix_local.inverted()@b.bone.matrix_local if b.parent else b.bone.matrix_local
   p[b.name]=[list(row) for row in rest.inverted()@mat]
  frames.append({'time':(frame-1)/60,'poses':p})

 report={'action':rig.animation_data.action.name,'frames':[1,85],'fps':60,'duration':1.4,'bones':len(rig.data.bones),'vertices':len(m.data.vertices),'triangles':len(m.data.polygons),'trimmedVertices':trimmed,'maxRemovedInfluence':maxloss,'maxInfluences':4}
 (out/'fbx-export-report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
except Exception as e:print(repr(e));print(traceback.format_exc())
finally:
 for im,path in imgs:im.filepath=path
 for o in copies:
  data=o.data;bpy.data.objects.remove(o,do_unlink=True)
  if data.users==0:
   if isinstance(data,bpy.types.Mesh):bpy.data.meshes.remove(data)
   else:bpy.data.armatures.remove(data)
 s.frame_start=state['start'];s.frame_end=state['end'];s.frame_set(state['frame'])
 bpy.ops.object.select_all(action='DESELECT')
 for o in state['selection']:o.select_set(True)
 bpy.context.view_layer.objects.active=state['active']
