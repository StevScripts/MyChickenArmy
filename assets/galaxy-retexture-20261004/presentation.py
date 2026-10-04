import bpy,math,json
from mathutils import Vector,Matrix
from pathlib import Path
ROOT=Path('/Users/stevin/.codex/artifacts/galaxy-retexture-20261004')
models=bpy.app.driver_namespace['retexture_models']
scene=bpy.data.scenes.get('GALAXY RETEXTURE | Review')
if scene is None:
    scene=bpy.data.scenes.new('GALAXY RETEXTURE | Review')
    for i,ident in enumerate(('astronaut','alien','dark-matter')):
        c=models[ident]
        col=bpy.data.collections.new('Retexture Review | '+ident)
        for ob in [c['rig']]+c['parts']+c['glass']:col.objects.link(ob)
        inst=bpy.data.objects.new('Review | '+ident,None);inst.instance_type='COLLECTION';inst.instance_collection=col
        inst.location=((i-1)*3.65,0,0);inst.scale=(.67016317,)*3;scene.collection.objects.link(inst)
    mesh=bpy.data.meshes.new('Review floor');mesh.from_pydata([(-20,-15,-.035),(20,-15,-.035),(20,15,-.035),(-20,15,-.035)],[],[(0,1,2,3)])
    floor=bpy.data.objects.new('Review floor',mesh);scene.collection.objects.link(floor)
    material=bpy.data.materials.new('Review navy');material.use_nodes=True
    principled=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED');principled.inputs['Base Color'].default_value=(.018,.028,.051,1);principled.inputs['Roughness'].default_value=.8;floor.data.materials.append(material)
    def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
    for name,loc,power,size,col in [('Key',(-5,-6,9),1400,7,(1,.97,.92)),('Fill',(7,-3,5),1000,6,(.72,.87,1)),('Rim',(0,5,7),1500,5,(.57,.68,1))]:
        data=bpy.data.lights.new('Review '+name,'AREA');data.energy=power;data.size=size;data.color=col
        o=bpy.data.objects.new(data.name,data);scene.collection.objects.link(o);o.location=loc;aim(o,(0,0,1.5))
    data=bpy.data.cameras.new('Review camera');data.type='ORTHO';data.ortho_scale=13.0
    camera=bpy.data.objects.new('Review camera',data);scene.collection.objects.link(camera);camera.location=(6,-30,10);aim(camera,(0,0,1.45));scene.camera=camera
    scene.world=bpy.data.worlds.new('Review world');scene.world.use_nodes=True
    bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.14,.19,.3,1);bg.inputs['Strength'].default_value=.45
    try:scene.render.engine='BLENDER_EEVEE'
    except TypeError:scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.3
    scene.render.resolution_x=1800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=False
bpy.context.window.scene=scene
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL'
scene.render.filepath=str(ROOT/'Galaxy-Retexture-Preview.png')
print('Review scene prepared')
