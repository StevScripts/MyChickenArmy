from pathlib import Path
import cv2,numpy as np,json
source=next(Path('/Users/stevin/Desktop').glob('Screen Recording 2026-10-06 at 1.40.58*'));cap=cv2.VideoCapture(str(source));frames=[]
while True:
 ok,im=cap.read()
 if not ok:break
 t=cap.get(cv2.CAP_PROP_POS_MSEC)/1000
 if t<18.5:continue
 if t>22.5:break
 im=cv2.resize(im,(1728,1117),interpolation=cv2.INTER_AREA)
 frames.append((t,cv2.cvtColor(im,cv2.COLOR_BGR2GRAY)[535:608,1000:1555]))
ref=frames[-1][1];template=ref[:,115:200];rows=[]
for t,im in frames:
 res=cv2.matchTemplate(im,template,cv2.TM_CCOEFF_NORMED);_,score,_,loc=cv2.minMaxLoc(res)
 x=float(loc[0]);i=loc[0]
 if 0<i<res.shape[1]-1:
  a,b,c=map(float,res[0,i-1:i+2]);den=a-2*b+c
  if den:x+=.5*(a-c)/den
 rows.append({'t':t,'offset':x-115,'score':score})
fitrows=[r for r in rows if r['score']>.97 and r['t']<21.5];t=np.array([r['t'] for r in fitrows]);x=np.array([r['offset'] for r in fitrows]);fits=[]
for power in [2,3,4,5]:
 best=None
 for end in np.arange(21,24,.002):
  basis=np.maximum(end-t,0)**power;amplitude=(basis@x)/(basis@basis);err=np.mean((amplitude*basis-x)**2)
  if best is None or err<best['rmse']**2:best={'power':power,'end':float(end),'amplitude':float(amplitude),'rmse':float(err**.5)}
 fits.append(best)
print('n',len(fitrows));print(fits)
for target in np.arange(18.5,22.51,.25):print(min(rows,key=lambda r:abs(r['t']-target)))
Path('assets/galaxy-roll-20261006/reference-match/tail-fit.json').write_text(json.dumps({'measurements':rows,'fits':fits},indent=2))
