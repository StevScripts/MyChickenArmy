"""Blender MCP authoring: banked swoop over the preserved flight rig."""
import bpy, math, json
import numpy as np
from functools import lru_cache
from pathlib import Path
from mathutils import Matrix
out=Path('/Users/stevin/Documents/Projects/MyChickenArmy/assets/dragon-attack-20261006')
rig=bpy.data.objects['Dragon | Flight Rig']; scene=bpy.context.scene
flight=bpy.data.actions['Dragon Flight | Forward Cupped Wings'];flight.use_fake_user=True
rig.animation_data.action=flight
for p in rig.pose.bones:p.rotation_mode='XYZ'
FPS=60; END=85; CONTACT=33
scene.render.fps=FPS
@lru_cache(None)
def coefficients(keys):
    # C2 Hermite: shared velocity/acceleration at every knot, both zero at handoff.
    x=np.array([k[0] for k in keys],float);y=np.array([k[1] for k in keys],float)
    h=np.diff(x);d=np.diff(y)/h;v=np.zeros(len(x));a=np.zeros(len(x))
    for i in range(1,len(x)-1):
        v[i]=(h[i]*d[i-1]+h[i-1]*d[i])/(h[i-1]+h[i]);a[i]=2*(d[i]-d[i-1])/(h[i-1]+h[i])
    result=[]
    for i,span in enumerate(h):
        c0=y[i];c1=v[i]*span;c2=a[i]*span*span/2
        tail=np.linalg.solve([[1,1,1],[3,4,5],[6,12,20]],[y[i+1]-c0-c1-c2,v[i+1]*span-c1-2*c2,a[i+1]*span*span-2*c2])
        result.append((c0,c1,c2,*tail))
    return x,result

def curve(frame,keys):
    x,c=coefficients(tuple(keys))
    if frame<=x[0]:return keys[0][1]
    if frame>=x[-1]:return keys[-1][1]
    i=min(int(np.searchsorted(x,frame,side='right')-1),len(c)-1);t=(frame-x[i])/(x[i+1]-x[i])
    return sum(value*t**power for power,value in enumerate(c[i]))

def rot(p,angle,axis='X'):
    b=p.bone.matrix_local.to_3x3()
    p.rotation_quaternion=(b.inverted()@Matrix.Rotation(math.radians(angle),3,axis)@b).to_quaternion()@p.rotation_quaternion

def phase(frame):
    u=(frame-1)/(END-1)
    return 1+72*u+12*math.sin(2*math.pi*u)/(2*math.pi)

base={}
for f in range(1,END+1):
    t=phase(f);scene.frame_set(int(t),subframe=t-int(t))
    base[f]={p.name:(p.location.copy(),p.rotation_euler.to_quaternion(),p.scale.copy()) for p in rig.pose.bones}
    for side,sign in [('L',1),('R',-1)]:
        t=phase(f)+sign*1.4*math.sin(math.pi*(f-1)/(END-1))**2
        scene.frame_set(int(t),subframe=t-int(t))
        for p in rig.pose.bones:
            if p.name.startswith('Wing') and p.name.endswith('.'+side):base[f][p.name]=(p.location.copy(),p.rotation_euler.to_quaternion(),p.scale.copy())
name='Dragon Attack | Airborne Strike'
old=bpy.data.actions.get(name)
if old:bpy.data.actions.remove(old)
attack=bpy.data.actions.new(name);attack.use_fake_user=True;rig.animation_data.action=attack
previous={};path=[]
for f in range(1,END+1):
    scene.frame_set(f)
    for p in rig.pose.bones:p.rotation_mode='QUATERNION';p.location,p.rotation_quaternion,p.scale=base[f][p.name]
    root=rig.pose.bones['FlightRoot']
    sideways=curve(f,[(1,0),(18,-.055),(32,.005),(45,.12),(62,.07),(85,0)])
    forward=curve(f,[(1,0),(18,-.04),(32,.16),(43,.29),(60,.13),(85,0)])
    lift=curve(f,[(1,0),(18,.09),(32,.005),(46,-.08),(64,-.018),(85,0)])
    root.location.x+=sideways;root.location.z+=forward;root.location.y+=lift
    bank=curve(f,[(1,0),(14,-9),(30,18),(45,12),(63,-8),(85,0)])
    yaw=curve(f,[(1,0),(15,-10),(30,13),(46,9),(64,-5),(85,0)])
    rot(root,curve(f,[(1,0),(17,-10),(33,26),(45,18),(63,-8),(85,0)]));rot(root,bank,'Y');rot(root,yaw,'Z')
    rot(rig.pose.bones['Body'],curve(f,[(1,0),(20,-4),(36,4),(52,1),(68,-2),(85,0)]));rot(rig.pose.bones['Body'],-.20*yaw,'Z')
    rot(rig.pose.bones['Neck'],curve(f,[(1,0),(16,-5),(31,2),(44,-6),(60,-2),(85,0)]))
    rot(rig.pose.bones['Head'],curve(f,[(1,0),(14,-6),(28,6),(38,-9),(59,-2),(85,0)]));rot(rig.pose.bones['Head'],-.40*bank,'Y')
    rot(rig.pose.bones['Head'],curve(f,[(1,0),(12,-3),(26,4),(38,-5),(59,-2),(85,0)]),'Z')
    rot(rig.pose.bones['Tail'],curve(f,[(1,0),(23,6),(42,-13),(59,5),(85,0)]));rot(rig.pose.bones['Tail'],curve(f,[(1,0),(17,8),(40,-14),(57,7),(85,0)]),'Z')
    for side,factor in [('L',1.18),('R',.82)]:
        rot(rig.pose.bones['WingShoulder.'+side],factor*curve(f,[(1,0),(18,5),(34,-10),(49,-4),(66,2),(85,0)]))
        rot(rig.pose.bones['WingShoulder.'+side],bank*.23,'Y')
        rot(rig.pose.bones['Thigh.'+side],curve(f,[(1,0),(21,7),(39,-10),(55,-4),(72,1),(85,0)]))
        rot(rig.pose.bones['Foot.'+side],curve(f,[(1,0),(23,-4),(42,8),(61,3),(85,0)]))
        rot(rig.pose.bones['Toes.'+side],curve(f,[(1,0),(24,-3),(38,6),(54,2),(85,0)]))
    for p in rig.pose.bones:
        q=p.rotation_quaternion.copy();p.rotation_mode='XYZ';p.rotation_euler=q.to_euler('XYZ',previous.get(p.name,base[f][p.name][1].to_euler('XYZ')));previous[p.name]=p.rotation_euler.copy()
        for channel in ('location','rotation_euler','scale'):p.keyframe_insert(channel,frame=f,group=p.name)
    path.append({'frame':f,'sideways':sideways,'forward':forward,'lift':lift,'bank':bank,'yaw':yaw})
source={(fc.data_path,fc.array_index):fc for l in flight.layers for st in l.strips for bag in st.channelbags for fc in bag.fcurves}
for l in attack.layers:
 for st in l.strips:
  for bag in st.channelbags:
   for fc in bag.fcurves:
    for k in fc.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    original=source.get((fc.data_path,fc.array_index))
    for k,sf in [(fc.keyframe_points[0],1),(fc.keyframe_points[-1],73)]:
     x,y=k.co;v=(original.evaluate(sf+.001)-original.evaluate(sf-.001))/.002 if original else 0
     k.handle_left_type='FREE';k.handle_right_type='FREE';k.handle_left=(x-1/3,y-v/3);k.handle_right=(x+1/3,y+v/3)
for m in list(scene.timeline_markers):scene.timeline_markers.remove(m)
for name,f in [('Flight entry',1),('Rising bank',18),('AttackContact',CONTACT),('Low curved follow-through',46),('Recovery arc',64),('Flight exit',END)]:scene.timeline_markers.new(name,frame=f);attack.pose_markers.new(name).frame=f
attack['Loop']=False;attack['RobloxPriority']='Action';attack['AttackContactSeconds']=(CONTACT-1)/FPS
attack['DurationSeconds']=(END-1)/FPS;attack['Revision']='Curved Swoop v2';attack['CompatibleRig']='Dragon | Flight Rig: original 23-bone bind pose'
scene.frame_start=1;scene.frame_end=END-1;scene.frame_set(CONTACT);scene.name='Galaxy Dragon | Curved Swoop Attack'
(out/'swoop-path.json').write_text(json.dumps(path,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Galaxy-Dragon-Flying-Attack.blend'))
print('Saved C2 curved swoop:',END,'samples; contact frame',CONTACT)
