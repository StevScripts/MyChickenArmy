from pathlib import Path
import cv2,numpy as np,json
source=next(Path('/Users/stevin/Desktop').glob('Screen Recording 2026-10-06 at 1.40.58*'))
cap=cv2.VideoCapture(str(source));rows=[];prev=None;prev_t=None;cumulative=0
while True:
 ok,im=cap.read()
 if not ok:break
 t=cap.get(cv2.CAP_PROP_POS_MSEC)/1000
 if t<12.25:continue
 if t>24.8:break
 im=cv2.resize(im,(1728,1117),interpolation=cv2.INTER_AREA)
 # Fixed center band inside cards; only analyze once the panel has settled.
 gray=cv2.cvtColor(im[535:608,210:1518],cv2.COLOR_BGR2GRAY).astype(np.float32)
 dx,quality=None,None
 if prev is not None:
  (dx,dy),quality=cv2.phaseCorrelate(prev,gray)
  if abs(dx)<230 and quality>.05 and 13.3<t<21.7:cumulative+=dx
 # Gold panel outline at two fixed x positions, far from card interiors.
 hsv=cv2.cvtColor(im,cv2.COLOR_BGR2HSV)
 mask=(hsv[:,:,0]>17)&(hsv[:,:,0]<40)&(hsv[:,:,1]>110)&(hsv[:,:,2]>145)
 column=np.max(mask[:,[176,177,178,1550,1551,1552]],axis=1)
 ys=np.where(column)[0].tolist()
 rows.append(dict(t=t,dx=dx,quality=quality,cumulative=cumulative,edgeYs=ys))
 prev=gray;prev_t=t
Path('assets/galaxy-roll-20261006/reference-match/reference-track.json').write_text(json.dumps(rows))
for second in np.arange(13.5,24.51,.5):
 r=min(rows,key=lambda r:abs(r['t']-second));print({k:round(r[k],3) if isinstance(r[k],float) else r[k] for k in ['t','dx','quality','cumulative']})
