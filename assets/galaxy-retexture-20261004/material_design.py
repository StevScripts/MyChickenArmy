"""Generated material sources projected into the existing chicken UV atlases."""
import bpy, numpy as np
from pathlib import Path

ROOT=Path('/Users/stevin/.codex/artifacts/galaxy-retexture-20261004')
def rgb(s): return np.array([int(s[i:i+2],16)/255 for i in (0,2,4)])
def smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1); return t*t*(3-2*t)
def mix(a,b,t): return a*(1-t[...,None])+b*t[...,None]
def load(path):
    im=bpy.data.images.load(str(path),check_existing=False)
    im.colorspace_settings.name='Non-Color'
    a=np.empty(im.size[0]*im.size[1]*4,np.float32);im.pixels.foreach_get(a)
    return a.reshape(im.size[1],im.size[0],4)[...,:3]
T={k:load(ROOT/'generated'/(k+'.png')) for k in ('alien-skin','dark-nebula','astronaut-panel')}
F=load(ROOT/'feather-height.png').mean(-1)
def sample(a,u,v,wrap=False):
    h,w=a.shape[:2]
    if wrap:u=np.mod(u,1);v=np.mod(v,1)
    x=np.clip(u,0,1)*(w-1);y=np.clip(v,0,1)*(h-1)
    i=x.astype(int);j=y.astype(int);fx=x-i;fy=y-j
    if a.ndim==3:fx=fx[...,None];fy=fy[...,None]
    return (a[j,i]*(1-fx)+a[j,np.minimum(i+1,w-1)]*fx)*(1-fy)+(a[np.minimum(j+1,h-1),i]*(1-fx)+a[np.minimum(j+1,h-1),np.minimum(i+1,w-1)]*fx)*fy
def field(key,P):
    u=.5+.21*(.707*P[...,0]-.707*P[...,1]);v=.1+.21*(.408*P[...,0]+.408*P[...,1]+.816*P[...,2])
    return sample(T[key],u,v,True)
def poly_mask(u,v,poly):
    mask=np.zeros(u.shape,bool);j=len(poly)-1
    for i,(x,y) in enumerate(poly):
        xx,yy=poly[j];mask^=((y>v)!=(yy>v))&(u<(xx-x)*(v-y)/(yy-y+1e-12)+x);j=i
    return mask

def shade(ident,style,P,UV,N,label):
    sh=P.shape[:-1];X,Y,Z=P[...,0],P[...,1],P[...,2]
    C=np.broadcast_to(rgb('EEECE4'),sh+(3,)).copy();R=np.full(sh,.42);M=np.full(sh,.04);E=np.zeros(sh);H=np.zeros(sh);A=np.ones(sh)
    edge=np.minimum.reduce([UV[...,0],1-UV[...,0],UV[...,1],1-UV[...,1]])
    if ident=='alien':
        C=field('alien-skin',P)*np.array([.88,1.0,1.12]);R[:]=.43
        if label=='Body':
            belly=(np.abs(X)<.66)&(Z>1.10)&(Z<2.15)&(N[1]<-.8)
            f=np.clip(1-(X/.83)**2-((Z-1.65)/.72)**2,0,1)**.65 if N[1]<-.8 else np.zeros(sh)
            C=mix(C,rgb('9AEBD0'),f*.55)
        if label.startswith(('Leg','Foot')) or label=='Beak':
            C[:]=rgb('343251');R[:]=.34;M[:]=.22
            C=mix(C,rgb('7869A6'),np.clip(UV[...,1]*.20,0,.20))
        if label=='Wattle':C[:]=rgb('946EC3');R[:]=.4
        if label.startswith('Antenna'):
            C[:]=rgb('244B4E');R[:]=.3;M[:]=.25
            if 'light' in label:C[:]=rgb('ACFFF0');E[:]=.35;M[:]=.02
        if label=='Eye' or (label=='Head' and N[1]<-.85):
            u=(np.abs(X)-.225)/.44;v=(Z-3.515)/.47
            ts=np.linspace(0,1,28);p0=np.array([.07,.02]);p1=np.array([.96,.99]);p2=np.array([1.12,-.05]);p3=np.array([-.09,1.02])
            poly=[(1-q)**2*p0+2*(1-q)*q*p2+q*q*p1 for q in ts]+[(1-q)**2*p1+2*(1-q)*q*p3+q*q*p0 for q in ts[1:]]
            mask=poly_mask(u,v,poly)&(N[1]<-.85)
            lens=np.clip(1-((u-.5)/.65)**2-((v-.5)/.73)**2,0,1)
            eye=rgb('03151B')+lens[...,None]*rgb('0A2532')
            glint=np.exp(-(((u-.57)/.14)**2+((v-.73)/.17)**2)*2)
            eye=mix(eye,rgb('CFFFF4'),np.clip(glint*1.45,0,1));C[mask]=eye[mask];R[mask]=.13;E[mask]=glint[mask]*.15
            if label=='Eye': A=mask.astype(float)
    elif ident=='dark-matter':
        C=field('dark-nebula',P);C=np.maximum(C,rgb('110D2A'));R[:]=.32;M[:]=.15
        E=np.clip((np.max(C,axis=-1)-.35)*.6,0,.22)
        if label=='Beak' or label.startswith(('Leg','Foot')):
            C[:]=rgb('4B417B');C=mix(C,rgb('A297D8'),UV[...,1]*.22);R[:]=.28;M[:]=.38
        if label=='Wattle':C[:]=rgb('854ADD');R[:]=.32
        if label.startswith('Small comb'):
            C[:]=rgb('473384');C=mix(C,rgb('A675F8'),UV[...,1]*.30);M[:]=.35;R[:]=.26
        if label=='Eye':C[:]=rgb('93F4FF');E[:]=.5;R[:]=.22;M[:]=0
    else:
        colors={'suit':'E8EBE7','white':'EEF1ED','navy':'273C56','gold':'C99745','yellow':'E6AE43','red':'B35D72','eye':'081521','white_light':'DBFFFF','cyan':'36C5D6','cosmic':'18374C'}
        C[:]=rgb(colors.get(style,'DFE5E4'));M[:]=.08;R[:]=.37
        if style=='gold':M[:]=.55;R[:]=.28
        if style in ('cyan','white_light'):E[:]=.12
        if label=='Head':
            C[:]=rgb('214D62');C=mix(C,rgb('3A8DA0'),np.clip((Z-2.8)/1.6,0,1)*.35);R[:]=.22;M[:]=.25
        if label=='Body' and N[1]<-.8:
            C=sample(T['astronaut-panel'],(X+1.0)/2,(Z-1)/1.9);R[:]=.38
        if label=='Body' and abs(N[0])>.8:
            C=sample(T['astronaut-panel'],np.clip((Y+.9)/2.2,0,1)*.27+.02,np.clip((Z-1)/1.9,0,1));R[:]=.43
        if label=='Chest computer' and N[1]<-.8:
            C=sample(T['astronaut-panel'],.40+UV[...,0]*.20,.30+UV[...,1]*.38);R[:]=.29;M[:]=.12
        if label.startswith('Foot'):
            C[:]=rgb('CCD8DA');C[Z<.09]=rgb('293C52');M[:]=.17
        if label.startswith('Leg'):
            C[:]=rgb('E8EBE7');C[(Z>.58)&(Z<.72)]=rgb('607685')
    if label.startswith('Wing'):
        u=np.clip((Y+.86)/2.08,0,1);v=np.clip((Z-1.23)/1.52,0,1)
        depth=np.clip((sample(F,u,v)-.11)/.66,0,1)
        low,hi={'astronaut':('234258','7497AC'),'alien':('343255','8474AE'),'dark-matter':('171430','604CAA')}[ident]
        C=mix(np.broadcast_to(rgb(low),sh+(3,)),rgb(hi),.12+.68*depth);R=.45-.06*depth;M[:]=.05;E[:]=0
        if ident=='dark-matter':C=C*.76+field('dark-nebula',P)*.24
        H=.008*(depth-.45)*smooth(0,.025,np.minimum.reduce([u,1-u,v,1-v])) if abs(N[0])>.8 else np.zeros(sh)
    return np.clip(C,0,1),R,M,E,H,A
