"""Run in Blender MCP with the original nine Tripo parts open. Preserves source separately."""
import bpy, math, json, os, shutil
from pathlib import Path
from mathutils import Vector, Matrix, Euler
ROOT=Path('/Users/stevin/Documents/Projects/MyChickenArmy')
ART=ROOT/'assets/egg-vacuum'
for sub in ['source','textures','export','preview']: (ART/sub).mkdir(parents=True,exist_ok=True)
assert bpy.data.objects.get('tripo_part_0'), 'Run once against original Tripo scene'
# All art remains unchanged. Apply the imported axis rotation before adding controls.
names={0:'Body',1:'WheelLeft',2:'Nozzle',3:'Hose',4:'Socket',5:'WheelRight',6:'NozzleRight',7:'NozzleLeft',8:'Support'}
parts={}
for i,name in names.items():
    obj=bpy.data.objects['tripo_part_'+str(i)]
    obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
    obj.name=name; parts[name]=obj
for image in bpy.data.images:
    if image.source!='FILE' or not image.filepath: continue
    src=Path(bpy.path.abspath(image.filepath))
    if not src.is_file():continue
    dest=ART/'textures'/src.name
    shutil.copy2(src,dest);image.filepath=str(dest);image.pack()
rig=bpy.data.objects.new('Vacuum_Rig',None);bpy.context.scene.collection.objects.link(rig)
rig.empty_display_type='PLAIN_AXES';rig.empty_display_size=.12
controls={}
pivots={'body':Vector((0,.20,.10)),'nozzle':Vector((0,-.36,.035))}
for group,pivot in pivots.items():
    ctrl=bpy.data.objects.new(group.title()+'_Control',None);bpy.context.scene.collection.objects.link(ctrl)
    ctrl.parent=rig;ctrl.location=pivot;ctrl.empty_display_size=.09
    controls[group]=ctrl
for name in ['Body','Hose','Socket','Nozzle','NozzleLeft','NozzleRight']:
    group='body' if name in ['Body','Hose','Socket'] else 'nozzle'
    obj=parts[name];obj.parent=controls[group];obj.matrix_parent_inverse=controls[group].matrix_world.inverted()
    # Force correct world bind; object coordinates already world authored.
    obj.location=-pivots[group]
    obj.matrix_parent_inverse=Matrix.Identity(4)
for name in ['WheelLeft','WheelRight']:
    obj=parts[name]
    bound=[v.co.copy() for v in obj.data.vertices];pivot=(Vector([min(v[i] for v in bound) for i in range(3)])+Vector([max(v[i] for v in bound) for i in range(3)]))/2
    obj.data.transform(Matrix.Translation(-pivot));obj.location=pivot;obj.parent=rig
    controls[name]=obj;pivots[name]=pivot
parts['Support'].parent=rig
bpy.context.view_layer.update()
SCALE=4.2
C=Matrix(((-1,0,0),(0,0,1),(0,1,0)))
def cv(v): return C@Vector(v)*SCALE
def cf(m):return [round(v,7) for v in [*m.translation,*m.to_3x3()[0],*m.to_3x3()[1],*m.to_3x3()[2]]]
def lua(v):
    if isinstance(v,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(x) for k,x in v.items())+'}'
    if isinstance(v,(tuple,list)):return '{'+','.join(lua(x) for x in v)+'}'
    if isinstance(v,bool):return str(v).lower()
    return json.dumps(v,separators=(',',':'))
# Direct Blender loop-triangle export: preserves split normals/UV seams with no mesh simplification.
payload={'scale':SCALE,'parts':[]}
for name,obj in parts.items():
    mesh=obj.data;mesh.calc_loop_triangles();uv=mesh.uv_layers.active
    mat=obj.active_material
    node=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
    positions=[];normals=[];uvs=[];indices=[]
    world=obj.matrix_world
    for tri in mesh.loop_triangles:
        for li in tri.loops:
            loop=mesh.loops[li];p=cv(world@mesh.vertices[loop.vertex_index].co)
            normal=C@(world.to_3x3()@mesh.corner_normals[li].vector)
            positions.append([round(x,7) for x in p]);normals.append([round(x,7) for x in normal.normalized()])
            tex=uv.data[li].uv;uvs.append([round(tex.x,7),round(1-tex.y,7)]);indices.append(len(indices)+1)
    payload['parts'].append({'name':name,'positions':positions,'normals':normals,'uvs':uvs,'indices':indices,'texture':Path(node.image.filepath).name,'sourceTriangles':len(mesh.loop_triangles)})
(ART/'export/model.json').write_text(json.dumps(payload,separators=(',',':')))
# Named, independently editable actions. Small squash: body <= 5%, nozzle <= 4%.
def sample(kind,t,duration):
    w=t/duration*2*math.pi
    bp=Vector((0,0,0));br=Vector((0,0,0));bs=Vector((1,1,1));np=Vector((0,0,0));nr=Vector((0,0,0));ns=Vector((1,1,1))
    if kind=='Idle':
        breath=(1-math.cos(w))*.5
        bp.z=.003*breath;bs=Vector((1+.004*breath,1+.004*breath,1+.009*breath))
        np.z=.0015*breath
    elif kind=='Move':
        bp.z=.008*(1-math.cos(w*2))*.5;br.y=math.radians(.9)*math.sin(w);br.x=math.radians(1.0)*math.sin(w*2)
        bs.z=1+.007*math.sin(w*2);np.z=.003*(1-math.cos(w*2))*.5
    elif kind=='Suction':
        pulse=math.sin(math.pi*min(1,t/duration))**2
        bp.y=-.008*pulse;bs=Vector((1+.022*pulse,1+.015*pulse,1-.045*pulse))
        np.y=-.009*pulse;ns=Vector((1+.035*pulse,1-.018*pulse,1-.025*pulse))
        nr.x=math.radians(-1.2)*pulse
    elif kind=='Unload':
        pulse=math.sin(math.pi*min(1,t/duration))**2
        br.x=math.radians(5)*pulse;bp.z=.014*pulse
        bs=Vector((1+.014*pulse,1+.012*pulse,1-.032*pulse));np.z=.008*pulse
    return {'body':(bp,br,bs),'nozzle':(np,nr,ns)}
specs={'Idle':(2.4,True),'Move':(.8,True),'Suction':(.5,False),'Unload':(1.0,False)}
clips={};actions={}
scene=bpy.context.scene;scene.render.fps=30
for kind,(duration,looped) in specs.items():
    frames=[]
    for group,obj in controls.items():
        obj.animation_data_clear();obj.animation_data_create()
        action=bpy.data.actions.new('Vacuum_'+kind+'_'+group);action.use_fake_user=True
        obj.animation_data.action=action;actions[kind,group]=action
    for frame in range(round(duration*30)+1):
        t=frame/30;poses=sample(kind,t,duration);record={'time':round(t,6)}
        for group,(p,r,s) in poses.items():
            obj=controls[group];obj.location=pivots[group]+p;obj.rotation_euler=r;obj.scale=s
            for path in ['location','rotation_euler','scale']:obj.keyframe_insert(data_path=path,frame=frame+1)
            rotation=C@Euler(r).to_matrix()@C.transposed();m=rotation.to_4x4();m.translation=cv(p)
            # Axis signs do not affect diagonal scale.
            record[group]={'cf':cf(m),'scale':[round(s.x,7),round(s.z,7),round(s.y,7)]}
        for group in ['WheelLeft','WheelRight']:
            obj=controls[group];obj.location=pivots[group];obj.rotation_euler=( -2*math.pi*t/duration if kind=='Move' else 0,0,0)
            obj.scale=(1,1,1);obj.keyframe_insert(data_path='rotation_euler',frame=frame+1)
        frames.append(record)
    clips[kind]={'duration':duration,'loop':looped,'frames':frames}
clipdata={'fps':30,'sampleSpace':'root-delta','pivots':{k:list(cv(v)) for k,v in pivots.items() if k in ['body','nozzle']},'clips':clips}
(ART/'export/clips.json').write_text(json.dumps(clipdata,separators=(',',':')))
(ROOT/'src/shared/VacuumClips.luau').write_text('-- Blender-authored vacuum poses, 30fps. Re-export using assets/egg-vacuum/tools.\nreturn '+lua(clipdata)+'\n')
# Compose a clearly labelled timeline preview while retaining each named action.
starts={'Idle':1,'Move':91,'Suction':131,'Unload':161}
scene.timeline_markers.clear()
for kind,start in starts.items():scene.timeline_markers.new(kind,frame=start)
for group,obj in controls.items():
    obj.animation_data_clear();obj.animation_data_create()
    track=obj.animation_data.nla_tracks.new();track.name='Vacuum animation showcase'
    for kind,start in starts.items():
        action=actions[kind,group]
        strip=track.strips.new(kind,start,action);strip.extrapolation='NOTHING';strip.blend_type='REPLACE'
scene.frame_start=1;scene.frame_end=191;scene.frame_set(1)
rig['AnimationGuide']='Timeline: Idle 1, Move 91, Suction 131, Unload 161. Named Vacuum_* actions are retained. Runtime wheels use distance.'
# Clean, material-preview framing; user camera/light are retained.
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active;space.shading.type='MATERIAL';space.overlay.show_floor=False
        q=(Vector((1.65,-2.6,1.45))-Vector((0,0,.35))).to_track_quat('Z','Y')
        space.region_3d.view_rotation=q;space.region_3d.view_distance=2.3;space.region_3d.view_location=(0,0,.35)
        space.clip_end=500
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'source/EggVacuum-Animated.blend'))
print(json.dumps({'saved':bpy.data.filepath,'parts':len(parts),'triangles':sum(x['sourceTriangles'] for x in payload['parts']),'clips':list(clips),'actions':len(actions),'sourcePreserved':True}))
