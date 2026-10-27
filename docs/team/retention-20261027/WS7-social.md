# WS7 — Social pull, server fill, ad-expectation match

Live build 1.25.0-eight-cards, ledger Oct 26–27 (2 days, 1,530 sessions, 1,383 unique,
1,341 new). Local `Config.Version` is already `1.26.0-first-minute` (c6153d1, not yet live).
Owner rules respected: Oct 15 later Missions rule (no flags, holding or contests), Friend
Boost never on steady income, HUD not restructured, one Scale-only layout, map
Studio-owned, additive saves only, AGENTS.md player-facing words. Stevin: "just do it", so
every item below is a decision. The only steps he does himself are dashboard settings.

---

## 1. Problem and evidence

All numbers come from `quit/raw125.json` and `quit/summary125.json`, computed with `python3 -I`.

### 1.1 Servers are not empty. Players are in the same server but never meet.

The brief says "servers hold 1–2 players". That is true per server-minute, but not for
what a player experiences:

| Measure | 1 player | 2 | 3 | 4–5 | 6 | n |
|---|---|---|---|---|---|---|
| Server-minutes (`server.players`) | 33.9% | 24.5% | 18.5% | 22.7% | 0.4% | 5,225 |
| Player-minutes (weighted) | **13.9%** | 20.2% | 22.9% | 42.0% | 1.0% | ≈12.7K |
| Server size at join (`seg.serverSize`, includes self) | **9.8%** | 17.1% | 20.3% | 51.8% | 1.0% | 1,558 |

- `maxPlayers = 6` (games API, live). The code can never go above that: `GameServer:AddPlayer`
  assigns one of the six `Config.PlotPositions` and kicks a seventh player ("All plots are
  full"). Peak players in any server = 6 (`server.peakPlayers`).
- 86% of player-minutes are spent with at least one other player, and 52% of joins land in a
  server with 3–4 other players. **Server fill is not the bottleneck.**
- Nobody interacts:
  - **Chat:** 5 chat messages in 1,530 sessions (`ui.chat.sent`).
  - **Friends:** 91.6% have no friend in the server (`seg.friendsInServer` 0 = 1,427/1,558).
    Follow joins are 131 (8.4%).
  - **Shared systems:** the Hill was entered by 94 players (~7% of uniques; 35 won).
    Missions were started by 16 players, because they are gated behind the King or
    Rebirth 5. Any-lane territory was first used by 234 players, mostly late. The
    Leaderboard was "viewed" 1,269 times, but the boards are global top-100 lists that a
    new player never appears on.
- **Survival:** 76% at 1 min, 48% at 3, 36% at 5, 21% at 10, 7% at 30. Cohort Oct 26 D1 is 4.7%.

### 1.2 Friends are a small and unproven lever for ad traffic

- Players who joined by following a friend returned at the same rate as everyone else
  (Oct 23 profile scan: 4/62 = 6.5% vs 7.1% direct). So invites are mainly cheap
  acquisition, not proven retention. They rank below in-server visibility.
- The Friend Boost "+" button (FriendBoost.luau → `SocialService:PromptGameInvite`) is not
  in the top-30 clicks, so it has fewer than 562 clicks in 2 days. Nothing records invites
  sent, and nothing tags joins that came from an invite.

### 1.3 The ads promise a horde; the first three minutes show one or two chickens

The live listing (games API plus 4 thumbnails, read Oct 27):

- **Thumbnail 1:** helmeted chicken leading a horde, giant eggs behind.
- **Thumbnail 2:** a player with an "Ⓔ Attack" prompt and a crowd of angry chickens.
- **Thumbnail 3:** helmeted chicken and an endless field of chickens, titled "My Chicken Army!".
- **Thumbnail 4:** "🥚100/s" basic chicken vs a cosmic chicken at "🥚924,294,923/s".

What players actually get:

- 79% of sessions end with an Army of 3 or fewer (`state.armySize` le3 1,215/1,530).
- The first Attack is a median of about 3 minutes in (`features.Attack` p50 le180).
- The description is stale and wrong against the current game:
  - It says "Collect eggs and sell them for **Cash**", but the currency is Coins.
  - It says "**Fuse** matching chickens into Giants", but Fuse was removed Oct 20.
  - It says "Start with **three chickens**", but the Oct 23 empty start gives none.
- Genre is "All" (`isAllGenre: true`; l1 Simulation / l2 Incremental Simulator).
- 98% of ad spend runs on one creative (Oct 23 dashboard read). We do not know which one.
  All four thumbnails sell either the horde or the income number.

### 1.4 Where social could plausibly move retention

These are moments that already happen and that other players never see. The rates are per
server-hour (87 server-hours in the window):

| Moment | Count in 2 days | Per server-hour |
|---|---|---|
| Rare bought | 552 | 6.3 |
| Epic or better bought | 123 | 1.4 |
| Fort Roost first wins | 135 | 1.6 |
| Ironbeak HQ first wins | 78 | 0.9 |
| King first clears | 21 | 0.2 |
| Rebirths | 62 | 0.7 |
| Hill wins | 61 | 0.7 |

That is about 12 moments per server-hour, or one every ~5 minutes, in a server where the
average player is beside 2–3 strangers. This is exactly the "proof of rarity / what's
possible" signal that roll games such as Pet Simulator and Drop a Fruit put in front of
everyone.

---

## 2. Root cause in code and settings

| Area | What exists | Shared moment? |
|---|---|---|
| Server size | Dashboard `maxPlayers=6`. `GameServer:AddPlayer` loops `Config.PlotPositions` (6 entries) and kicks a 7th player. | n/a |
| Plot layout | Six plots on a ring about 310 studs from centre; neighbours are about 311 studs apart. Spawn faces the own lever and yard (`WorldService:SpawnFrame`). StreamingEnabled is on, so far plots may not be streamed in. | None: a player cannot see a neighbour's yard, rolls or eggs. |
| Rolls | `RollStation` offer labels have `MaxDistance=38`. The reveal is client-only for the roller (`StateChanged:FireClient`). The only remote fired to everyone is `BattleChanged`. | None. |
| Eggs, Flock | Per-plot actors | None. |
| Armies | Marches run on the own lane toward camps, which point outward, away from others. Any-lane attacks exist (ANY_LANE_ATTACKS.md), but the tutorial locks players to their own Cluck Camp, and the first targets are your own camps. | Late game only. |
| Missions | `OperationService`: one island-wide pool, the first army sent claims a site. Tier 1 needs a King clear or Rebirth 5 (`Config.Rebirth.MissionTierRanks={5,10,15}`). | Exists but almost nobody reaches it (16 starters). The Oct 15 rule forbids holding or contests. |
| Hill | `HillService`: 5-min rounds every 10 min. The banner "The Hill is open!" goes only to players with `kingCleared`. Guards are at Ironbeak HQ strength. | Yes, but only for ~7% of players. |
| Gold Rush | Server-wide clock multiplier | Shared clock, but it does not involve other players. |
| Friend Boost | `FriendBoostService` (+10% per friend, max +50%, live earned Coins only). Client `FriendBoost.luau` "+" opens Roblox invites. | Only when a friend is present (8%). |
| Leaderboards | `LeaderboardService`: three global OrderedDataStore boards (Strongest Army, Top Rebirths, Robux Spent) on every plot | Global, so a new player is never on them. |
| Broadcast plumbing | `session.banner` per player becomes `AppController:Notify` (line 1073). Admin `announce` loops sessions. No `TextChatService` system messages. | Plumbing exists; nothing uses it for other players' deeds. |

**Root cause:** the server holds 3–5 strangers whose progress is invisible to each other.
No system turns another player's luck or win into something you see, want, or can visit.
The listing then promises a horde the first session never delivers.

---

## 3. Options and recommended design

### Ranking (retention impact per effort)

| # | Item | Effort | Impact | Decision |
|---|---|---|---|---|
| 1 | **Server Moments feed:** other players' first Rare+ finds, Fort Roost / Ironbeak / King firsts, Rebirth N, Hill winner. Shown as chat system line + toast + far beacon. | ~1 day | Medium: a social proof loop every ~5 min and a visible "1 in 9,400 exists" | **Build now** |
| 2 | **Listing fix:** description, genre, creative brief | 30 min (Stevin) | Medium on ad CTR→play quality; removes broken promises | **Do now** |
| 3 | **Matchmaking/fill settings** | 15 min (Stevin) | Small: about 10% of joins are alone; language matching helps the 32% es/pt players | **Do now** |
| 4 | **Visit button** on Epic+ / King toasts: teleport to that player's plot sign | ~0.5 day | Small–medium: the first reason to look at another player | **Build now (phase 1b)** |
| 5 | **Invite prompt after a high moment:** one Roblox invite prompt per session, tagged with LaunchData | ~0.5 day | Small for retention, positive for free installs | **Build now** |
| 6 | **Experience Notifications opt-in** plus a next-day "your eggs piled up" moment | 1.5–2 days and an Open Cloud key (Stevin) | Possibly the best D1 lever here (13+ only) | **Phase 2, after 1–5 ship** |
| 7 | Server-local leaderboard ("Strongest Army in this server") | 0.5 day | Small | Not now: boards are Studio-authored map pieces, and rule-safe space is limited |
| 8 | Co-op Missions (several armies on one site, each participant paid) | 2–3 days in BattleService | Unknown; gated late anyway | **Rejected for now.** It is compatible with the Oct 15 rule only as a single fight with no holding. Missions are unreachable for 99% of players, so it does not touch the leak. |
| 9 | Bigger servers (more than 6) | Needs new plots (map is Studio-owned) | Low: fill is already fine | **Rejected** |
| 10 | Trading or gifting | Large; scam and moderation surface | n/a | Out of scope |

### 3.1 Server fill and matchmaking (Stevin, Creator Dashboard)

Leave **Server Size at 6**. It must equal `#Config.PlotPositions`; raising it only creates kicks.

**Server Fill.** In Places → My Chicken Army place → Access/Settings, the "Server Fill"
setting: choose **Customize** and reserve **1** slot for social joins. Today's data (6-player
servers are only 0.4% of server-minutes) suggests Roblox Optimized already holds one or two
slots back. Fixing it at 1 lets 5 strangers fill a server and keeps one seat for a friend
or invite. Roblox does not document this menu clearly (a DevForum report of a Custom-slots
bug, Oct 2025), so if the label differs, pick the option that reserves the fewest slots
while it is still above 0.

**Custom Matchmaking.** In Creator Dashboard → My Chicken Army → **Configurations > Custom
matchmaking** → Create Configuration. Roblox default weights are Friends 15, Latency 3,
Text Chat 3, Occupancy 2, Play History 2, Language 2, Age 1, Voice 1, Device 0. Set these:

| Signal | Default | New | Why |
|---|---|---|---|
| Friends | 15 | **30** | Must stay larger than the sum of all the others, so friends still always land together |
| Occupancy | 2 | **8** | Prefer the fuller server; cuts the 9.8% alone-at-join and the 33.9% single-player server-minutes |
| Language | 2 | **6** | 32% of sessions are es/pt (293 + 188 of ~1,486 locales). Chat lines and the Visit button only work socially if players share a language. |
| Latency | 3 | 3 | Keep |
| Text Chat | 3 | 2 | Nobody chats (5 messages) |
| Play History, Age, Voice, Device | 2, 1, 1, 0 | unchanged | |

Preview it on the dashboard's mock servers before saving. Record the date in
`docs/team/SOCIAL_MOMENTS.md`, because the ledger has no setting history.
**Target:** alone-at-join drops from 9.8% to 6% or less, and 1-player server-minutes drop
from 33.9% to 25% or less.

### 3.2 Server Moments (the core build)

Each moment is server-authoritative and fired to all clients except the actor with a new
RemoteEvent `ServerMoment`. Presentation tiers:

| Kind | Trigger (server) | Chat line (everyone else) | Toast + far beacon | Visit button |
|---|---|---|---|---|
| `find` Rare | First time this species enters the player's Index (`firstFind`) and its rarity is Rare | yes | no | no |
| `find` Epic+ | `firstFind`, rarity Epic, Legendary, Mythic or Secret | yes | **yes** (rarity colour) | **yes** |
| `camp` | First win on Fort Roost or Ironbeak HQ (own lane, `firstWins[i]` flips) | yes | no | no |
| `king` | First King clear | yes | **yes** (gold) | **yes** |
| `rebirth` | `Rebirth` succeeds (ranks 1–50); Rebirth 0 is skipped because it is too common | yes | rank ≥ 5 only | no |
| `hill` | `HillService:Close` with a winner | yes, to non-participants only (participants already get the Hill result) | no | no |

**Exact copy.** `{Name}` is the actor's DisplayName, already moderated by Roblox and not
user-typed text, so no filter call is needed. `{Chicken}` is `Catalog[species].name` and
`{X}` is `Currency`'s whole-number format of `Catalog[species].oneIn`:

- find: `{Name} found {Chicken}! 1 in {X}`
- camp: `{Name} conquered {Camp}!`, where Camp is "Fort Roost" or "Ironbeak HQ"
- king: `{Name} defeated the Chicken King!`
- rebirth: `{Name} reached Rebirth {N}!`
- hill: `{Name} won the Hill!`
- Visit button label: `Visit`. After teleporting, the toast reads `You're at {Name}'s base.`

**Chat line.** The client calls `TextChatService.TextChannels.RBXSystem:DisplaySystemMessage(text)`.
It uses the system channel, so it costs nothing and needs no filtering for our own strings.
Phones keep the chat window collapsed; that is fine, because the toast carries Epic+.

**Toast.** `app:Notify(text, "event")` reuses the existing banner and the "(xN)" stacking.
It adds a small Visit ActionButton inside the existing notice frame, so no new HUD element
and no HUD restructure. All Scale.

**Far beacon.** Add a new shared method `WorldFeel:Beacon(position, color, seconds)`: a
client-local, anchored Neon cylinder (2 × 140 studs, CanCollide/CanQuery/CanTouch false,
CastShadow false) at `Config.PlotPositions[plotIndex]`. It fades in and out with one
TweenService tween (AGENTS "Simple animations"; `RepeatCount=1, Reverses=true`), with a
`WorldFeel:Sound("RareFind")` positional cue. Because it is client-local at a known
position, streaming does not matter. It skips `WorldFeel:Near`, so it is visible across the
island, but it still goes through `WorldFeel:Take` and respects reduced motion (beacon
static, no tween). The sound cue is named in the contract and is silent if missing
(`MyChickenArmyAudio`). At most one beacon at a time.

**Rate limits.** Defined in `SocialMoments` and enforced in `SocialService`:

- Server: per actor, one moment per 45 s (`ActorGapSeconds`); per server, at most 6 per minute.
- Client: at most one toast or beacon per 20 s (`ToastGapSeconds`). Chat lines are always shown.
- **Tutorial quiet rule (Oct 25):** while the local player's tutorial is not complete, the
  client shows nothing (no chat line, toast or beacon), only counts `moment.missed`. It reads
  the same tutorial-complete signal `Hud:SetTutorialStage` already uses.
- The actor never receives their own moment; their own reveal already exists.

**Visit.** New `RequestAction` `VisitPlot {plotIndex}`. The server checks:

- the plot is occupied by a loaded session;
- the player is not in their own tutorial;
- the cooldown is shared with `GoBase` (`armyCommands` cooldown, same "ready in Ns" message);
- the player's character exists.

It then does `character:PivotTo(world:SpawnFrame(plotIndex) * CFrame.new(0,0,6))`. Home
plots are already safe from attack (ANY_LANE_ATTACKS), so a visitor cannot interfere.
Prompts on foreign plots stay disabled, because the station checks
(`CanUseStation` "Walk up to your own roll machine") are unchanged. The existing "My Base"
HUD button (`Hud/MyBase`, 587 clicks) brings them back.

### 3.3 Invite prompt timing

- **Trigger:** once per session, the first of these after the tutorial is complete and at
  least `MinSessionSeconds=240` into the session:
  - the `RebirthIntro` (Rebirth 0) success, 485 players p50 ≤ 5 min;
  - the player's own Epic+ first find;
  - the first Fort Roost win.
- Skip it when `FriendBoost` > 0 (a friend is already here).
- **Delay:** 3 s after the celebration so the reveal finishes first.
- **Quiet window:** no invite prompt within 60 s of any Roblox purchase prompt, in either
  direction. This is the interface with WS3.
- **Prompt:** Roblox's own prompt directly (owner Oct 20: "no popup of our own"), through the
  existing `FriendBoost:Invite()`, extended with a reason and options:
  - `ExperienceInviteOptions.PromptMessage = "Play with a friend: +10% Coins for each friend in your server!"`
    (the percentage comes from `Config.FriendBoost.PerFriend`);
  - `ExperienceInviteOptions.LaunchData = "inv:<inviterUserId>"`.
- **Join tagging:** `AnalyticsPlayer` parses `GetJoinData().LaunchData` and, if it begins with
  `inv:`, sets `joinSource = "invite"`. This is a new value, added by appending; the old
  ones are unchanged.
- **No reward for inviting.** No Gems for referrals in this pass: it needs a save field and
  invites abuse from alt accounts, and Friend Boost already pays co-presence.

### 3.4 Ad-expectation match

**Description.** Stevin pastes this in Creator Dashboard → Basic Settings. It fixes Cash,
Fuse and "three chickens" and uses AGENTS words. The "1 in 200,000" is the Secret threshold.

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

**Genre.** Keep Simulation / Incremental Simulator, and clear "All" if the dashboard
still shows it.

**Creative brief.** This is one new ad creative and thumbnail to A/B against the current
98% one. Stevin makes the art; the chunky-simulator-icons skill or `codex exec` can render
it.

- **The first-minute promise is what the game shows by minute 1:** the lever, a chicken
  popping out with a big "1 in 9,400!" tag, eggs turning into Coins.
- Drop a Fruit's pattern: one verb plus its reward.
- Keep the horde thumbnails (1 and 3) only as secondary slots until WS1/WS2 make an Army of
  8 or more march by minute ~5.
- Thumbnail 4's "100/s → 924,294,923/s" matches the game (`Currency.Rate` whole numbers)
  and can stay.
- Thumbnail 2's "Ⓔ Attack" is device-specific copy ("Press E" is banned in-game) and sells a
  PvP that does not exist. Retire it.

**What the first 3 minutes should show** (acceptance criteria for WS2/WS5/WS1; WS7 does not
build these):

1. By 0:20, the lever pulled and a chicken with its "1 in X".
2. By 1:00, Coins rising from eggs.
3. By 3:00, an Army visibly marching (more than 3 chickens on screen) at Cluck Camp.
4. By 5:00, at least one other player's moment seen. This is WS7's own part: about 12 per
   server-hour × 3–4 others, so most 5-minute sessions after the tutorial see one.

### 3.5 Phase 2: Experience Notifications (after 1–5)

- **Opt-in:** `ExperienceNotificationService:CanPromptOptInAsync()` then `PromptOptIn()`. Ask
  once, right after the player claims Offline Coins or after Rebirth 1. Roblox suppresses
  the prompt for under-13s and for 30 days after a dismissal, and its text cannot be changed.
- **Send:**
  - On leave, `SocialService` writes `{userId, dueAt = now + 20h}` to a MemoryStore SortedMap
    `NotifyQueue` (30-hour expiry).
  - Every server polls the queue once a minute (`GetRangeAsync`, ≤ 20 items) and calls the
    Open Cloud `createUserNotification` (Creator Store Open Cloud package) for due entries.
  - It then removes them. One per user per day is a Roblox limit.
- **Message string**, created on the dashboard (≤ 99 chars): `Your Flock laid {coins} Coins while you were away!`.
  The `{coins}` value is the offline estimate at leave time (`OfflineCash` math). LaunchData
  is `"note:offline"`.
- **Needs from Stevin:**
  - an Open Cloud API key with the notifications scope, stored in the experience's
    **Secrets** (Creator Dashboard). Agents never type keys;
  - the message asset id.
- **Gate:** the game needs 100+ visits; it has 31.9K.

---

## 4. Implementation steps (file by file)

### 4.1 `src/shared/Config.luau` (shared, append one block next to `FriendBoost`)

```lua
-- October 27 WS7 social moments (docs/team/SOCIAL_MOMENTS.md): other players' firsts
-- in this server as a chat line, toast and beacon; Visit; one invite prompt per session.
Social={Enabled=true,
 Moments={Enabled=true,ChatMinRarity="Rare",ToastMinRarity="Epic",RebirthToastRank=5,
  ActorGapSeconds=45,ServerPerMinute=6,ToastGapSeconds=20,BeaconSeconds=10},
 Visit={Enabled=true},
 Invite={Enabled=true,MinSessionSeconds=240,DelaySeconds=3,QuietAfterPurchasePromptSeconds=60},
 Notifications={Enabled=false,DelayHours=20}},
```

### 4.2 `src/shared/SocialMoments.luau` (new, pure, Lune-testable)

- `RarityRank` table (Common=1 … Secret=7, the same as ShopCatalog's local).
- `SocialMoments.Classify(kind, data) -> {chat: boolean, toast: boolean, beacon: boolean, visit: boolean}?`
  Returns nil for moments that are not shown.
- `SocialMoments.Text(kind, data) -> string`, with the exact copy in §3.2, using
  `Currency.Text`-style whole numbers for `oneIn`.
- `SocialMoments.Color(kind, data) -> Color3`, from `UIColors` rarity colours or Gold.

### 4.3 `src/server/SocialService.luau` (new)

- `SocialService.new(server)`, where server is `GameServer`. It keeps `lastByActor`,
  `windowCount` and `invited[userId]`.
- `:Moment(session, kind, data)`:
  - checks Config, `Classify`, actor gap and server cap;
  - builds the payload `{kind, userId, name=session.name, plotIndex=session.plotIndex, species, oneIn, rarity, camp, rank}`;
  - calls `remotes.ServerMoment:FireClient(p, payload)` for every other player with a loaded session;
  - fires `analytics:ServerEvent(session,"social.moment",kind)`.
- `:Visit(player, session, plotIndex, now)` follows the §3.2 rules. Returns `ok, message`.
  Messages: "That base is empty.", "Finish the tutorial first.", and the GoBase cooldown message.
- `:HighMoment(session, trigger)` checks the §3.3 gates and sets `session.invitePrompt = trigger`
  (transient, never saved). The client snapshot carries `invitePrompt`, and the client calls
  `FriendBoost:Invite(trigger)`. It fires `analytics:ServerEvent(session,"invite.prompt",trigger)`.

### 4.4 `src/server/GameServer.luau` (shared: WS1/WS3/WS5 also edit it)

- In `Start`, change the remote list to `{"RequestAction","StateChanged","BattleChanged","ServerMoment"}`
  and create `self.social = SocialService.new(self)`.
- In the `Buy` branch, after `ok`: if `recruit.offer.firstFind`, call
  `self.social:Moment(session,"find",{species=recruit.offer.species})`. If the rarity is
  Epic+, also call `self.social:HighMoment(session,"EpicFind")`.
- In the `Rebirth` branch, after `ok`, call `self.social:Moment(session,"rebirth",{rank=session.rebirths})`.
- In the `RebirthIntro` branch, after `ok`, call `self.social:HighMoment(session,"Rebirth0")`.
- New branch: `elseif action=="VisitPlot" then ok,message=self.social:Visit(player,session,request.plotIndex,now)`.
- Add `invitePrompt` to the per-player snapshot fields (or to the session ToState in PlayerSession).
  It is cleared after it is sent once.

### 4.5 `src/server/RollService.luau` (shared with WS4)

In `Buy`, before the pet is added, compute `local firstFind = not session.discovered[species]`
and add `firstFind=firstFind` to the returned `offer` table, which is analytics-only today
(line ~301). That is a one-line change.

### 4.6 `src/server/BattleService.luau` (shared with WS1)

- At the first-win branch (~line 989, `attacker.firstWins[battle.campIndex]=true`, own lane),
  call `if self.onFirstWin then self.onFirstWin(attacker, battle.campIndex, battle.isKing) end`.
- `GameServer` sets `battles.onFirstWin`, which maps:
  - camp 2 → `Moment(..., "camp", {camp="Fort Roost"})` plus `HighMoment(...,"FortRoost")`;
  - camp 3 → `"camp", {camp="Ironbeak HQ"}`;
  - King → `"king"`.
- Camp names come from `Progression.Get(i).name`.

### 4.7 `src/server/HillService.luau`

In `Close`, after the winner is paid, call `if self.social then self.social:Moment(winner,"hill",{exclude=participants}) end`.
`participants` is the set of userIds with `self.seconds[...]>0 or self.entered[...]==self.round`.

### 4.8 `src/server/AnalyticsPlayer.luau` (~line 410)

Read `data.LaunchData`. If it is a string beginning with `"inv:"`, set
`ap.joinSource="invite"`, which is counted as `seg.join.invite` (a new key). If it begins
with `"note:"`, set `"notification"`.

### 4.9 `src/server/Analytics.luau` (~line 946)

Add to the journey record `sv = <server size at join>` and `fr = ap.friends`. This is
additive; old journeys lack them. Store `st.serverSizeAtJoin` where `seg.serverSize` is
recorded.

### 4.10 `src/server/AnalyticsSchema.luau` (shared, append only)

See §5.

### 4.11 `src/client/ServerMoments.luau` (new)

- Connects `Remotes.ServerMoment.OnClientEvent` and calls `Classify` again for the presentation.
- Tutorial quiet rule: while incomplete, call `AnalyticsClient.Track("moment.missed",kind)` and return.
- Chat line through RBXSystem.
- If the toast gap is open and `toast`: `app:Notify(text,"event")` and attach a Visit button
  when `visit` (`Theme.ActionButton(notice,"Visit","Visit",...)` → `RequestAction{action="VisitPlot",plotIndex=...}`).
- If `beacon`: `app.worldFeel:Beacon(plotPosition(plotIndex), color, Config.Social.Moments.BeaconSeconds)`.
  The plot position is `Vector3.new(x, groundY, z)` from `Config.PlotPositions`, with Y taken
  from the own SpawnFrame height.
- `AnalyticsClient.Track("moment.seen",kind)`.

### 4.12 `src/client/WorldFeel.luau` (shared vocabulary)

Add `WorldFeel:Beacon(position, color, seconds)` as described in §3.2. Document it in
`docs/team/GAME_FEEL_20261021.md` under the WorldFeel list.

### 4.13 `src/client/FriendBoost.luau`

- `Invite(reason: string?)` sets `options.LaunchData = "inv:"..player.UserId`. Its
  PromptMessage is the §3.3 copy, built from `Config.FriendBoost.PerFriend`.
- Before prompting, call `self.app.commerce:LastPromptAt()` (the WS3 interface) and skip if
  it was less than 60 s ago.
- Connect `SocialService.GameInvitePromptClosed` (player, recipientIds) and call
  `AnalyticsClient.Track("invite.sent", reason or "button", #recipientIds)`.
- The "+" button passes `"button"`.

### 4.14 `src/client/AppController.luau` (shared with WS5)

- Construct `ServerMoments.new(self)` next to `FriendBoost`.
- In the state handler, if `state.invitePrompt` is new, call
  `task.delay(Config.Social.Invite.DelaySeconds, function() self.friendBoost:Invite(state.invitePrompt) end)`.

### 4.15 Docs (allowed: a contract doc, the AGENTS pattern)

- `docs/team/SOCIAL_MOMENTS.md`: the rules, copy, config, dashboard settings with their date,
  and rollback.
- One AGENTS.md paragraph: "Social moments (October 27)", 4 lines.

### 4.16 Sound

Cue name `RareFind` (and `KingFallen` reused if it exists). Stevin's library is
OwnerApproved, so the plan only names the cue. Missing means silent. He adds the sound himself.

---

## 5. Analytics (append only) and success metrics

### 5.1 `AnalyticsSchema.luau` additions

**`Schema.ServerEvents`:**
- `["social.moment"]="free"`: detail is the kind (find/camp/king/rebirth/hill).
- `["social.visit"]="none"`.
- `["invite.prompt"]="free"`: detail is the trigger (Rebirth0/EpicFind/FortRoost).

**`Schema.ClientEvents`:**
- `["moment.seen"]="free"`: detail is the kind.
- `["moment.missed"]="free"`: detail is the kind (hidden by the tutorial quiet rule).
- `["invite.sent"]="free"`: detail is the reason; value is the recipient count.

**`Schema.FeatureFunnels`**, appended:

```lua
{id = "Social", steps = {
  {id = "MomentSeen", trigger = "client:moment.seen"},
  {id = "Visited", trigger = "server:social.visit"},
  {id = "InvitePrompted", trigger = "server:invite.prompt"},
  {id = "InviteSent", trigger = "client:invite.sent"},
}},
```

**Join source:** `seg.join.invite`, `seg.join.notification` (new count keys).

**Journeys:** `sv`, `fr` fields.

**Version:** `Schema.Version = 16`, with a comment block in the version history. This is
shared: if WS1–WS6 also add analytics, the lead makes ONE Version 16 bump for the integrated
release.

No new Roblox custom events (the 100-event cap stays untouched).

### 5.2 Success metrics

Compare 2 days before and 2 days after with `AnalyticsReport`.

| Metric | Now | Target |
|---|---|---|
| Sessions past the tutorial that see ≥ 1 moment (MomentSeen / tutorial done) | 0 | ≥ 60% |
| Visits per 100 Epic+ toasts | n/a | ≥ 10 |
| Alone at join (`seg.serverSize` le1) | 9.8% | ≤ 6% (dashboard change) |
| Joins with a friend (follow + invite) | 8.4% | ≥ 10% |
| invite.sent / invite.prompt | n/a | ≥ 8% |
| **Primary:** 10-minute survival of post-tutorial sessions that saw a moment, vs those that did not, using journeys `sv` > 1 to control for server size | n/a | +3 pp gap. Then a cohort check: overall 10-min survival 21% → 23% and D1 4.7% → 5.5%, shared with the other WS. |

**Kill switch criteria:** if, after 2 days, 5-minute survival drops by 2 pp or more, or
toasts correlate with exits within 10 s (`exits.action` after `moment.seen`), set
`Config.Social.Moments.ToastMinRarity="Legendary"`, or disable toasts and keep chat lines.

---

## 6. Verification

- **Headless (Lune, `tools/sim` harness per memory):** a `SocialMoments` spec that checks:
  - Classify for every kind and rarity edge (Rare: chat only; Epic: toast + Visit; Rebirth 4 vs 5);
  - Text copy, including the whole-number "1 in 9,400" and a Secret 1 in 200,000+;
  - the rate limiter (45 s per actor, 6 per minute per server).
- **luau-lsp analyze** on the changed files against a HEAD baseline (memory: local Luau checks).
- **Studio** `multiplayer_playtest` with 2 clients, Pet Roll Test place, Edit identity checked:
  1. Player A uses the admin/debug command to get an Epic first find. Check that B sees the
     chat line, toast, Visit button and a beacon over A's plot, and that A sees nothing extra.
  2. B presses Visit. B lands at A's sign. B's roll prompts on A's plot stay disabled.
     "My Base" returns B home. The GoBase cooldown is shared.
  3. B in the tutorial (TestNewPlayer): B sees nothing, and `moment.missed` is counted.
  4. A Rebirth 0 at ≥ 240 s makes the invite prompt open once. A second trigger does not
     open it. A Coins-shortfall prompt within 60 s suppresses it.
  5. Close a Hill round with A as the winner and B as a participant: B gets no feed line.
  6. A phone viewport (749×381) shows the toast with Visit inside the existing notice frame.
     Scale only, nothing clipped.
- **Dashboard:** after Stevin saves matchmaking, confirm on the mock-server preview that
  Friends still dominates.
- **Live:** run `Report.Summarize` 48 h after publish for the §5 metrics, and check
  `seg.join.invite` > 0. Every publish uses "Migrate To Latest Update".
- No save fields are added. `invitePrompt` is transient, so the save checks are unchanged.
  Do not bump `DataRevision`.

---

## 7. Risks, owner-rule conflicts, rollback

| Risk | Mitigation and rollback |
|---|---|
| Toast or beacon noise distracts in the critical first minutes | Tutorial quiet rule; 20 s client gap; chat-only for Rare. Rollback: `Social.Moments.ToastMinRarity="Legendary"`, or `Social.Moments.Enabled=false`. |
| Oct 25 rule "during the tutorial the screen shows only the guide card" | Fully respected: nothing renders before completion. |
| HUD must not be restructured | No new HUD element. The Visit button lives inside the existing Notify toast. |
| Invite modal right after a celebration annoys players | Once per session, ≥ 240 s in, not when a friend is present, 60 s apart from purchase prompts. Rollback: `Social.Invite.Enabled=false`. |
| Owner Oct 20 "+ opens Roblox's list straight away, no popup of our own" | Respected: the same Roblox prompt, no custom dialog. |
| Visit used to grief | Home plots are safe. Foreign prompts are disabled by `CanUseStation`. Visitors can only stand there. Rollback: `Social.Visit.Enabled=false`. |
| Missions rule (Oct 15 later) | Not touched. Co-op Missions rejected. |
| Player-facing words | Copy uses Army, Camp, Coins, Rebirth N, Hill, "found". No "pets", "$", "Press E" or "Tap". |
| Streaming hides far plots | The beacon is client-local at `Config.PlotPositions`, not a streamed part. |
| Performance on low phones (WS6) | One anchored part at a time, one tween, no lights or particles. `WorldFeel:Take` budget and reduced motion apply. |
| Matchmaking change pairs strangers by language and harms latency | Latency weight is unchanged. Preview first. Rollback: switch back to "Roblox default" on the dashboard (1 click). |
| Notifications (phase 2) | Needs a key Stevin creates; `Enabled=false` by default; Roblox's 1/day limit; 13+ only. |
| Analytics Version collision across WS | The lead makes a single bump to 16. |

---

## 8. Files touched and interfaces

### New files
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/shared/SocialMoments.luau`
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/SocialService.luau`
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/ServerMoments.luau`
- `/Users/stevin/Documents/Projects/MyChickenArmy/docs/team/SOCIAL_MOMENTS.md`

### Edited (SHARED = another WS likely edits it too; the lead merges)

| File | Change | Shared with |
|---|---|---|
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/shared/Config.luau` | `Social` block | SHARED: WS1, WS2, WS4, WS5 |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/GameServer.luau` | remote list, SocialService, Buy/Rebirth/RebirthIntro hooks, VisitPlot, `invitePrompt` | SHARED: WS1, WS3, WS5 |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/RollService.luau` | `firstFind` on the Buy return | SHARED: WS4 |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/BattleService.luau` | `onFirstWin` callback | SHARED: WS1 |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/HillService.luau` | Hill moment | |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/AnalyticsSchema.luau` | append | SHARED: all WS |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/Analytics.luau` | journey `sv`/`fr` | SHARED |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/AnalyticsPlayer.luau` | invite/notification join source | |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/AppController.luau` | mount ServerMoments, invite trigger | SHARED: WS5, WS3 |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/FriendBoost.luau` | reason, LaunchData, quiet window, invite.sent | |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/WorldFeel.luau` | `Beacon` | SHARED vocabulary: WS6 perf review |
| `/Users/stevin/Documents/Projects/MyChickenArmy/AGENTS.md` | one rule paragraph | lead only |
| `/Users/stevin/Documents/Projects/MyChickenArmy/docs/team/GAME_FEEL_20261021.md` | list `Beacon` and the `RareFind` cue | |

### Interfaces needed from other workstreams
- **WS3:** `CommerceController:LastPromptAt(): number` (the os.clock of the last Roblox
  purchase prompt shown). In return, WS3 must not open a purchase prompt within 60 s after
  `FriendBoost:Invite` fired. I expose `FriendBoost.lastInviteAt`.
- **WS5:** a single client tutorial-complete signal. The plan assumes the one behind
  `Hud:SetTutorialStage`; WS5 should name it `app:TutorialComplete(): boolean`. The
  post-tutorial card order must leave room for the invite prompt at Rebirth 0, so WS5 must
  not schedule a Daily popup in the same 5 s.
- **WS1:** keeps the own-lane `firstWins` flip as the single first-win point, and calls
  `onFirstWin` there if it moves the code. The ad-match criterion "Army of more than 3
  marching by about minute 3" is WS1/WS2's.
- **WS4:** if RollService:Buy changes shape, it keeps `offer.species` and adds `firstFind`.
  If WS4 changes "1 in X" display data, `Catalog[species].oneIn` stays the source.
- **WS6:** reviews `WorldFeel:Beacon` cost on low-tier phones. WS7 accepts disabling the
  beacon when `ChickenEffectQuality` is low.
- **WS2:** none, except that the description copy uses Coins and Rebirth as they are; if WS2
  changes Rebirth 0's price or rename, update the copy.

### Stevin (dashboard, ~45 min total, no code)
1. Server Fill: Customize, 1 social slot. Server Size stays 6.
2. Custom matchmaking weights per §3.1. Preview, then save.
3. Paste the description from §3.4. Check the genre.
4. Commission the one new creative from §3.4 and A/B it against the current one.
5. (Phase 2) An Open Cloud key with the notifications scope, saved in Secrets, plus the
   message string asset.

### Sources
- [Roblox server scoring](https://create.roblox.com/docs/en-us/matchmaking/scoring): default weights.
- [Customize matchmaking](https://create.roblox.com/docs/en-us/matchmaking/customize-matchmaking): menu path.
- [Experience notifications](https://create.roblox.com/docs/cloud-services/experience-notifications)
- [DevForum: Roblox creating 1-player servers (Oct 2025)](https://devforum.roblox.com/t/roblox-is-creating-1-player-servers-over-filling-existing-ones-harming-interaction/3981365)
- [DevForum: Custom Matchmaking available to all experiences](https://devforum.roblox.com/t/custom-matchmaking-is-now-available-to-all-experiences-on-roblox/4051419)
- Games API (live): maxPlayers 6, listing text.
