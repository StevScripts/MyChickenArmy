"""Run through Blender MCP in the saved attack copy, preserving the flight action."""
import bpy
import math
from mathutils import Matrix, Vector

rig = bpy.data.objects['Dragon | Flight Rig']
scene = bpy.context.scene
flight = bpy.data.actions['Dragon Flight | Forward Cupped Wings']
flight.use_fake_user = True
rig.animation_data.action = flight
scene.render.fps = 60
for pose in rig.pose.bones:
    pose.rotation_mode = 'XYZ'

# Shape-preserving cubic curves. This is offline skeletal authoring, not game code.
def curve(frame, keys):
    xs, ys = zip(*keys)
    if frame <= xs[0]: return ys[0]
    if frame >= xs[-1]: return ys[-1]
    h = [xs[i+1]-xs[i] for i in range(len(xs)-1)]
    d = [(ys[i+1]-ys[i])/h[i] for i in range(len(h))]
    tangents = [0.0]
    for i in range(1,len(xs)-1):
        if d[i-1]*d[i] <= 0: tangents.append(0.0)
        else:
            w1, w2 = 2*h[i]+h[i-1], h[i]+2*h[i-1]
            tangents.append((w1+w2)/(w1/d[i-1]+w2/d[i]))
    tangents.append(0.0)
    i = next(i for i in range(len(h)) if frame <= xs[i+1])
    t = (frame-xs[i])/h[i]
    return ((2*t**3-3*t*t+1)*ys[i] + (t**3-2*t*t+t)*h[i]*tangents[i]
            +(-2*t**3+3*t*t)*ys[i+1]+(t**3-t*t)*h[i]*tangents[i+1])

def radians_curve(frame, keys):
    return math.radians(curve(frame, keys))

base = {}
previous_euler = {}
for frame in range(1,74):
    scene.frame_set(frame)
    base[frame] = {p.name:(p.location.copy(),p.rotation_euler.to_quaternion(),p.scale.copy()) for p in rig.pose.bones}

name = 'Dragon Attack | Airborne Strike'
previous = bpy.data.actions.get(name)
if previous:
    if rig.animation_data.action == previous: rig.animation_data.action = None
    bpy.data.actions.remove(previous)
attack = bpy.data.actions.new(name)
attack.use_fake_user = True
rig.animation_data.action = attack

def rotate_rest_axis(pose, angle, axis='X'):
    basis = pose.bone.matrix_local.to_3x3()
    delta = basis.inverted() @ Matrix.Rotation(angle,3,axis) @ basis
    pose.rotation_quaternion = delta.to_quaternion() @ pose.rotation_quaternion

for frame in range(1,74):
    scene.frame_set(frame)
    for pose in rig.pose.bones:
        loc, quat, scale = base[frame][pose.name]
        pose.rotation_mode = 'QUATERNION'
        pose.location, pose.rotation_quaternion, pose.scale = loc, quat, scale
    root = rig.pose.bones['FlightRoot']
    root.location.z += curve(frame,[(1,0),(15,-.065),(27,.215),(33,.23),(50,.035),(65,0),(73,0)])
    root.location.y += curve(frame,[(1,0),(15,.018),(27,-.018),(38,-.012),(54,.006),(65,0),(73,0)])
    rotate_rest_axis(root,radians_curve(frame,[(1,0),(15,-18),(27,36),(33,30),(49,-5),(65,0),(73,0)]))
    rotate_rest_axis(rig.pose.bones['Body'],radians_curve(frame,[(1,0),(16,-4),(28,4),(37,2),(52,-2),(65,0),(73,0)]))
    rotate_rest_axis(rig.pose.bones['Neck'],radians_curve(frame,[(1,0),(17,-9),(25,-3),(30,-6),(44,-10),(62,0),(73,0)]))
    rotate_rest_axis(rig.pose.bones['Head'],radians_curve(frame,[(1,0),(17,-9),(27,3),(34,-8),(47,-5),(61,0),(73,0)]))
    rotate_rest_axis(rig.pose.bones['Tail'],radians_curve(frame,[(1,0),(19,6),(32,-14),(44,-6),(57,3),(68,0),(73,0)]))
    for side in ('L','R'):
        # Keep the approved membrane curve; shoulders counter the body's dive.
        rotate_rest_axis(rig.pose.bones['WingShoulder.'+side],radians_curve(frame,[(1,0),(16,7),(28,-15),(38,-11),(53,3),(66,0),(73,0)]))
        rotate_rest_axis(rig.pose.bones['Thigh.'+side],radians_curve(frame,[(1,0),(17,8),(30,-12),(43,-5),(60,0),(73,0)]))
        rotate_rest_axis(rig.pose.bones['Foot.'+side],radians_curve(frame,[(1,0),(18,-5),(32,10),(45,5),(63,0),(73,0)]))
        rotate_rest_axis(rig.pose.bones['Toes.'+side],radians_curve(frame,[(1,0),(17,-4),(28,8),(40,3),(61,0),(73,0)]))
    for pose in rig.pose.bones:
        q = pose.rotation_quaternion.copy()
        pose.rotation_mode = 'XYZ'
        pose.rotation_euler = q.to_euler('XYZ', previous_euler.get(pose.name, base[frame][pose.name][1].to_euler('XYZ')))
        previous_euler[pose.name] = pose.rotation_euler.copy()
        pose.keyframe_insert('location',frame=frame,group=pose.name)
        pose.keyframe_insert('rotation_euler',frame=frame,group=pose.name)
        pose.keyframe_insert('scale',frame=frame,group=pose.name)

flight_curves = {(fc.data_path,fc.array_index):fc
    for layer in flight.layers for strip in layer.strips
    for bag in strip.channelbags for fc in bag.fcurves}
for layer in attack.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for fc in bag.fcurves:
                for key in fc.keyframe_points:
                    key.interpolation='BEZIER'
                    key.handle_left_type='AUTO_CLAMPED'
                    key.handle_right_type='AUTO_CLAMPED'
                # Preserve the moving flight tangent at both handoff boundaries.
                source = flight_curves.get((fc.data_path,fc.array_index))
                for key in (fc.keyframe_points[0],fc.keyframe_points[-1]):
                    x,y=key.co
                    velocity=(source.evaluate(x+.001)-source.evaluate(x-.001))/.002 if source else 0.0
                    key.handle_left_type='FREE';key.handle_right_type='FREE'
                    key.handle_left=(x-1/3,y-velocity/3)
                    key.handle_right=(x+1/3,y+velocity/3)

for marker in list(scene.timeline_markers): scene.timeline_markers.remove(marker)
for name, frame in [('Flight entry',1),('Anticipation',15),('AttackContact',27),('Follow through',33),('Recovery',49),('Flight exit',73)]:
    scene.timeline_markers.new(name,frame=frame)
    attack.pose_markers.new(name).frame=frame
attack['Loop'] = False
attack['RobloxPriority'] = 'Action'
attack['AttackContactSeconds'] = 26/60
attack['DurationSeconds'] = 1.2
attack['CompatibleRig'] = 'Dragon | Flight Rig: 23 bones, original bind pose'
scene.frame_start=1
scene.frame_end=72
scene.frame_set(27)
scene.name='Galaxy Dragon | Flying Attack'
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('Authored',attack.name,'73 samples at 60fps; contact frame27; flight action preserved')
