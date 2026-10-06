"""Evaluate current Blender attack, check handoff, and fit review cameras."""
import bpy,json,math
import numpy as np
from pathlib import Path
from mathutils import Vector
out=Path('/Users/stevin/Documents/Projects/MyChickenArmy/assets/dragon-attack-20261006')
s=bpy.context.scene;r=bpy.data.objects['Dragon | Flight Rig'];m=bpy.data.objects['Dragon | Skinned mesh'];c=s.camera
attack=bpy.data.actions['Dragon Attack | Airborne Strike'];flight=bpy.data.actions['Dragon Flight | Forward Cupped Wings']
end=int(attack.frame_range[1]);fps=s.render.fps
bones=[{'name':b.name,'parent':b.parent.name if b.parent else None,'rest':[list(row) for row in b.matrix_local]} for b in r.data.bones]
frames=[];worldpoints=[];endpoint=[]
r.animation_data.action=attack
for f in range(1,end+1):
 s.frame_set(f);poses={}
 for b in r.pose.bones:
  mat=b.parent.matrix.inverted()@b.matrix if b.parent else b.matrix
  rest=b.bone.parent.matrix_local.inverted()@b.bone.matrix_local if b.parent else b.bone.matrix_local
  poses[b.name]=[list(row) for row in rest.inverted()@mat]
 frames.append({'time':(f-1)/fps,'poses':poses})
 if f in (1,end):endpoint.append({b.name:b.matrix.copy() for b in r.pose.bones})
 ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();a=np.empty(len(me.vertices)*3,dtype=np.float32);me.vertices.foreach_get('co',a);mw=np.array(ev.matrix_world)
 worldpoints.append(a.reshape(-1,3)@mw[:3,:3].T+mw[:3,3]);ev.to_mesh_clear()
(out/'attack-cycle.json').write_text(json.dumps({'name':'Attack','revision':'Forward Swoop v3','fps':fps,'duration':(end-1)/fps,'loop':False,'priority':'Action','markers':[{'name':'AttackContact','time':attack['AttackContactSeconds']}],'bones':bones,'frames':frames}))
r.animation_data.action=flight;s.frame_set(1)
flight_entry={b.name:b.matrix.copy() for b in r.pose.bones}
for f in range(1,74):
 s.frame_set(f);ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();a=np.empty(len(me.vertices)*3,dtype=np.float32);me.vertices.foreach_get('co',a);mw=np.array(ev.matrix_world)
 worldpoints.append(a.reshape(-1,3)@mw[:3,:3].T+mw[:3,3]);ev.to_mesh_clear()
points=np.concatenate(worldpoints);framing={}
for view,loc in [('three-quarter',(1.7,-2.8,1.35)),('side',(2.8,-.6,1.05))]:
 c.location=loc;c.rotation_euler=(Vector((0,-.15,.53))-c.location).to_track_quat('-Z','Y').to_euler();rot=np.array(c.rotation_euler.to_matrix())
 projected=(points-np.array(c.location))@rot;lo=projected[:,:2].min(axis=0);hi=projected[:,:2].max(axis=0);center=(lo+hi)/2
 c.location+=c.rotation_euler.to_matrix()@Vector((float(center[0]),float(center[1]),0))
 scale=max(float(hi[0]-lo[0]),float(hi[1]-lo[1])*1.5)*1.20;c.data.ortho_scale=scale
 framing[view]={'location':list(c.location),'rotation_euler':list(c.rotation_euler),'ortho_scale':scale,'minimum_edge_margin_fraction':1/12}
(out/'camera-framing.json').write_text(json.dumps(framing,indent=2))
error=lambda left,right:max(abs(left[n][i][j]-right[n][i][j]) for n in left for i in range(4) for j in range(4))
path=json.loads((out/'swoop-path.json').read_text());positions=np.array([[x['sideways'],x['forward'],x['lift']] for x in path]);velocity=np.diff(positions,axis=0)*fps
report={'revision':'Forward Swoop v3','fps':fps,'samples':end,'duration':(end-1)/fps,'attackEntryExitMaxDifference':error(endpoint[0],endpoint[1]),'attackVsFlightHandoffMaxDifference':error(endpoint[0],flight_entry),'finiteVerticesAllFrames':bool(np.isfinite(points).all()),'boneCount':len(bones),'contactSeconds':attack['AttackContactSeconds'],'sidewaysArcRange':float(np.ptp(positions[:,0])),'verticalArcRange':float(np.ptp(positions[:,2])),'minRootPathSpeedAroundContactFrames29to39':float(np.linalg.norm(velocity[28:39],axis=1).min()),'forwardPeakFrame':int(positions[:,1].argmax()+1),'lowestArcFrame':int(positions[:,2].argmin()+1)}
(out/'animation-check.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
r.animation_data.action=attack;s.frame_start=1;s.frame_end=end-1;s.frame_set(1)
data=framing['three-quarter'];c.location=data['location'];c.rotation_euler=data['rotation_euler'];c.data.ortho_scale=data['ortho_scale']
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Galaxy-Dragon-Flying-Attack.blend'))
