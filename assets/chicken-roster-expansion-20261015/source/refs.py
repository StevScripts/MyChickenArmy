"""Generate one concept reference per chicken with the chatgpt-image skill.
Usage: python3 refs.py ID [ID...]   (prompts live in ref_prompts.json)"""
import json, subprocess, sys, pathlib
ST = pathlib.Path(__file__).resolve().parent.parent
BASE = ("Edit the reference: keep the SAME cute boxy voxel Roblox chicken with identical proportions and pose "
        "(tall square head, large rectangular beak, black square eyes with small white square glints, blocky torso, "
        "flat block wings on the sides, block legs and three squared toes). Front three-quarter view, whole chicken visible, "
        "plain light-gray studio background, soft even light, chunky low-poly toy look, flat colors with a little pixel texture, "
        "small simple box-shaped accessories only, no text, no particles. Variant: ")
prompts = json.loads((ST/'source'/'ref_prompts.json').read_text())
for cid in sys.argv[1:]:
    out = ST/'concepts'
    if (out/f'{cid}.png').exists():
        print('skip', cid); continue
    r = subprocess.run(['python3', str(pathlib.Path.home()/'.claude/skills/chatgpt-image/scripts/gen.py'), BASE+prompts[cid],
        '--image', str(ST/'reference-previews'/'approved-base.png'), '--quality', 'medium', '--out', str(out), '--name', cid],
        capture_output=True, text=True)
    for f in out.glob(cid+'-2026*.png'): f.rename(out/f'{cid}.png')
    print(cid, r.stdout.strip()[-120:], r.stderr.strip()[-300:])
