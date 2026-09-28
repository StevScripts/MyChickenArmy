"""Eight approved chicken traits. Run in live Blender via MCP, in ordered stages.
All geometry is authored here; source anatomy and skeleton are appended unchanged.
No user objects are removed. Surface patterns use mesh material regions, not external textures.
"""
import bpy, bmesh, math, json, random
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
from mathutils import noise

OUT = Path('/Users/stevin/.codex/artifacts/chicken-traits-approved8')
SOURCE = bpy.data.scenes['Cute_Chicken_Reference']
SOURCE_RIG = bpy.data.objects['Chicken_Master_Rig']
MODELS = {}

def lin(v):
    return v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4

def material(name, color, rough=.32, metal=0, glow=0, transmission=0):
    m=bpy.data.materials.new('T8 | '+name)
    m.use_nodes=True
    rgb=tuple(lin(int(color[i:i+2],16)/255) for i in (0,2,4))
    m.diffuse_color=(*rgb,1)
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=metal
    p.inputs['Coat Weight'].default_value=.25
    p.inputs['Transmission Weight'].default_value=transmission
    p.inputs['Emission Color'].default_value=(*rgb,1)
    p.inputs['Emission Strength'].default_value=glow
    return m

M={}
for name,col,r,mt,g in [
 ('Eye','11131E',.25,0,0),('Glint','FFFFFF',.3,0,.08),
 ('Pink','FF168A',.22,0,0),('Cream','FFF4DB',.25,0,0),('CandyCyan','00DBED',.22,0,0),
 ('Yellow','FFCE16',.3,0,0),('Orange','FF9212',.32,0,0),('Red','F82637',.32,0,0),
 ('HoneyRim','FFBF16',.23,.1,.05),('Honey','F59A08',.2,0,0),('HoneyDeep','CE6103',.27,0,0),('HoneyLight','FFD842',.2,0,0),
 ('Lime','B8FF00',.24,0,.16),('LimeLight','DFFF25',.22,0,.2),('LimeDark','6CDF03',.3,0,.03),('Crust','351342',.6,0,0),('CrustLight','632879',.55,0,0),
 ('Water','047DFF',.2,.03,.04),('Aqua','07CBF5',.2,.03,.04),('WaterLight','57EBFF',.2,.02,.05),('DeepBlue','0836CB',.24,0,0),('Foam','DEFCFF',.3,0,.03),
 ('SunCore','FFEC57',.3,0,.55),('SunYellow','FFCD12',.32,0,.4),('SunOrange','FF8B0D',.35,0,.25),('SunEdge','FF6206',.32,0,.13),
 ('Pearl','FFF9EC',.28,.1,0),('PearlShade','C8F2F4',.3,.05,0),('Sky','6BDCFA',.23,.05,.05),('Gold','FFC23C',.25,.5,0),
 ('Scarlet','F92035',.32,0,0),('Crimson','D91430',.4,0,0),('Membrane','9F0D2D',.4,0,0),('Horn','2D1739',.38,.12,0),
 ('Leaf','168B42',.42,0,0),('LeafLight','43BA46',.4,0,0),('Emerald','096437',.44,0,0),('LeafVein','C2EE35',.35,0,0),('JungleHead','A0DC33',.4,0,0),('Flower','FF1F9A',.32,0,0)
]: M[name]=material(name,col,r,mt,g)

def rawmesh(name,verts,faces,mats,inds=None,smooth=False):
    mesh=bpy.data.meshes.new(name+' Mesh')
    mesh.from_pydata(verts,[],faces);mesh.update()
    for m in mats: mesh.materials.append(m)
    if inds:
        for p,idx in zip(mesh.polygons,inds): p.material_index=idx
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    for p in mesh.polygons:p.use_smooth=smooth
    return mesh

def addmesh(ctx,name,verts,faces,mats,inds=None,bone='Body',bevel=0,smooth=False):
    obj=bpy.data.objects.new(ctx['name']+' | '+name,rawmesh(name,verts,faces,mats,inds,smooth))
    ctx['collection'].objects.link(obj)
    obj.parent=ctx['rig']
    obj['attachment_bone']=bone
    if bevel:
        b=obj.modifiers.new('Tiny toy edge bevel','BEVEL');b.width=bevel;b.segments=2;b.limit_method='ANGLE'
    group=obj.vertex_groups.new(name=bone);group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
    mod=obj.modifiers.new('Rigid master skeleton','ARMATURE');mod.object=ctx['rig']
    ctx['parts'].append(obj)
    return obj

def box(ctx,name,center,size,mat,bone='Body',bevel=.025):
    x,y,z=center;a,b,c=[v/2 for v in size]
    verts=[(x+sx*a,y+sy*b,z+sz*c) for sx,sy,sz in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
    faces=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
    return addmesh(ctx,name,verts,faces,[mat],bone=bone,bevel=bevel)

def extrude(ctx,name,polygon,depth,center,mat,bone='Body',u=(1,0,0),v=(0,0,1),bevel=.02,side_mat=None):
    C,U,V=Vector(center),Vector(u),Vector(v);N=U.cross(V).normalized()
    verts=[tuple(C+U*x+V*y+N*d) for d in (-depth/2,depth/2) for x,y in polygon]
    n=len(polygon);faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mats=[mat] if side_mat is None else [mat,side_mat]
    inds=[0,0]+[1 if side_mat else 0]*n
    return addmesh(ctx,name,verts,faces,mats,inds,bone,bevel)

def tube(ctx,name,points,radii,mat,bone='Body',sides=8,closed=False):
    pts=[Vector(p) for p in points]
    if isinstance(radii,(int,float)):radii=[radii]*len(pts)
    verts=[];previous_u=None
    for j,p in enumerate(pts):
        d=(pts[(j+1)%len(pts)]-pts[j-1 if j>0 else (len(pts)-1 if closed else 0)]) if (closed or j<len(pts)-1) else (p-pts[j-1])
        d.normalize()
        if previous_u is None:
            ref=Vector((1,0,0)) if abs(d.x)<.9 else Vector((0,1,0))
            u=d.cross(ref).normalized()
        else:
            u=(previous_u-d*previous_u.dot(d)).normalized()
        v=d.cross(u).normalized();previous_u=u
        for k in range(sides):verts.append(tuple(p+radii[j]*(u*math.cos(2*math.pi*k/sides)+v*math.sin(2*math.pi*k/sides))))
    faces=[]
    for j in range(len(pts) if closed else len(pts)-1):
        for k in range(sides):faces.append((j*sides+k,j*sides+(k+1)%sides,((j+1)%len(pts))*sides+(k+1)%sides,((j+1)%len(pts))*sides+k))
    if not closed:faces.extend([tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+k for k in range(sides))])
    return addmesh(ctx,name,verts,faces,[mat],bone=bone,smooth=True)

def ball(ctx,name,center,radius,mat,bone='Body',seg=12,rings=6):
    verts=[];faces=[];C=Vector(center)
    for j in range(rings+1):
        a=math.pi*j/rings
        for i in range(seg):
            t=2*math.pi*i/seg;verts.append(tuple(C+Vector((math.sin(a)*math.cos(t),math.sin(a)*math.sin(t),math.cos(a)))*radius))
    for j in range(rings):
        for i in range(seg):faces.append((j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,(j+1)*seg+i))
    return addmesh(ctx,name,verts,faces,[mat],bone=bone,smooth=True)

def bone_for(name):
    if name.startswith('Eye'):return 'Head'
    if name.startswith('Toe_'):return 'Foot_'+name.split('_')[1]
    return name

def bounds(obj):
    pts=[obj.matrix_world@Vector(p) for p in obj.bound_box]
    return [(min(p[i] for p in pts),max(p[i] for p in pts)) for i in range(3)]

BASE={o.name[5:]:bounds(o) for o in SOURCE.objects if o.type=='MESH' and o.name.startswith('Cute_')}

def faces_of_box(bb):
    for normal_axis in range(3):
        ax=[i for i in range(3) if i!=normal_axis]
        for side in (0,1):
            origin=Vector((0,0,0));origin[normal_axis]=bb[normal_axis][side];origin[ax[0]]=bb[ax[0]][0];origin[ax[1]]=bb[ax[1]][0]
            U=Vector((0,0,0));U[ax[0]]=1;V=Vector((0,0,0));V[ax[1]]=1
            yield origin,U,V,bb[ax[0]][1]-bb[ax[0]][0],bb[ax[1]][1]-bb[ax[1]][0],normal_axis,side

def painted_box(ctx,name,bb,mats,paint,bone,step=.22):
    verts=[];faces=[];inds=[]
    for O,U,V,w,h,axis,side in faces_of_box(bb):
        nx=max(1,round(w/step));ny=max(1,round(h/step))
        for i in range(nx):
            for j in range(ny):
                coords=[(i*w/nx,j*h/ny),((i+1)*w/nx,j*h/ny),((i+1)*w/nx,(j+1)*h/ny),(i*w/nx,(j+1)*h/ny)]
                index=len(verts);verts.extend(tuple(O+U*x+V*y) for x,y in coords);faces.append(tuple(range(index,index+4)))
                P=O+U*((i+.5)*w/nx)+V*((j+.5)*h/ny);inds.append(paint(P,axis,side))
    return addmesh(ctx,name,verts,faces,mats,inds,bone,.018)

def striped_box(ctx,name,bb,bone):
    verts=[];faces=[];inds=[];width=.26
    def clip(poly,limit,lower):
        out=[]
        for a,b in zip(poly,poly[1:]+poly[:1]):
            va=sum(a)-limit;vb=sum(b)-limit;ina=va>=-1e-8 if lower else va<=1e-8;inb=vb>=-1e-8 if lower else vb<=1e-8
            if ina:out.append(a)
            if ina!=inb:
                t=va/(va-vb);out.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
        return out
    for O,U,V,w,h,axis,side in faces_of_box(bb):
        for i in range(-1,math.ceil((w+h)/width)+1):
            p=clip(clip([(0,0),(w,0),(w,h),(0,h)],i*width,True),(i+1)*width,False)
            if len(p)<3:continue
            n=len(verts);verts.extend(tuple(O+U*x+V*y) for x,y in p);faces.append(tuple(range(n,n+len(p))));inds.append(i%4)
    return addmesh(ctx,name,verts,faces,[M['Pink'],M['Cream'],M['CandyCyan'],M['Cream']],inds,bone,.017)

def begin(id,name,bodymat,headmat=None,beakmat=None,wattlemat=None,legmat=None,wings=True,paint=None,stripes=False):
    assert 'T8 '+name not in bpy.data.collections,'Already built: '+name
    col=bpy.data.collections.new('T8 '+name)
    scene=bpy.data.scenes.new('TRAIT | '+name);scene.collection.children.link(col)
    scene.world=SOURCE.world.copy();scene.render.engine=SOURCE.render.engine
    # Standard is present in this installed Blender's active OCIO view configuration.
    scene.view_settings.view_transform='Standard'
    scene.eevee.taa_render_samples=32
    scene.render.resolution_x=1000;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    rig=SOURCE_RIG.copy();rig.data=SOURCE_RIG.data.copy();rig.animation_data_clear();rig.name=name+' | Master Rig'
    col.objects.link(rig);rig.data.pose_position='REST';rig.show_in_front=True
    for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
    ctx={'id':id,'name':name,'collection':col,'scene':scene,'rig':rig,'parts':[]}
    MODELS[id]=ctx
    for name,bb in BASE.items():
        if name.startswith('Wing') and not wings:continue
        bone=bone_for(name)
        if name.startswith('Eye_Highlight'):mat=M['Glint']
        elif name.startswith('Eye'):mat=M['Eye']
        elif name=='Beak':mat=beakmat or M['Yellow']
        elif name=='Wattle':mat=wattlemat or M['Red']
        elif name.startswith(('Leg','Foot','Toe')):mat=legmat or M['Orange']
        else:mat=(headmat or bodymat) if name=='Head' else bodymat
        if name in ['Body','Head','Neck','Wing_L','Wing_R']:
            if stripes:striped_box(ctx,name,bb,bone);continue
            if paint:painted_box(ctx,name,bb,*paint,bone);continue
        center=tuple((a+b)/2 for a,b in bb);size=tuple(b-a for a,b in bb)
        box(ctx,name,center,size,mat,bone,.004 if name.startswith('Eye') else .022)
    bpy.context.window.scene=scene
    return ctx

def spiral_disc(ctx,name,center,r,depth,bone,u,v):
    C,U,V=Vector(center),Vector(u),Vector(v);N=U.cross(V).normalized()
    n=24;rings=12;verts=[];faces=[];inds=[]
    for side in (-1,1):
        off=len(verts)
        for j in range(rings+1):
            for k in range(n):
                rr=r*j/rings;t=2*math.pi*k/n+2*math.pi*1.15*j/rings
                verts.append(tuple(C+U*(rr*math.cos(t))+V*(rr*math.sin(t))+N*(side*(depth/2+.025*math.sin(math.pi*j/rings)))))
        for j in range(rings):
            for k in range(n):
                faces.append((off+j*n+k,off+j*n+(k+1)%n,off+(j+1)*n+(k+1)%n,off+(j+1)*n+k))
                inds.append(k//(n//3))
    off=(rings+1)*n
    for k in range(n):faces.append((rings*n+k,rings*n+(k+1)%n,off+rings*n+(k+1)%n,off+rings*n+k));inds.append(k//(n//3))
    return addmesh(ctx,name,verts,faces,[M['Pink'],M['Cream'],M['CandyCyan']],inds,bone,smooth=True)

def drop(ctx,name,top,length,mat,bone='Body',radius=.10):
    x,y,z=top
    pts=[(x,y,z),(x,y,z-length*.3),(x,y,z-length*.64),(x,y,z-length*.84),(x,y,z-length)]
    return tube(ctx,name,pts,[radius*.7,radius*.6,radius*.65,radius,.015],mat,bone,10)

def beam(ctx,name,start,end,width,depth,mat,bone='Body',edge=None):
    A,B=Vector(start),Vector(end);D=(B-A).normalized();N=Vector((0,1,0));U=N.cross(D).normalized();N=D.cross(U).normalized()
    V=[]
    for p,w in [(A,width*.7),(B-D*.10,width),(B,width*.55)]:
        for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]:V.append(tuple(p+U*w*.5*sx+N*depth*.5*sy))
    F=[(3,2,1,0),(8,9,10,11)]+[(j*4+k,j*4+(k+1)%4,(j+1)*4+(k+1)%4,(j+1)*4+k) for j in range(2) for k in range(4)]
    return addmesh(ctx,name,V,F,[mat,edge or mat],[1,1]+[0,1,0,1]*2,bone,.018)

def leaf(ctx,name,start,end,width,mat,bone='Body',normal=(0,-1,0),vein=True):
    A,B=Vector(start),Vector(end);D=B-A;N=Vector(normal).normalized();U=D.cross(N).normalized()
    verts=[tuple(A),tuple(A+D*.28-U*width*.5),tuple(A+D*.66-U*width*.40),tuple(B),tuple(A+D*.66+U*width*.40),tuple(A+D*.28+U*width*.5),tuple(A+D*.48+N*.13)]
    verts += [tuple(Vector(p)-N*.12) for p in verts[:6]]
    faces=[(i,(i+1)%6,6) for i in range(6)]+[tuple(range(12,6,-1))]+[(i,7+i,7+(i+1)%6,(i+1)%6) for i in range(6)]
    obj=addmesh(ctx,name,verts,faces,[mat,M['LeafLight'] if mat!=M['Flower'] else mat],[i%2 for i in range(6)]+[0]*7,bone,.008)
    if vein:tube(ctx,name+' central vein',[tuple(A+N*.08),tuple(A+D*.48+N*.15),tuple(B+N*.02)],[.028,.028,.008],M['LeafVein'],bone,5)
    return obj

def socket(ctx,name,point,bone):
    obj=bpy.data.objects.new(ctx['name']+' | FX_'+name,None);ctx['collection'].objects.link(obj)
    obj.empty_display_type='PLAIN_AXES';obj.empty_display_size=.12;obj.parent=ctx['rig'];obj.parent_type='BONE';obj.parent_bone=bone
    bpy.context.view_layer.update();obj.matrix_world=Matrix.Translation(Vector(point));obj['purpose']='Suggested runtime VFX attachment; no particle simulation authored'
    return obj

def studio(ctx):
    s=ctx['scene'];bpy.context.window.scene=s
    for original in SOURCE.objects:
        if original.type not in ('LIGHT','CAMERA'):continue
        obj=original.copy();obj.data=original.data.copy();obj.name=ctx['name']+' Studio '+original.name;s.collection.objects.link(obj)
        if original.type=='CAMERA':
            obj.data.type='ORTHO';obj.data.ortho_scale=7.1;obj.location=(8,-13,8)
            obj.rotation_euler=(Vector((0,-.05,2.5))-obj.location).to_track_quat('-Z','Y').to_euler();s.camera=obj
        else:obj.data.energy*=.75
    floor=box({'name':ctx['name'],'collection':s.collection,'rig':ctx['rig'],'parts':[]},'Preview floor',(0,0,-.095),(200,200,.15),M['PearlShade'],'Root',0)
    floor.parent=None;floor.modifiers.clear();floor.vertex_groups.clear();floor['preview_only']=True
    floor.data.materials.clear();floor.data.materials.append(STUDIO_MAT)
    for n in s.world.node_tree.nodes:
        if n.type=='BACKGROUND':n.inputs['Color'].default_value=(.25,.32,.42,1);n.inputs['Strength'].default_value=.55
    socket(ctx,'Head',(0,-.9,4.65),'HatSocket');socket(ctx,'Chest',(0,-1.28,1.9),'ChestSocket')
    socket(ctx,'Trail',(0,1.65,1.9),'BackSocket')
    for side,sign in [('L',-1),('R',1)]:socket(ctx,'Wing_'+side,(sign*1.5,0,2.2),'Wing_'+side)
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.region_3d.view_camera_zoom=10
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False
    return ctx

STUDIO_MAT=material('Studio slate','BCCBD9',.8)

def build_lollipop():
    c=begin('lollipop','Lollipop',M['Pink'],beakmat=M['Yellow'],legmat=M['Yellow'],wings=False,stripes=True)
    for sign,side in [(-1,'L'),(1,'R')]:spiral_disc(c,'Spiral candy wing '+side,(sign*1.22,.05,2.0),.83,.24,'Wing_'+side,(0,1,0),(0,0,1))
    spiral_disc(c,'Spiral candy tail',(0,1.52,3.15),.90,.23,'BackSocket',(1,0,0),(0,0,1))
    spiral_disc(c,'Candy curl comb',(0,-.88,4.61),.39,.24,'Head',(0,1,0),(0,0,1))
    return studio(c)

def honey_cells(ctx,name,bb,bone):
    verts=[];faces=[];inds=[];rad=.26
    for O,U,V,w,h,axis,side in faces_of_box(bb):
        if min(w,h)<.6:continue
        N=Vector((0,0,0));N[axis]=-1 if side==0 else 1
        for j in range(int(h/(rad*1.5))+1):
            cy=rad+j*rad*1.5
            for i in range(int(w/(rad*math.sqrt(3)))+1):
                cx=rad*.9+i*rad*math.sqrt(3)+(j%2)*rad*math.sqrt(3)/2
                if cx+rad*.88>w-.025 or cy+rad>h-.025:continue
                C=O+U*cx+V*cy
                start=len(verts)
                for r,d in [(rad*.99,.055),(rad*.78,.057),(rad*.7,.007)]:
                    for k in range(6):
                        t=math.pi/6+k*math.pi/3;verts.append(tuple(C+U*(r*math.cos(t))+V*(r*math.sin(t))+N*d))
                for ring in range(2):
                    for k in range(6):faces.append((start+ring*6+k,start+ring*6+(k+1)%6,start+(ring+1)*6+(k+1)%6,start+(ring+1)*6+k));inds.append(ring)
                faces.append(tuple(start+12+k for k in range(6)));inds.append(2+(i+j)%2)
    return addmesh(ctx,name,verts,faces,[M['HoneyRim'],M['Honey'],M['HoneyDeep'],M['Honey']],inds,bone)

def build_honeycomb():
    c=begin('honeycomb','Honeycomb',M['HoneyRim'],beakmat=M['HoneyLight'],legmat=M['Honey'],wattlemat=M['Orange'])
    for obj in c['parts']:
        if ' | Eye' in obj.name:
            for vertex in obj.data.vertices:vertex.co.y-=.075
    for name in ['Body','Head','Wing_L','Wing_R']:honey_cells(c,name+' recessed hex cells',BASE[name],bone_for(name))
    for i,z in enumerate([.55,.39,.23]):box(c,'Honey comb '+str(i),(0,-1.23+i*.35,4.29+z/2),(.28,.30,z),M['Honey'],'Head')
    for i,x in enumerate([-.45,0,.45]):beam(c,'Honey tail '+str(i),(x,1.32,2.45),(x,1.92,3.55-abs(x)),.36,.30,M['HoneyRim'],'BackSocket')
    for sign,side in [(-1,'L'),(1,'R')]:
        for j,y in enumerate([-.55,.22,.95]):drop(c,'Honey drip '+side+str(j),(sign*1.30,y,1.38),.22+j*.10,M['Honey'],'Wing_'+side,.10)
    drop(c,'Head honey drip',(.64,-1.53,4.23),.44,M['Honey'],'Head',.075)
    return studio(c)

def toxic_paint(p,axis,side):
    n=noise.noise(p*2.5+Vector((7,2,3)))
    if n>.12:return 3 if n>.27 else 4
    return 0 if n<-.13 else (1 if n<.02 else 2)

def build_toxic():
    c=begin('toxic','Toxic',M['Lime'],beakmat=M['LimeLight'],wattlemat=M['LimeLight'],legmat=M['Crust'],paint=([M['Lime'],M['LimeLight'],M['LimeDark'],M['Crust'],M['CrustLight']],toxic_paint))
    for i in range(3):
        box(c,'Toxic comb '+str(i),(0,-1.23+i*.35,4.44+i*.08),(.32,.28,.3+i*.16),M['Crust'] if i==1 else M['Lime'],'Head')
        x=(i-1)*.63;h=[.42,.7,.5][i]
        box(c,'Tail vent '+str(i),(x,1.42,2.87+h/2),(.39,.42,h),M['Crust'],'BackSocket')
        box(c,'Glowing vent mouth '+str(i),(x,1.42,2.88+h),(.29,.32,.05),M['LimeLight'],'BackSocket',.008)
        ball(c,'Vent bubble '+str(i),(x,1.42,3.0+h),.13,M['Lime'],'BackSocket')
    for i,(x,z,r) in enumerate([(-.6,1.58,.13),(.35,2.1,.19),(.72,1.42,.10),(-.15,1.77,.075)]):ball(c,'Acid bubble '+str(i),(x,-1.25,z),r,M['LimeLight'])
    for sign,side in [(-1,'L'),(1,'R')]:
        for j,y in enumerate([-.60,.16,.95]):drop(c,'Acid drip '+side+str(j),(sign*1.29,y,1.42),.22+j*.09,M['Lime'],'Wing_'+side,.105)
    for side in ['L','R']:
        for i in range(1,4):
            bb=BASE['Toe_'+side+'_'+str(i)];box(c,'Lime toe cap '+side+str(i),tuple((a+b)/2 for a,b in bb),tuple(b-a+.007 for a,b in bb),M['LimeLight'],'Foot_'+side,.009)
    return studio(c)

def wave(ctx,name,center,r,bone,u,v):
    C,U,V=Vector(center),Vector(u),Vector(v);N=U.cross(V).normalized()
    if 'Chest' in name:
        points=[]
        for i in range(40):
            t=i/39;ang=-.75*math.pi+t*3.6*math.pi;rr=r*(1-.91*t)
            points.append(tuple(C+U*(rr*math.cos(ang))+V*(rr*math.sin(ang))))
        tube(ctx,name+' cyan vortex',points,[r*(.09-.065*i/39) for i in range(40)],M['WaterLight'],bone,7)
        return
    poly=[(-.88,-.68),(.68,-.68),(.87,-.46),(.56,-.22),(.16,-.12),(-.10,.08),(-.10,.34),(.10,.48),(.32,.49),(.48,.32),(.47,.08),(.60,.12),(.76,.40),(.65,.70),(.38,.93),(.02,1),(-.4,.8),(-.70,.50),(-.88,.05)]
    extrude(ctx,name+' solid wave fin',[(x*r,z*r) for x,z in poly],r*.26,center,M['Water'],bone,u,v,.016,M['Aqua'])
    inner=[(-.68,-.52),(-.28,-.32),(-.25,.05),(-.24,.35),(-.05,.57),(.20,.66),(.45,.56)]
    tube(ctx,name+' cyan water ridge',[tuple(C+U*(x*r)+V*(z*r)+N*r*.16) for x,z in inner],r*.054,M['Aqua'],bone,7)
    foampts=[]
    for x,z in [(-.72,.48),(-.52,.68),(-.28,.86),(.02,.95),(.32,.89),(.57,.71),(.70,.48)]:
        foampts.append(tuple(C+U*(x*r)+V*(z*r)+N*(r*.16)))
    tube(ctx,name+' white crest',foampts,r*.075,M['Foam'],bone,7)
    for i in [1,5]:ball(ctx,name+' foam bead '+str(i),foampts[i],r*.105,M['Foam'],bone,8,4)

def water_paint(p,axis,side):
    n=noise.noise(p*3.6)
    return 2 if abs(n)<.055 else (0 if n<0 else 1)

def build_water():
    c=begin('water','Water',M['Water'],beakmat=M['Aqua'],wattlemat=M['DeepBlue'],legmat=M['Aqua'],wings=False,paint=([M['Water'],M['Aqua'],M['WaterLight']],water_paint))
    for sign,side in [(-1,'L'),(1,'R')]:wave(c,'Wave wing '+side,(sign*1.37,.05,2.1),.82,'Wing_'+side,(0,sign,0),(0,0,1))
    wave(c,'Wave tail',(0,1.50,3.17),.94,'BackSocket',(1,0,0),(0,0,1))
    wave(c,'Wave comb',(0,-.9,4.60),.47,'Head',(1,0,0),(0,0,1))
    wave(c,'Chest whirlpool',(0,-1.28,1.93),.65,'Body',(1,0,0),(0,0,1))
    return studio(c)

def solar_paint(p,axis,side):
    n=noise.noise(p*3.4)
    return 0 if n<-.08 else (1 if n<.18 else 2)

def build_solar():
    c=begin('solar-flare','Solar Flare',M['SunCore'],beakmat=M['SunOrange'],legmat=M['SunOrange'],wattlemat=M['SunEdge'],wings=False,paint=([M['SunCore'],M['SunYellow'],M['SunOrange']],solar_paint))
    for sign,side in [(-1,'L'),(1,'R')]:
        for i in range(4):
            ang=math.radians(-38+i*27);A=(sign*1.08,.12,2.1);B=(sign*(1.15+1.23*math.cos(ang)),.10,2.1+1.23*math.sin(ang))
            beam(c,'Solar wing ray '+side+str(i),A,B,.36,.20,M['SunCore'],'Wing_'+side,M['SunOrange'])
    for i in range(5):
        a=math.radians(-52+i*26);beam(c,'Solar tail ray '+str(i),(0,1.27,2.35),(math.sin(a)*1.33,1.87,2.35+math.cos(a)*1.84),.35,.22,M['SunYellow'],'BackSocket',M['SunEdge'])
    for i in range(3):beam(c,'Solar comb '+str(i),((i-1)*.32,-.88,4.26),((i-1)*.43,-.88,4.78+(.26 if i==1 else 0)),.24,.28,M['SunYellow'],'Head',M['SunOrange'])
    return studio(c)

def build_heavenly():
    c=begin('heavenly','Heavenly',M['Pearl'],beakmat=M['Gold'],legmat=M['Gold'],wattlemat=M['Sky'],wings=False)
    for sign,side in [(-1,'L'),(1,'R')]:
        for i in range(5):
            A=(sign*(1.02+i*.035),.30,2.05+i*.23);B=(sign*(1.95+i*.18),.35,2.10+i*.52)
            beam(c,'Angel feather '+side+str(i),A,B,.36,.16,M['Pearl'],'Wing_'+side,M['PearlShade'])
        beam(c,'Gold wing root '+side,(sign*1.05,.20,2.04),(sign*1.38,.20,3.5),.18,.23,M['Gold'],'Wing_'+side)
    vertices=[]
    for z in [4.685,4.815]:
        for w,h in [(.77,.70),(.63,.56)]:
            vertices.extend([(x,-.9+y,z) for x,y in [(-w,-h),(w,-h),(w,h),(-w,h)]])
    faces=[]
    for i in range(4):
        j=(i+1)%4;faces.extend([(i,j,8+j,8+i),(4+j,4+i,12+i,12+j),(8+i,8+j,12+j,12+i),(j,i,4+i,4+j)])
    addmesh(c,'Continuous square halo',vertices,faces,[M['Gold']],bone='Head',bevel=.012)
    for i in range(3):beam(c,'Pearl tail '+str(i),((i-1)*.34,1.3,2.28),((i-1)*.55,1.75,3.05-(.16 if i!=1 else 0)),.32,.16,M['PearlShade'],'BackSocket',M['Gold'])
    extrude(c,'Gold chest diamond',[(0,.34),(.31,0),(0,-.34),(-.31,0)],.08,(0,-1.25,1.91),M['Gold'],'Body',bevel=.013)
    extrude(c,'Sky chest gem',[(0,.24),(.21,0),(0,-.24),(-.21,0)],.10,(0,-1.30,1.91),M['Sky'],'Body',bevel=.012)
    for sign in [-1,1]:box(c,'Gold shoulder trim '+str(sign),(sign*1.07,-.84,2.43),(.07,.15,.86),M['Gold'],'Body',.008)
    return studio(c)

def build_devil():
    c=begin('devil','Devil',M['Scarlet'],beakmat=M['Orange'],legmat=M['Orange'],wattlemat=M['Crimson'],wings=False)
    for sign,side in [(-1,'L'),(1,'R')]:
        tube(c,'Curved horn '+side,[(sign*.6,-.82,4.06),(sign*.87,-.80,4.3),(sign*.91,-.77,4.57),(sign*.80,-.74,4.92)],[.24,.23,.15,.02],M['Horn'],'Head',6)
        poly=[(0,0),(.42,.5),(1.08,.17),(1.48,-.7),(.98,-.48),(.80,-.97),(.48,-.63),(0,-.83)]
        U=(sign,0,0);center=(sign*1.03,.17,2.58)
        extrude(c,'Bat membrane '+side,poly,.13,center,M['Membrane'],'Wing_'+side,u=U,bevel=.012)
        def pt(x,z):return (center[0]+sign*x,center[1]-.1,center[2]+z)
        for j,path in enumerate([[(0,0),(.42,.5),(1.08,.17),(1.48,-.7)],[(.42,.5),(.8,-.97)],[(.42,.5),(0,-.83)]]):tube(c,'Orange bat rib '+side+str(j),[pt(x,z) for x,z in path],.055,M['SunEdge'],'Wing_'+side,6)
    tail=[(0,1.3,2.04),(0,1.8,2.12),(0,2.2,2.53),(0,2.32,3.1),(0,2.24,3.51)]
    tube(c,'Devil tail',tail,[.17,.16,.14,.12,.10],M['Scarlet'],'BackSocket',8)
    extrude(c,'Tail arrow',[(-.25,-.12),(0,.28),(.25,-.12),(0,0)],.19,(0,2.23,3.59),M['Horn'],'BackSocket',bevel=.012)
    extrude(c,'Chest orange chevron',[(-.76,.31),(0,-.20),(.76,.31),(.76,.12),(0,-.42),(-.76,.12)],.03,(0,-1.239,1.88),M['Orange'],'Body',bevel=.008)
    return studio(c)

def build_jungle():
    c=begin('jungle','Jungle',M['Emerald'],headmat=M['JungleHead'],beakmat=M['Yellow'],legmat=M['Yellow'],wattlemat=M['Orange'],wings=False)
    for sign,side in [(-1,'L'),(1,'R')]:
        for i in range(4):leaf(c,'Tropical wing leaf '+side+str(i),(sign*1.09,-.6+i*.44,2.70),(sign*1.62,-.28+i*.50,1.48+i*.06),.73,M['Leaf'],'Wing_'+side,(sign,0,0))
    for i in range(5):leaf(c,'Tropical tail leaf '+str(i),((i-2)*.12,1.33,2.43),((i-2)*.48,1.77,3.74-abs(i-2)*.21),.69,M['Leaf'],'BackSocket')
    for i in range(3):leaf(c,'Leaf comb '+str(i),((i-1)*.28,-.91,4.26),((i-1)*.65,-.91,5.22-abs(i-1)*.3),.48,M['Leaf'],'Head')
    vine=[(-1,-1.25,2.65),(-.89,-1.31,2.31),(-.48,-1.34,2.04),(.0,-1.34,1.84),(.46,-1.32,1.62),(.91,-1.27,1.41)]
    tube(c,'Living chest vine',vine,.065,M['LeafVein'])
    leaf(c,'Chest leaf one',(-.49,-1.41,2.03),(-.32,-1.44,2.56),.32,M['LeafLight'])
    leaf(c,'Chest leaf two',(.38,-1.42,1.65),(.69,-1.43,2.1),.36,M['LeafLight'])
    C=Vector((.42,-1.12,4.52))
    for i in range(5):
        a=2*math.pi*i/5;D=Vector((math.cos(a),0,math.sin(a)))
        poly=[(0,0),(-.12,.14),(-.105,.27),(0,.34),(.105,.27),(.12,.14)]
        leaf(c,'Flower petal '+str(i),tuple(C),tuple(C+D*.36),.25,M['Flower'],'Head',vein=False)
    ball(c,'Flower yellow center',tuple(C+Vector((0,-.13,0))),.105,M['Yellow'],'Head',10,5)
    return studio(c)

BUILDERS={'lollipop':build_lollipop,'honeycomb':build_honeycomb,'toxic':build_toxic,'water':build_water,'solar-flare':build_solar,'heavenly':build_heavenly,'devil':build_devil,'jungle':build_jungle}
