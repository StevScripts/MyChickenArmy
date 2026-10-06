"""Assemble native Blender renders into a review movie."""
import json, subprocess
from pathlib import Path

out=Path(__file__).resolve().parent
status=json.loads((out/'render-progress.json').read_text())
assert status['status']=='complete' and status['completed']==156, status
segments=[]
for view in ('three-quarter','side'):
    for kind in ('flight','attack','flight'):
        segments.append((view,kind,30))
segments.append(('three-quarter','attack',15))
lines=['ffconcat version 1.0']
last=None
for view,kind,fps in segments:
    for i in range(36 if kind=='flight' else 42):
        last=out/'frames'/view/kind/f'{i:03d}.png'
        assert last.is_file(),last
        lines.extend([f"file '{last}'",'option framerate 30',f'duration {1/fps:.9f}'])
lines.extend([f"file '{last}'",'option framerate 30'])
manifest=out/'preview-frames.ffconcat'
manifest.write_text('\n'.join(lines)+'\n')
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-safe','0','-i',str(manifest),
                '-r','30','-t','10.4','-c:v','libx264','-crf','18',
                '-pix_fmt','yuv420p','-movflags','+faststart',str(out/'Galaxy-Dragon-Forward-Attack-Preview.mp4')],check=True)
print(out/'Galaxy-Dragon-Forward-Attack-Preview.mp4')
