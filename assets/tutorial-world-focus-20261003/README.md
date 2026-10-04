# Projected world spotlight

Latest user correction: enable world dimming only for the initial Roll/Recruit
interactions while their native prompt is in reach. Walking and repeated tasks
use the Beam/marker alone. The geometry checks below describe the renderer's
capabilities; they do not enable the spotlight on every tutorial step.

World targets use the existing transparent cutout frame with a 10,000-pixel
outer black UIStroke at 0.5 transparency. GuideWorldBounds projects actual item
corners into the overlay's coordinate space; GuideFocus tracks the active item
and camera before rendering. The white Beam remains the world direction cue.

The lever includes its base, arm and handle. Recruitment includes the podium
and revealed chicken. Collectible eggs use their visible billboard bounds.
Off-screen, behind-camera and near-plane-crossing items clear the overlay.
Destroyed targets, guide completion/skip and menu handoffs clean up tracking.

Seventeen world projection/lifecycle checks passed on desktop 1238×587 and
iPhone 13 landscape emulation 749×368. All nineteen existing GUI spotlight
checks passed on desktop. The actual lever was visually inspected in both
views. These are Studio checks, not physical-phone or performance measurements.

- [World check source](check-world-focus.luau)
- [Recorded results](validation.json)
- [Camera projection API](https://create.roblox.com/docs/reference/engine/classes/Camera#WorldToScreenPoint)
- [Model bounding box API](https://create.roblox.com/docs/reference/engine/classes/Model#GetBoundingBox)

Default device and normal player camera restored. Play remains running, as at
task start. No release, saved profile reset, Git commit or push was made.
