"""Short, resumable native Blender render job; run via Blender MCP."""
import bpy, json, traceback
from pathlib import Path
from mathutils import Vector

out=Path('/Users/stevin/Documents/Projects/MyChickenArmy/assets/dragon-attack-20261006')
scene=bpy.context.scene
rig=bpy.data.objects['Dragon | Flight Rig']
attack=bpy.data.actions['Dragon Attack | Airborne Strike']
flight=bpy.data.actions['Dragon Flight | Forward Cupped Wings']
camera=scene.camera
framing=json.loads((out/'camera-framing.json').read_text())
scene.render.resolution_x=1200
scene.render.resolution_y=800
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
scene.sync_mode='FRAME_DROP'
jobs=[]
for view in ('three-quarter','side'):
    for label,action in [('flight',flight),('attack',attack)]:
        folder=out/'frames'/view/label
        folder.mkdir(parents=True,exist_ok=True)
        for index,frame in enumerate(range(1,int(action.frame_range[1]),2)):
            jobs.append((view,action,frame,folder/f'{index:03d}.png'))

state={'status':'running','completed':0,'total':len(jobs)}
def progress():
    (out/'render-progress.json').write_text(json.dumps(state,indent=2))

def aim(view):
    data=framing[view]
    camera.location=data['location']
    camera.rotation_euler=data['rotation_euler']
    camera.data.ortho_scale=data['ortho_scale']

def finish():
    rig.animation_data.action=attack
    scene.frame_start=1;scene.frame_end=int(attack.frame_range[1])-1;scene.frame_set(1)
    aim('three-quarter')
    scene.render.filepath=str(out/'Attack-Contact.png')
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)

def render_next():
    try:
        i=state['completed']
        if i>=len(jobs):
            state['status']='complete';progress();finish();return None
        view,action,frame,path=jobs[i]
        aim(view)
        rig.animation_data.action=action
        scene.frame_set(frame)
        scene.render.filepath=str(path)
        bpy.ops.render.render(write_still=True)
        state['completed']+=1
        progress()
        return .05
    except Exception:
        state['status']='error';state['error']=traceback.format_exc();progress();finish()
        return None

bpy.app.driver_namespace['dragon_attack_render_tick']=render_next
bpy.app.timers.register(render_next,first_interval=.1)
progress()
print('Native render timer started:',len(jobs),'frames, 30fps output')
