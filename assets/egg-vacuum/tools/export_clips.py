"""Run inside the animated Blender file after editing its named Vacuum_* actions.
Exports the exact edited body/nozzle poses to shared/VacuumClips.luau.
"""
import bpy, json
from pathlib import Path
from mathutils import Matrix, Vector
ROOT=Path('/Users/stevin/Documents/Projects/MyChickenArmy')
ART=ROOT/'assets/egg-vacuum'
C=Matrix(((-1,0,0),(0,0,1),(0,1,0)))
SCALE=4.2
PIVOTS={'body':Vector((0,.20,.10)), 'nozzle':Vector((0,-.36,.035))}
def convert(v):return C@Vector(v)*SCALE
def lua(v):
 if isinstance(v,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(x) for k,x in v.items())+'}'
 if isinstance(v,(list,tuple)):return '{'+','.join(map(lua,v))+'}'
 if isinstance(v,bool):return str(v).lower()
 return json.dumps(v,separators=(',',':'))
scene=bpy.context.scene;oldframe=scene.frame_current;states=[]
controls={g:bpy.data.objects[g.title()+'_Control'] for g in PIVOTS}
clips={}
try:
 for obj in controls.values():
  ad=obj.animation_data
  states.append((obj,ad.action,ad.action_slot,[t.mute for t in ad.nla_tracks]))
  for track in ad.nla_tracks:track.mute=True
 for name in ['Idle','Move','Suction','Unload']:
  actions={g:bpy.data.actions['Vacuum_'+name+'_'+g] for g in controls}
  duration=(max(a.frame_range.y for a in actions.values())-1)/30
  for group,obj in controls.items():
   obj.animation_data.action=actions[group]
   obj.animation_data.action_slot=actions[group].slots[0]
  frames=[]
  for frame in range(round(duration*30)+1):
   scene.frame_set(frame+1);data={'time':round(frame/30,6)}
   for group,obj in controls.items():
    rot=C@obj.rotation_euler.to_matrix()@C.transposed()
    m=rot.to_4x4();m.translation=convert(obj.location-PIVOTS[group])
    data[group]={'cf':[round(v,7) for v in [*m.translation,*m.to_3x3()[0],*m.to_3x3()[1],*m.to_3x3()[2]]],
     'scale':[round(obj.scale.x,7),round(obj.scale.z,7),round(obj.scale.y,7)]}
   frames.append(data)
  clips[name]={'duration':duration,'loop':name in ('Idle','Move'),'frames':frames}
 data={'fps':30,'sampleSpace':'root-delta','pivots':{g:list(convert(p)) for g,p in PIVOTS.items()},'clips':clips}
 (ART/'export/clips.json').write_text(json.dumps(data,separators=(',',':')))
 (ROOT/'src/shared/VacuumClips.luau').write_text('-- Blender-authored vacuum poses, 30fps. Re-export using assets/egg-vacuum/tools.\nreturn '+lua(data)+'\n')
 print('Exported four edited Blender clips to src/shared/VacuumClips.luau')
finally:
 for obj,action,slot,mutes in states:
  obj.animation_data.action=action
  if action and slot:obj.animation_data.action_slot=slot
  for track,mute in zip(obj.animation_data.nla_tracks,mutes):track.mute=mute
 scene.frame_set(oldframe)
