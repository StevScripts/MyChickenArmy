# Social moments, Visit and the invite prompt (October 27, WS7)

Plan and evidence: `docs/team/retention-20261027/WS7-social.md` (integration:
`docs/team/RETENTION_PLAN_20261027.md`). Live 1.25.0 data: 86% of player-minutes are
spent beside another player, but nobody meets (5 chat messages in 1,530 sessions, 92%
with no friend in the server). This turns other players' firsts into something you see,
want and can visit. Server fill is not the problem; the dashboard settings below are
small adjustments.

## Rules

- **Moments are server-authoritative.** `src/server/SocialService.luau` fires the
  `ServerMoment` RemoteEvent to every other loaded player; the actor never receives their
  own (their reveal already exists). Rules live in the pure
  `src/shared/SocialMoments.luau`; the client presents in `src/client/ServerMoments.luau`.
- **What is a moment** (each at most once per visit per actor):

| Kind | Trigger (server) | Chat line | Toast + far beacon | Visit button |
|---|---|---|---|---|
| `find` Rare | A Buy whose chicken was not in the Index yet (`recruit.offer.firstFind`, WS4; fallback: the offer's species was undiscovered before the Buy) | yes | no | no |
| `find` Epic+ | Same, Epic, Legendary, Mythic or Secret | yes | yes (rarity colour) | yes |
| `camp` | `BattleService.onFirstWin` (WS1) on Fort Roost (2) or Ironbeak HQ (3); Cluck Camp is never announced | yes | no | no |
| `king` | `onFirstWin` with `isKing` | yes | yes (gold) | yes |
| `rebirth` | The `Rebirth` action succeeds (ranks 1–50; Rebirth 0 is never announced; Auto Rebirth is not hooked) | yes | rank 5+ only | no |
| `hill` | `HillService:Close` with a winner | yes, to non-participants only (participants get the round result) | no | no |

- **Rate limits.** Server: one moment per actor every 45 s, at most 6 a minute per
  server (a rolling minute; a moment into an empty server spends nothing). Client: at
  most one toast or beacon every 20 s; chat lines always show.
- **Tutorial quiet rule (Oct 25 owner rule).** While the viewer's own tutorial is on,
  nothing shows (no chat line, toast or beacon); the client counts `moment.missed`. The
  signal: WS5's `app:TutorialComplete()` when present, else `Hud.tutorialStage` (the
  `Hud:SetTutorialStage` signal) and the saved tutorial facts (`SocialMoments.TutorialDone`:
  guide completed, core done, skipped, a camp won, or a pre-guide save).
- **Nothing changes Coins, chickens or saves.** `invitePrompt`, `socialInvited` and
  `socialAnnounced` are transient session fields; no `DataRevision` bump.

## Copy (exact)

`{Name}` is the actor's DisplayName (Roblox-moderated, not typed text, so no filter
call); `{Chicken}` is `PetCatalog[species].name`; `1 in {X}` is
`PetCatalog.OneInText(species)`, the podium tag's own whole-number figure.

- find: `{Name} found {Chicken}! 1 in {X}` (e.g. "Ana found Magma Chicken! 1 in 10,500")
- camp: `{Name} conquered {Camp}!` (Fort Roost / Ironbeak HQ)
- king: `{Name} defeated the Chicken King!`
- rebirth: `{Name} reached Rebirth {N}!`
- hill: `{Name} won the Hill!`
- Visit button: `Visit`; reply after the teleport: `You're at {Name}'s base.`
- Visit refusals: "That base is empty.", "That's your own base.", "Finish the tutorial
  first.", "Base teleport ready in Ns." (shared with My Base), "Your character will be
  ready in a moment.", "Visiting is off right now."
- Invite prompt message: `Play with a friend: +10% Coins for each friend in your server!`
  (the percentage is `Config.FriendBoost.PerFriend`).

## Presentation

- **Chat line:** `TextChatService.TextChannels.RBXSystem:DisplaySystemMessage`, rich text
  in the moment's colour (rarity colour for finds, gold for the King and Rebirths,
  Conquest red for camps, Rewards gold for the Hill). Phones keep the chat collapsed; the
  toast carries Epic+.
- **Toast:** `app:Notify(text, "event")`, the existing top-centre banner. A Visit
  `Theme.ActionButton` (Base colour) sits inside the same banner at the strip's right end
  (Scale only, aspect 2.4); 14 no-break spaces after the text keep the text clear of it.
  The button leaves when another notice takes the banner. No new HUD element.
- **Far beacon:** `app.worldFeel:Beacon(position, color, Config.Social.Moments.BeaconSeconds)`
  at `Config.PlotPositions[plotIndex]` (Y from the viewer's own root). WS6 owns
  `WorldFeel:Beacon` and its `RareFind` cue (see `GAME_FEEL_20261021.md`); while it is
  missing the beacon is skipped.

## Visit

`RequestAction {action="VisitPlot", plotIndex}`. The server checks Social and Visit are
on, the plot index is valid and occupied by another loaded session, the visitor's own
tutorial is over, the character is alive, and the GoBase wait (`session.lastGoBase`, 2 s,
same message). Then a following Army is sent home (`ArmyCommandService:Release`) and the
character is pivoted to `WorldService:SpawnFrame(plotIndex) * CFrame.new(0, 0, 6)`.
The Army itself stays where it is. Prompts on a foreign plot stay off
(`CanUseStation` "Walk up to your own roll machine" is unchanged) and home plots are safe
from attack, so a visitor can only look. "My Base" brings them home.

## Invite prompt (one per visit)

- **Server** (`SocialService:HighMoment`): the first of Rebirth 0 (`RebirthIntro`
  success), the player's own Epic+ first find, or the first Fort Roost win, once per
  visit, after the tutorial, at least `Config.Social.Invite.MinSessionSeconds` (240) into
  this visit's Playtime clock, never with a Friend Boost above 0. It sets
  `session.invitePrompt` and records `invite.prompt` (detail = trigger); the next snapshot
  carries `state.invitePrompt` once.
- **Client** (`FriendBoost:Prompted`): waits `DelaySeconds` (3) for the celebration, then
  until no popup is busy (WS5 `app:ModalBusy()`) and `QuietAfterPurchasePromptSeconds`
  (60) have passed since the last Roblox purchase prompt (WS3
  `commerce:LastPromptAt()`); gives up after 90 s or when a friend arrives. It opens
  Roblox's own invite prompt (owner Oct 20: no popup of our own) with
  `ExperienceInviteOptions.LaunchData = "inv:<inviterUserId>"`.
- **Exposed:** `FriendBoost.lastInviteAt` (os.clock of the last invite prompt, nil until
  one; WS3 keeps checkout 60 s away from it) and `app.friendBoost.invitePromptOpen` (true
  from the prompt until `GameInvitePromptClosed`, at most 60 s; feeds WS5's `ModalBusy`).
- **No reward for inviting** (alt-account abuse; Friend Boost already pays co-presence).

## Analytics (schema 16, already declared)

- Server events: `social.moment` (kind), `social.visit`, `invite.prompt` (trigger).
- Client events: `moment.seen` (kind), `moment.missed` (kind), `invite.sent` (reason:
  button / Rebirth0 / EpicFind / FortRoost; value = recipients; only when at least one
  friend was invited).
- Social funnel: MomentSeen, Visited, InvitePrompted, InviteSent (`AnalyticsFunnels`).
- Join source: `seg.join.invite` (LaunchData `inv:`), `seg.join.notification`
  (`note:`, phase 2).
- Journeys: `sv` (players in the server at join, self included), `fr` (friends in the
  server). Snapshot `indexFound` (different chickens in the Index).

## Config (`Config.Social`) and rollback

```
Social={Enabled=true,
 Moments={Enabled=true,ChatMinRarity="Rare",ToastMinRarity="Epic",RebirthToastRank=5,
  ActorGapSeconds=45,ServerPerMinute=6,ToastGapSeconds=20,BeaconSeconds=10},
 Visit={Enabled=true},
 Invite={Enabled=true,MinSessionSeconds=240,DelaySeconds=3,QuietAfterPurchasePromptSeconds=60},
 Notifications={Enabled=false,DelayHours=20}},
```

- Toasts too noisy: `Moments.ToastMinRarity="Legendary"` (Epic becomes chat only).
- Everything off: `Moments.Enabled=false`, `Visit.Enabled=false`, `Invite.Enabled=false`,
  or `Social.Enabled=false`.
- Kill criteria after two days: 5-minute survival down 2 pp or more, or exits within
  10 s after `moment.seen`.

## Dashboard settings (Stevin; no code)

Record the date each one is saved here, because the ledger has no setting history.

1. **Server Fill** (Places > My Chicken Army > Access/Settings): Customize, reserve
   **1** slot for social joins. Server Size stays **6** (`#Config.PlotPositions`; more
   only kicks). If the label differs, pick the option that reserves the fewest slots
   above 0. Saved: 2026-10-27 (Stevin)
2. **Custom matchmaking** (Creator Dashboard > My Chicken Army > Configurations > Custom
   matchmaking > Create Configuration). Preview on the mock servers first; Friends must
   stay larger than all the others together. Saved: 2026-10-27 (Stevin; mock preview: fullest server wins)

| Signal | Default | New |
|---|---|---|
| Friends | 15 | **30** |
| Occupancy | 2 | **8** |
| Language | 2 | **6** (32% of sessions are es/pt) |
| Latency | 3 | 3 |
| Text Chat | 3 | **2** |
| Play History, Age, Voice, Device | 2, 1, 1, 0 | unchanged |

   Targets: alone at join 9.8% → 6% or less; 1-player server-minutes 33.9% → 25% or less.
   Rollback: switch back to Roblox default (one click).
3. **Description** (Basic Settings), paste as is (fixes "Cash", "Fuse" and "three
   chickens"; 1 in 200,000 is the Secret threshold). Saved: 2026-10-27 (Stevin)

```
Pull the lever, find rare chickens and build the biggest chicken Army on the island!

⭐ How to play
🎰 Pull the lever for chickens: from 1 in 4 all the way to 1 in 200,000 Secrets
🥚 Your Flock lays eggs: sell them for Coins
⬆️ Spend Coins on Upgrades: Flock Size, Egg Speed, the Egg Vacuum and more
⚔️ Send your Army to conquer Camps, win the Hill and beat the Chicken King
🔁 Rebirth for bigger eggs and Gems
👫 Play with friends: +10% Coins for each friend in your server!

👍 Like the game and join the group for a free chicken!
```

4. **Genre:** keep Simulation / Incremental Simulator; clear "All" if it still shows.
5. **Creative:** retire thumbnail 2 ("Ⓔ Attack": device-specific copy and a PvP that does
   not exist); A/B one new creative against the current one: the lever, a chicken popping
   out with a big "1 in 9,400!" tag, eggs turning into Coins. Keep the horde thumbnails
   (1, 3) as secondary slots until the Army visibly marches by minute ~5; thumbnail 4
   ("100/s → 924,294,923/s") can stay.
6. **Phase 2 only** (not built): Experience Notifications need an Open Cloud key with the
   notifications scope in the experience's Secrets and the message string asset
   (`Your Flock laid {coins} Coins while you were away!`, LaunchData `note:offline`).

## Interfaces consumed (nil-safe on this branch)

- WS1: `BattleService.onFirstWin(attacker, campIndex, isKing)` (GameServer sets it).
- WS4: `recruit.offer.firstFind` on the Buy receipt (fallback: the pre-Buy Index check).
- WS6: `WorldFeel:Beacon(position, color, seconds)` (skipped while missing).
- WS3: `CommerceController:LastPromptAt()` (no quiet window while missing).
- WS5: `app:TutorialComplete()`, `app:ModalBusy()` (fallbacks: the HUD tutorial stage and
  the saved facts; no busy wait).

## Verification

- Headless: `tests/SocialMomentsChecks.luau` (Classify per kind and rarity edge, the kill
  switches, the exact copy and whole-number odds, colours, both rate limits, the toast
  gap, the tutorial facts, the invite gates, and SocialService against a fake server:
  recipients, repeats, empty server, Hill participants, first wins, the invite once,
  every Visit refusal, the teleport spot and the shared wait).
- Studio (`multiplayer_playtest`, two clients, Pet Roll Test): A gets an Epic first find
  → B sees the chat line, toast with Visit and the beacon, A sees nothing extra; B presses
  Visit → lands at A's sign, A's prompts stay off for B, My Base returns home and the wait
  is shared; B in `TestNewPlayer` sees nothing and counts `moment.missed`; A's Rebirth 0
  after 240 s opens the invite prompt once, and a Coins-pack prompt within 60 s holds it;
  B as a Hill participant gets no Hill line; a 749×381 phone viewport shows the Visit
  button inside the toast, nothing clipped.
