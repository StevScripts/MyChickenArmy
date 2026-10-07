# Lightweight notifications — September 25, 2026

Task: 01a0d4f3-a87e-7da1-b43d-5f4f4bcd3429. User requested a less dense notification UI without the existing background.

Scope: UITheme notification styling; AppController Notify, sizing, lifetime cleanup and removal of the toast burst; UIMotion Toast only. AppController was explicitly released by the egg progression task. Its production/recruit messages, request context and replay handling are preserved, as are all other dirty-file edits. No server, commerce, reward values or player data changes.

The shared theme now constructs a transparent CanvasGroup with status-colored SourceSansBold text and a matching glyph. Following the user's visibility follow-up, text is 34px desktop/28px compact with a 3px/2.5px outline, rather than the earlier 22px white message. Success/error booleans remain compatible; omitted status means info. Explicit `"warning"`, `"info"`, `"pending"`, `"success"`, and `"error"` strings are supported. Message markup is escaped, allowing player/item names to remain literal. No image upload or new artwork.

The existing single latest-message behavior remains. Identical repeats refresh the cancellable dismissal timer without replaying entry. Text wraps within at most 720px/safe width, with height measured for the full message. Gameplay notices moved from the bottom to upper center (24% height bottom anchor); menus keep their existing top lane. Error/warning lifetime is 5–8 seconds; other messages 4–8. Normal TweenService-based shared tweens handle fade and 6px entry travel; reduced motion is respected. No bounce or burst behind messages.

Reference research: inspected gameplay screenshots from https://gamertweak.com/leather-in-blox-fruits/ and https://twinfinite.net/roblox/how-to-go-to-trading-plaza-pet-simulator-99/ in the browser. Blox Fruits' upper-center outlined colored reward text fits the user's background-free request; the shown Pet Simulator error modal does not. No reference assets copied. The current Play session was not interrupted; restart is needed to load the changed modules. No runtime or visual validation of this revision was performed.

Before-source copies: `/tmp/chicken-notifications-desu14/` (AppController, UITheme, UIMotion). All three matched canonical Studio Edit before edits, place 96683186622050. Local edits use Rojo, not Studio Source writes. No playtest, automated test, visual validation, save, publish, purchase, commit or push was performed. Appearance and runtime behavior remain untested in this task. Canonical DESIGN.md, its HTML companion and documentary tokens record the lighter visual contract.

## Livelier messages — October 7, 2026

The user found success/error messages dull and asked for something cooler. They stay
background-free (the September 25 request). Changes are client presentation only:

- A round status badge (dark ring, colored face, frame-built mark: check, cross,
  `!`, `i`, crossed swords, dots) sits just left of the centered text, replacing the
  text glyph. `Theme.StatusGlyph` draws the marks; no font glyphs or uploaded art.
- Text keeps SourceSansBold with a 3.5px outline. Its status color lives in a
  `Shine` UIGradient so a bright band can sweep across it.
- `Theme.NotificationFlair`: success/conquest pop in (0.72 → 1, Back) and shine;
  errors punch in (1.14 → 1), shake side to side and the badge spins in; warnings
  hop with a bounce; identical repeats pulse once. Info/pending keep the fade.
  Reduced motion skips all of it.
