# Tutorial guidance — October 6, 2026

The user's latest direction removes tutorial highlighting. GuideFocus now places
only the GUI arrow: no viewport dimming, target outline or focus pulse. World
targets keep normal lighting, the existing destination marker and one native
attachment-driven Beam. Progression, prompt handoff and reduced motion remain.

The Beam uses original generated arrow artwork, `rbxassetid://78163165437840`,
uploaded to the game's creator group 778575811. Its white face, black contour,
short shaft and broad head repeat vertically with transparent spacing. Existing
GUI/destination artwork remains `rbxassetid://101313283357577`.

- `beam-arrow-master.png`: unchanged generated 1254 × 1254 source.
- `beam-arrow-roblox.png`: 1024 × 1024 runtime export; no crop or recoloring.
- `beam-arrow.rgba`: upload pixels; `asset.json` records hashes and alpha bounds.
- `PROMPT.md`: exact built-in generation prompt and references.
- `upload.json`: creator group, image ID and upload result.

Source changes are confined to GuideFocus, CommanderGuide and BaseController.
GuideWorldBounds remains an unused module for preservation. Combat and camp
action highlights are unchanged. No playtest or experience publication.

The three edited source modules matched Studio after the existing Rojo sync.
One stale same-named GuideFocus copy was preserved under
`ServerStorage.TutorialHighlightArchive20261006.GuideFocus`, outside client startup.
The upload receipt is retained under `ServerStorage.TutorialBeamArrow20261006`.
Source readback and whitespace checks passed; live appearance/direction remains
unverified because no playtest was started. The place was not saved or published.
