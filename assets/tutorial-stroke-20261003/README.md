# White arrows and single-stroke spotlight

Current runtime uses the generated white arrow with black contour, asset
`rbxassetid://101313283357577`. Both GUI pointers and the world destination marker
use GuideArrow. The later Beam revision replaces the ground chevrons with white
scrolling arrows; see `docs/team/COMMANDER_TUTORIAL.md`. Destination text stays white. The user's white
correction supersedes the retained gold generation; it is not used in runtime.

GuideFocus moves one transparent frame around the real target. Its black outer
UIStroke is 10,000 pixels (or larger for the viewport) with **0.5 transparency**.
The separate thin Army-green outline pulses; the white pointer bounces. All
motion uses TweenService. The frame follows native layout and does not capture
clicks. Hidden/offscreen targets and handoff remove the overlay.

- [White master](guidance-arrow-white-master.png)
- [Runtime PNG](guidance-arrow-white-roblox.png)
- [Exact edit prompt](WHITE-PROMPT.md)
- [Live spotlight screenshot](white-spotlight-live.png)
- [Validation record](validation.json)

The screenshots and validation record below predate the user's final change
from 0.8 to 0.5 transparency. The reusable check script now expects 0.5; the
earlier device sweep was not repeated for this one-value adjustment.

At the earlier 0.8 transparency, 19 focused checks passed at desktop 1238×587, landscape phone 666×374 and
portrait phone 373×666. Native input closed the actual highlighted Exit button.
The generated image loaded in both GUI and world pointers; all ten ground
chevron arms and the destination caption read back as white. Pixel sampling
confirmed all four viewport corners received exactly 20% black and the target
remained undimmed. No physical-phone or performance claim is made.

The relevant native APIs were checked against [Roblox UIStroke documentation](https://create.roblox.com/docs/reference/engine/classes/UIStroke)
and [StudioDeviceSimulatorService](https://create.roblox.com/docs/reference/engine/classes/StudioDeviceSimulatorService).
Studio returned to Edit with the default device. No release was published.
