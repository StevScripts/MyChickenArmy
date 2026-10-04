"""Reference-matched vivid materials for existing Galaxy meshes.

Only material samples are produced. Importing this module does not access Blender
or mutate a scene. Call configure(models) once in Blender, then pass shade to
atlas_tools.bake_existing. Shader colors and source PNG samples are sRGB values;
loading as Non-Color prevents accidental sRGB-to-linear conversion before the
atlas writer. P and bounds use native original-mesh coordinates.

Sources: original generated cosmic/plasma art and approved feather-height art.
The Alien eyes are painted on Head; legacy Eye/Glint boxes are fully transparent.
"""
from pathlib import Path
import numpy as np

SOURCE_ROOT=Path('/Users/stevin/.codex/artifacts/galaxy-reference-textures')
FEATHER_PATH=Path('/Users/stevin/.codex/artifacts/galaxy-feather-wings/generated-textures/feather-height.png')
TILES={}
FEATHER=None
PLASMA_BOUNDS={}
SOURCE_IMAGES=[]

def rgb(value):
    return np.array([int(value[i:i+2],16)/255 for i in (0,2,4)],dtype=float)

def hash3(p):
    h=np.sin(np.sum(np.asarray(p,dtype=float)*np.array((127.1,311.7,74.7)),axis=-1))*43758.5453123
    return h-np.floor(h)

def _load_png(path):
    import bpy
    image=bpy.data.images.load(str(path),check_existing=False)
    image.name='Reference v2 source | '+path.stem
    image.colorspace_settings.name='Non-Color'
    image.pack()
    samples=np.empty(image.size[0]*image.size[1]*4,dtype=np.float32)
    image.pixels.foreach_get(samples)
    SOURCE_IMAGES.append(image)
    return samples.reshape(image.size[1],image.size[0],4)[...,:3]

def configure(models):
    """Load and pack sources; obtain exact unchanged Body/Neck/Head bounds."""
    global FEATHER
    if not TILES:
        for key in ('plasma','cosmic'):
            TILES[key]=_load_png(SOURCE_ROOT/'generated-textures'/(key+'.png'))
        # The established very shallow source smoothing removes small harsh dots.
        source=TILES['plasma']
        TILES['plasma']=sum(np.roll(np.roll(source,dy,0),dx,1) for dx in (-3,-1,0,1,3) for dy in (-3,-1,0,1,3))/25
    if FEATHER is None:
        FEATHER=_load_png(FEATHER_PATH).mean(-1)
    mesh=models['dark-matter']['base'].data
    for component,label in enumerate(('Body','Neck','Head')):
        vertices=np.array([vertex.co[:] for vertex in mesh.vertices[component*24:(component+1)*24]],dtype=float)
        PLASMA_BOUNDS[label]=(vertices.min(0),vertices.max(0))
    return {'sources':[str(SOURCE_ROOT/'generated-textures'/f'{k}.png') for k in ('plasma','cosmic')]+[str(FEATHER_PATH)], 'plasma_bounds':{k:[a.tolist(),b.tolist()] for k,(a,b) in PLASMA_BOUNDS.items()}}

def plasma_edge_distance(P,label):
    bounds=PLASMA_BOUNDS.get(label)
    if bounds is None:
        return np.full(P.shape[:-1],1.0)
    lo,hi=bounds
    distances=np.minimum(np.abs(P-lo),np.abs(hi-P))
    return np.sort(distances,axis=-1)[...,1]

def sample(name,P,N,scale=.3,offset=(.13,.23)):
    a=TILES[name];h,w=a.shape[:2];axis=int(np.argmax(np.abs(N)))
    uv=P[...,[1,2] if axis==0 else ([0,2] if axis==1 else [0,1])]*scale+np.array(offset)
    u=np.mod(uv[...,0],1)*w;v=np.mod(uv[...,1],1)*h;x=np.floor(u).astype(int);y=np.floor(v).astype(int)
    fx=(u-x)[...,None];fy=(v-y)[...,None]
    return (a[y%h,x%w]*(1-fx)+a[y%h,(x+1)%w]*fx)*(1-fy)+(a[(y+1)%h,x%w]*(1-fx)+a[(y+1)%h,(x+1)%w]*fx)*fy

def continuous_plasma(P):
    # One oblique projection in original mesh coordinates: adjoining faces use
    # precisely the same coordinates at their common edge. Never choose by normal.
    q=P-np.array((0,0,2.3))
    u=.5+.19*np.sum(q*np.array((.70710678,-.70710678,0)),axis=-1)
    v=.5+.19*np.sum(q*np.array((.40824829,.40824829,.81649658)),axis=-1)
    a=TILES['plasma'];h,w=a.shape[:2]
    # The complete chicken fits inside the source image. No periodic wrap cuts.
    u=np.clip(u,0,1)*(w-1);v=np.clip(v,0,1)*(h-1)
    x=np.floor(u).astype(int);y=np.floor(v).astype(int);fx=(u-x)[...,None];fy=(v-y)[...,None]
    return (a[y,x]*(1-fx)+a[y,np.minimum(x+1,w-1)]*fx)*(1-fy)+(a[np.minimum(y+1,h-1),x]*(1-fx)+a[np.minimum(y+1,h-1),np.minimum(x+1,w-1)]*fx)*fy

def mix(a,b,t):return a*(1-t[...,None])+b*t[...,None]

def smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)

def poly_mask(U,V,poly):
    inside=np.zeros(U.shape,bool);j=len(poly)-1
    for i,(xi,yi) in enumerate(poly):
        xj,yj=poly[j];inside ^= ((yi>V)!=(yj>V)) & (U<(xj-xi)*(V-yi)/(yj-yi+1e-12)+xi);j=i
    return inside

COLORS={
 'white':('E9F3FF',.26,.08,0),'suit':('E4ECF7',.31,.02,0),
 'navy':('1045B2',.26,.12,0),'gold':('FFD148',.22,.55,0),
 'yellow':('FFD42F',.27,0,0),'red':('EA1751',.3,0,0),
 'eye':('010509',.17,0,0),'white_light':('E6FBFF',.23,0,.75),
 'cyan':('1DE3FF',.23,.03,1.35),'purple':('871BDC',.29,.05,0),
 'alien':('B8F51E',.31,0,.02),'green':('10B84C',.3,0,0),
 'lime_light':('D6FF72',.24,0,1.6),'lilac':('E4B7FF',.27,0,.045),
 'magenta':('DE13CE',.28,0,.10),'pink_light':('FFD8FF',.24,0,1.8),
 'dark_purple':('4421B4',.27,.06,.01),'plasma':('281052',.3,.03,0),
 'cosmic':('102ABE',.24,.1,.075),'glass':('FFFFFF',.14,.02,0)
}

def _reference_shade(ident,style,P,UV,N,label):
    sh=P.shape[:-1];co,r,m,e=COLORS[style];C=np.broadcast_to(rgb(co),sh+(3,)).copy()
    R=np.full(sh,r,dtype=float);M=np.full(sh,m,dtype=float);E=np.full(sh,e,dtype=float);H=np.zeros(sh);A=np.ones(sh)
    X,Y,Z=P[...,0],P[...,1],P[...,2]
    edge=np.minimum.reduce([UV[...,0],1-UV[...,0],UV[...,1],1-UV[...,1]])
    if ident=='astronaut-visor':
        A[:]=.008;C[:]=rgb('ADCDF7');R[:]=.12
        border=edge<.033;C[border]=rgb('F5F3DF');A[border]=1;R[border]=.23;M[border]=.15
        outer=edge<.011;C[outer]=rgb('F6C94A');M[outer]=.50
        U,V=UV[...,0],UV[...,1]
        streak=(abs(U+V-1.15)<.019)&(V>.70)&(~border)
        C[streak]=rgb('DCFAFF');A[streak]=.20;E[streak]=.12
        return C,R,M,E,H,A
    if ident in ['alien','dark-matter'] and label=='Glint':
        A[:]=0;E[:]=0;return C,R,M,E,H,A
    if (label=='Eye' and ident in ['alien','dark-matter']) or (ident=='alien' and label=='Head' and N[1]<-.85):
        u=(np.abs(X)-.225)/.44;v=(Z-3.515)/.47
        # Reference eye shapes are painted into the native eye surfaces, with opacity outside.
        if ident=='alien':
            t=np.linspace(0,1,28);p0=np.array([.07,.02]);p1=np.array([.96,.99])
            p2=np.array([1.12,-.05]);p3=np.array([-.09,1.02])
            curve=[(1-q)**2*p0+2*(1-q)*q*p2+q*q*p1 for q in t]
            curve += [(1-q)**2*p1+2*(1-q)*q*p3+q*q*p0 for q in t[1:]]
            mask=poly_mask(u,v,curve)
            C[:]=rgb('020A08');lens=np.clip(1-((u-.5)/.65)**2-((v-.5)/.73)**2,0,1)
            C+=lens[...,None]*rgb('07180B');H=.003*lens;R[:]=.16
            glint=np.exp(-(((u-.57)/.14)**2+((v-.73)/.17)**2)*2)
            C=mix(C,rgb('DFFF5B'),np.clip(glint*1.65,0,1));E=glint*2.2
            lower=np.exp(-(((u-.40)/.052)**2+((v-.18)/.055)**2)*2)
            C=mix(C,rgb('3AA242'),lower*.6)
            C[~mask]=rgb('B8F51E');H[~mask]=0;R[~mask]=.30;E[~mask]=.07
        else:
            mask=poly_mask(u,v,[(.03,.43),(.99,.98),(.87,.42),(.70,.11),(.43,.04),(.21,.16)])
            A=mask.astype(float);C[:]=rgb('FFD6FB');R[:]=.25;E[:]=1.6
        if abs(N[1])<.85:
            if ident=='alien':C[:]=rgb('B8F51E');E[:]=.07;H[:]=0;R[:]=.30
            else:A[:]=0
        return C,R,M,E,H,A
    if style=='cosmic':
        C=sample('cosmic',P,N,.24,(.20,.11))
        C=np.clip(C*np.array((.90,.88,1.10)),0,1)**1.12;C=np.maximum(C,rgb('0B117D'))
        speck=np.max(C,axis=-1);E=.10+smooth(.80,.96,speck)*.8;R[:]=.23
        q=P*15;cell=np.floor(q);f=q-cell;stars=(hash3(cell)>.992)&(np.min(abs(f-.5),axis=-1)<.07)
        C[stars]=rgb('77C6FF');E[stars]=.55
        border=np.clip(1-edge/.02,0,1);C=mix(C,rgb('7359FF'),border*.2)
    elif style=='plasma':
        C=continuous_plasma(P)
        C=np.clip(C,0,1)**1.15;C[...,1]*=.72
        C=np.maximum(C,rgb('2C075B'))
        hot=smooth(.61,.96,C[...,0]);E=.035+hot*1.12;R=.32-hot*.10
        rim=np.clip(1-plasma_edge_distance(P,label)/.035,0,1)**1.5
        C=mix(C,rgb('FA79FF'),rim*.92);E=np.maximum(E,rim*1.55)
        H=-.003*hot
    elif style=='alien':
        # Small controlled blocks, broad lime surfaces, a darker lower belly like the reference.
        cells=np.floor(P*6);h=hash3(cells)
        patch=(h>.975)&(Z<3.48);C*=np.where(patch,.94,1)[...,None]
        E[:]=.07
        C*= (.97+.03*np.clip((Z-1)/3.3,0,1))[...,None]
        if label=='Body' and N[1]<-.7:
            px=np.floor(X*6)/6;pz=np.floor(Z*6)/6
            belly=((np.abs(px)<.54)&(pz<1.78)&(pz>1.23))|((np.abs(px)<.38)&(pz<1.93)&(pz>1.06))
            C[belly]=rgb('2AAA29')
            patch2=((px>.57)&(px<.9)&(pz>2.01)&(pz<2.18))|((px>.73)&(px<.9)&(pz>1.85)&(pz<2.01))
            C[patch2]=rgb('279D32')
            H[belly]=-.002
        if label=='Head':
            edgehi=np.clip(1-edge/.025,0,1);C=mix(C,rgb('D6FF67'),edgehi*.22)
    if label.startswith('Wing'):
        if ident=='astronaut':base='0735A2';light='2686E6';trim='022D79'
        elif ident=='alien':base='7512CC';light='BD35F1';trim='45098C'
        else:base='3021A6';light='7242E4';trim='20106B'
        v=np.clip((Z-1.23)/1.52,0,1);u=np.clip((Y+.86)/2.08,0,1)
        C=mix(np.broadcast_to(rgb(base),sh+(3,)),rgb(light),(.10+.48*v))
        if abs(N[0])>.8:
            # Broad feather-panel color blocks and shallow relief, entirely in the maps.
            row=np.clip(np.floor((v-.07)/.29),0,2);stagger=np.mod(row,2)*.15
            cell=np.floor((u+stagger)/.34);localu=np.mod(u+stagger,.34)/.34
            localv=np.mod(v-.07,.29)/.29
            panel=(u>.07)&(u<.97)&(v>.07)&(v<.94)
            face=(.07+.17*localv+.045*np.mod(cell+row,3))*panel
            C=mix(C,rgb(light),face)
            seams=((1-smooth(.015,.045,localu))+(1-smooth(.018,.060,localv)))*panel
            C=mix(C,rgb(trim),np.clip(seams*.66,0,.85));H-=np.clip(seams,0,1)*.006
            lip=(smooth(.925,.97,localv)*(1-smooth(.975,1,localv)))*panel
            C=mix(C,rgb(light),lip*.63);H+=lip*.003
            rim=np.clip(1-edge/.023,0,1);C=mix(C,rgb(light),rim*.4)
        R[:]=.27;M[:]=.08;E[:]=0
    if style=='suit':
        C[:]=rgb('DFEAF8');R[:]=.30
        rim=np.clip(1-edge/.04,0,1);C=mix(C,rgb('F4FAFF'),rim*.55)
        if label=='Body' and N[1]<-.8:
            # Reference-like chest panel blocks and clean pale manufactured seams.
            seam=(np.abs(X)>.94)|(Z<1.14);C[seam]=rgb('B8CCE7')
            belt=(Z>1.16)&(Z<1.37);C[belt]=rgb('C3D3E8')
            waist=(np.abs(X)>.48)&(np.abs(X)<.82)&(Z<1.4);C[waist]=rgb('1B4A9A')
            screws=(np.abs(np.abs(X)-.78)<.024)&(np.abs(Z-1.31)<.025);C[screws]=rgb('62E2F7');E[screws]=.6
            panel=(np.abs(X)<.72)&(Z>1.58)&(Z<2.44);C[panel]=rgb('10264D');H[panel]=-.004
            inner=(np.abs(X)<.57)&(Z>1.70)&(Z<2.34);C[inner]=rgb('265996')
            sidegasket=(np.abs(X)>.81)&(np.abs(X)<.94)&(Z>1.42)&(Z<2.71);C[sidegasket]=rgb('253956');H[sidegasket]=-.007
            seam2=(np.abs(Z-1.47)<.018)|(np.abs(np.abs(X)-.39)<.013)&(Z<1.55);C[seam2]=rgb('839DBF')
            bolt2=(np.abs(np.abs(X)-.63)<.033)&((np.abs(Z-1.68)<.036)|(np.abs(Z-2.35)<.036));C[bolt2]=rgb('A0B5CE')
        elif label=='Body' and abs(N[0])>.8:
            C[(Z>1.13)&(Z<1.35)]=rgb('2456AE')
        if label.startswith('Foot'):
            C[Z<.06]=rgb('17428B')
            if N[2]>.7:
                mark=(np.abs(np.abs(X)-.62)<.13)&(Y>-.76)&(Y<-.42)
                C[mark]=rgb('54DAEE');E[mark]=.33;H[mark]=-.004
            elif abs(N[0])>.7:
                band=(Y>-.67)&(Y<-.20)&(Z>.10)&(Z<.19);C[band]=rgb('42DBEC');E[band]=.25
        if label.startswith('Leg'):
            C[:]=rgb('E4ECF4');cuff=(Z>.63)&(Z<.93);C[cuff]=rgb('9FBEDF')
            bolt=(np.abs(Z-.78)<.046)&(Y<-.25);C[bolt]=rgb('277CCF')
    if ident=='alien' and label.startswith('Leg'):
        C[:]=rgb('592496');C[Z<.48]=rgb('723ABB');R[:]=.28;E[:]=0
    if ident=='alien' and label=='Beak':
        C[:]=rgb('9B24E9');C[N[2]>.7]=rgb('C77BF5');R[:]=.24
    if ident in ['alien','dark-matter'] and label=='Wattle':
        C[:]=rgb('D92464');C[N[1]<-.7]=rgb('EB2560');E[:]=.025;R[:]=.28
    if ident=='dark-matter' and label.startswith('Foot'):
        if N[2]>.8:C[:]=rgb('F2BAFC');E[:]=.24
        else:C[:]=rgb('A92DC9');E[:]=.045
        rim=np.clip(1-edge/.035,0,1);C=mix(C,rgb('FCE1FF'),rim*.75);E=np.maximum(E,rim*.35)
    if ident=='dark-matter' and style=='magenta':
        rim=np.clip(1-edge/.035,0,1);C=mix(C,rgb('FF82F3'),rim*.50);E=np.maximum(E,rim*.3)
    if ident=='alien' and style=='lime_light':
        C[:]=rgb('B7FF35');E[:]=1.15
        if N[2]>.3:C[:]=rgb('DEFF9E');E[:]=1.6
    return np.clip(C,0,1),np.clip(R,0,1),np.clip(M,0,1),np.maximum(E,0),H,A

def sample_feather(u,v):
    if FEATHER is None:
        raise RuntimeError('Call reference_materials.configure(models) before baking.')
    h,w=FEATHER.shape
    x=np.clip(u,0,1)*(w-1);y=np.clip(v,0,1)*(h-1)
    xi=np.floor(x).astype(int);yi=np.floor(y).astype(int)
    fx=x-xi;fy=y-yi
    xj=np.minimum(xi+1,w-1);yj=np.minimum(yi+1,h-1)
    value=(FEATHER[yi,xi]*(1-fx)+FEATHER[yi,xj]*fx)*(1-fy)
    value+=(FEATHER[yj,xi]*(1-fx)+FEATHER[yj,xj]*fx)*fy
    return np.clip((value-.11)/.66,0,1)

def shade(ident,style,P,UV,N,label):
    """Return sRGB color, roughness, metalness, emission, height and opacity."""
    shape=P.shape[:-1]
    if ident=='alien' and label in ('Eye','Glint'):
        return (np.zeros(shape+(3,)),np.full(shape,.20),np.zeros(shape),
                np.zeros(shape),np.zeros(shape),np.zeros(shape))
    if label.startswith('Wing') and ident in ('astronaut','alien','dark-matter'):
        u=np.clip((P[...,1]+.86)/2.08,0,1)
        v=np.clip((P[...,2]-1.23)/1.52,0,1)
        depth=sample_feather(u,v)
        low,high={'astronaut':('071E91','246EFF'),
                  'alien':('5A08A5','B833FA'),
                  'dark-matter':('211075','7645EA')}[ident]
        tint=.13+.78*depth
        C=mix(np.broadcast_to(rgb(low),shape+(3,)),rgb(high),tint)
        R=.31-.065*depth;M=np.full(shape,.02);E=np.zeros(shape)
        H=np.zeros(shape);A=np.ones(shape)
        if abs(N[0])>.8:
            perimeter=np.minimum.reduce((u,1-u,v,1-v))
            H=.011*(depth-.45)*smooth(0,.025,perimeter)
        else:
            C=mix(np.broadcast_to(rgb(low),shape+(3,)),rgb(high),.28+.18*v)
            R=np.full(shape,.29)
        return C,R,M,E,H,A
    if style in ('plasma','cosmic') and not TILES:
        raise RuntimeError('Call reference_materials.configure(models) before baking.')
    return _reference_shade(ident,style,P,UV,N,label)
