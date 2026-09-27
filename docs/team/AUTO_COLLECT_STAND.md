# Auto Collect purchase stand — September 25, 2026

Authorized: replace the existing Gamepass stand's sample advertising with the
approved vacuum model, floating/rotating preview, name and live Robux price.
Stepping on the pad depresses it and opens native checkout once per visit.
Owned state replaces the price without changing the player's automatic setting.

Ownership for this task: new `client/AutoCollectStandController.luau`, narrow
start/step/destroy integration in `client/BaseController.luau`, this record,
`assets/auto-collect-stand/`, and the Gamepass display descendants in the six
authored home plots plus the retained AuthoredHomePlot template. No edits to
other tasks' dirty files, commerce services, vacuum gameplay, or shared theme.

Canonical Studio: Pet Roll Test, 96683186622050, instance:69i-u8j, Edit mode.
BaseController has one active copy and matched disk before editing (24151 bytes,
rolling hash 343888521). An existing Rojo server owns mapped source synchronization.
Studio asset changes are separate from saved/published place state.

## Implementation

The seven authored displays (six home plots and the retained template) reuse the
existing nine-part EggVacuum asset. `AutoCollectPreview`, `OfferAnchor` and its
editable `AutoCollectOffer` BillboardGui are added inside each existing Gamepass
model. The upper plate is named `AutoCollectPad`; its old weld is disabled so
only that plate depresses. Original placeholder GUIs and large ray emitters are
disabled, and the original Glow emitter is reduced and placed beneath the model.
Original stands are retained in `ServerStorage.AutoCollectStandRecovery20260925`.
Reapply recipe: `assets/auto-collect-stand/author_stands.luau` through Studio Flow
in Edit mode. No individual studs, asset uploads, or replacement map geometry.

The new controller starts/steps/destroys from BaseController. The player can buy
on their own plot. Billboard labels reflect the local player's live commerce
state on every stand; owned players see Owned and the current on/off setting.
The price loads through CommerceController and refreshes near the stand every
two minutes using its existing cache. No fallback to the proposed catalog price.
Purchase entry uses `Buy("AutoCollectEggs")`, preserving PreparePurchase,
native checkout and verified server ownership. No entitlement/toggle mutation.

Native TweenService loops drive the 16-second full rotation and 1.8-second
reversing 0.24-stud bob. Motion pauses beyond 80 studs or in reduced motion.
Actual supporting-pad contact depresses the plate 0.18 studs over 0.25 seconds;
release takes 0.1 seconds. Checkout is once per visit, with a three-second
cooldown. Jumping in the same footprint does not rearm it. Menus, text input and
existing checkout block entry. Reduced motion preserves functional contact.

## Evidence and limitations

- Rojo packaging and source compilation passed. Both mapped modules matched
  disk; the current controller is 9720 bytes, rolling hash 914085897.
- Rojo initially created two identical new modules. One active copy remains;
  the extra is retained as `DuplicateAutoCollectStandController` in the recovery
  folder. A subsequent source edit reached the active copy through Rojo.
- `assets/auto-collect-stand/checks.luau` passed 31 isolated checks against the
  authored stand, real tweens/raycast, and mocked commerce. Includes correct
  native pass routing after server preparation, no duplicate entry/cancel/jump
  requests, errors/loading, exact live-price display, owned/toggle states,
  reduced motion, pad travel/base stability and cleanup.
- Edit viewport inspection confirmed the vacuum, outlined name/price/hint,
  soft glow, and exactly one enabled label per stand.
- A short session-only Play run loaded all six local displays without new
  script errors. The current player already owns the pass; all labels correctly
  showed Owned and Auto Collect is on.
- A disposable cloned stand with the real R15 character produced one mocked
  purchase, 89/90 grounded samples, no re-prompt on cancellation, and no foreign
  plot activation. No real checkout or purchase was invoked.
- Live visual motion could not be verified: Studio reported no rendered frame,
  and Computer Use reported the Mac is locked. Even a standalone native tween
  remained Playing without advancing; gameplay motion is therefore unverified,
  despite the earlier successful isolated tween checks. The user was asked to
  unlock the Mac. Play was stopped and all fixtures were removed.

No place save/publish, upload, purchase, commit, push or saved-player-data change.
Save the authored Studio place separately to persist the stand art; source files
and the reconstruction recipe are already saved locally. Task file ownership is
released, with only the visible gameplay-motion review outstanding.
