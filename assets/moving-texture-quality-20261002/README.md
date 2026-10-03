# Moving material quality evidence

Current behavior and measured limits: `../../docs/team/MOVING_TEXTURE_QUALITY.md`.

- `galaxy-shared-material.jpg`: high-detail workbench Galaxy, actual graphics 10.
- `galaxy-roaming-material.jpg`: real server-created yard actor walking with aura
  and foreground eggs. Its grant was confined to the session-only test profile.
- `rainbow-shared-material.jpg`: smooth continuous gradient on the final UV path.
- `galaxy-reveal-mask.jpg`: original full mask on a disposable final-offer preview.
- `validation.json`: client observations and the separately verified final cleanup.
- `source-readback.json`: exact byte lengths and djb2 hashes matching all eight
  canonical source files to their single Studio copies; Edit, no remaining fixture.
- `cleanup-check.luau`: focused final resource/restoration/cancelled-load check.
  Run only in Edit through Studio Flow; it creates an unparented disposable folder.
- `*.before.luau`: preserved prior atlas animators.

Performance sampling wrapped the actual Flow.Step in the real DuckAnimator, summed
its elapsed CPU per rendered frame, excluded 30 initial samples, then restored the
method. Ten temporary Galaxies plus the workbench Galaxy shared one cache; the
nearby Rainbow used its own. Reported frame intervals include the surrounding
game and VFX. No synthetic dt or quality override was used for those measurements.
The separate low-tier lifecycle check temporarily used Quality.NewState(1) and
restored the original state. Camera/UI and all diagnostic hooks were restored
before Play stopped. These measurements do not establish low-end phone performance.

Source is saved locally and synced. Native Studio save controls recovered during
the subsequent VFX-audio request. The Studio log confirmed “Saved new changes in
Pet Roll Test to Roblox” at 2026-10-03 03:41:24 UTC, saving this material revision
and the new audio placeholders together. No publish, asset upload or Git push
was performed. The earlier blocked cloud-save step is resolved.
