# Lightweight notifications — September 25, 2026

Task: 01a0d4f3-a87e-7da1-b43d-5f4f4bcd3429. User requested a less dense notification UI without the existing background.

Scope: UITheme notification styling; AppController Notify, sizing, lifetime cleanup and removal of the toast burst; UIMotion Toast only. AppController was explicitly released by the egg progression task. Its production/recruit messages, request context and replay handling are preserved, as are all other dirty-file edits. No server, commerce, reward values or player data changes.

The shared theme now constructs a transparent CanvasGroup with status-colored SourceSansBold text and a matching glyph. Following the user's visibility follow-up, text is 34px desktop/28px compact with a 3px/2.5px outline, rather than the earlier 22px white message. Success/error booleans remain compatible; omitted status means info. Explicit `"warning"`, `"info"`, `"pending"`, `"success"`, and `"error"` strings are supported. Message markup is escaped, allowing player/item names to remain literal. No image upload or new artwork.

The existing single latest-message behavior remains. Identical repeats refresh the cancellable dismissal timer without replaying entry. Text wraps within at most 720px/safe width, with height measured for the full message. Gameplay notices moved from the bottom to upper center (24% height bottom anchor); menus keep their existing top lane. Error/warning lifetime is 5–8 seconds; other messages 4–8. Normal TweenService-based shared tweens handle fade and 6px entry travel; reduced motion is respected. No bounce or burst behind messages.

Reference research: inspected gameplay screenshots from https://gamertweak.com/leather-in-blox-fruits/ and https://twinfinite.net/roblox/how-to-go-to-trading-plaza-pet-simulator-99/ in the browser. Blox Fruits' upper-center outlined colored reward text fits the user's background-free request; the shown Pet Simulator error modal does not. No reference assets copied. The current Play session was not interrupted; restart is needed to load the changed modules. No runtime or visual validation of this revision was performed.

Before-source copies: `/tmp/chicken-notifications-desu14/` (AppController, UITheme, UIMotion). All three matched canonical Studio Edit before edits, place 96683186622050. Local edits use Rojo, not Studio Source writes. No playtest, automated test, visual validation, save, publish, purchase, commit or push was performed. Appearance and runtime behavior remain untested in this task. Canonical DESIGN.md, its HTML companion and documentary tokens record the lighter visual contract.

## Color text with a self-drawing mark — October 7, 2026

Chosen from Figma option A ("Feedback / Status text options", node 651:1501, file
4lJjZOqNhR8K7rfMbVIjaK) after the user rejected background badges and louder
pop/shake styles as too silly for the military theme. Still background-free.

- **Look:** the message is Source Sans Pro Bold in the UI kit's status gradient
  (success = header green 176,255,1 → 23,223,0; error = close-button red
  255,107,83 → 233,51,43; other kinds derive from their style color), with a dark
  `16,23,16` outline and a hard dark drop, like the kit's pressed buttons. A matching
  mark leads it: check, X, `!`, `i` or dots, drawn with `Path2D` vector lines (rotated
  Frames looked stair-stepped and jittered when scaled) in the status mid-tone, with the
  same outline (lengthened past the flat Path2D ends) and drop. The narrow `i`, `!` and
  pending dots draw 30% heavier, and stacked pieces leave room for both outlines and
  the drop shadow so they never merge into one dark bar. All shadows, then all outlines, then all faces are layered, so
  the X's strokes cross cleanly.
- **Motion (`Theme.NotificationFlair`):** the group fades and slides down
  (`Motion:Toast`); the mark draws itself (check in one pen move, X in two quick
  strokes); the text wipes in left to right behind the pen; then success gives the
  check one small pop and errors give the line one short nudge. Repeats only
  pop the mark. Exit (`Theme.NotificationLeave`) wipes the text away to the
  right while the group fades. Same-property steps chain on `Completed`, because a
  later `Play()` cancels an earlier tween even during its delay. Reduced motion
  shows it at rest.
- **Layout:** `layoutNotification` measures with `TextService` and shrinks the font
  until icon plus text fit (two-line messages supported). The invisible `Toast`
  label stays as the measuring surface for callers such as recruit messages.
