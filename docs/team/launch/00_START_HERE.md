# Launch sprint: start here

**Goal:** ship the launch changes from [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) with several Claude sessions working in parallel.
**Written:** October 14, 2026.

## The one thing that limits speed

Writing code is not the bottleneck. **Studio is.** This repo only has Rojo (no Lune), so every test runs inside the one Studio place, and only one session can sync into Studio at a time. Ten agents writing code still funnel through one person syncing, testing and publishing.

So the sprint uses the structure AGENTS.md already prescribes: "One writer per file. For parallel tasks, assign explicit files and contracts. Workers do not control canonical Studio, Blender, Git history or further agents; the root integrates."

- **1 lead session** owns `main`, Studio, Rojo sync, merging, tests and publishing.
- **Worker sessions** each own a list of files, work in their own git worktree on their own branch, never open Studio, and hand back a branch plus a handoff note.
- **You** do the Creator Dashboard work (it needs your login) and make the design calls.

## What is realistic tonight

| Ship tonight (publish 1) | Ship tomorrow after more testing (publish 2) | Not this week |
|---|---|---|
| Phase 0 store and shop fixes (you) | M1 mutations | X1 yard raids |
| O1 Operations unlock | H1 Halloween (needs a Pumpkin Chicken model) | |
| R1 rebirth (server and client) | | |
| D1 7-day login streak | | |

Why not everything tonight: each feature adds saved data to real player profiles. Publishing five save-touching features at once means that if one breaks, you can't tell which, and rolling back removes all of them. Two publishes keep each one testable. Raids are a design problem more than a coding problem (fairness, young players, tuning) and need their own playtests, see [`20_X1_RAIDS_LATER.md`](20_X1_RAIDS_LATER.md).

## Sessions and documents

| Session | Document | Starts when | Rough length |
|---|---|---|---|
| You | [`01_OWNER_DASHBOARD.md`](01_OWNER_DASHBOARD.md) | Now | 45 min |
| Lead | [`02_LEAD.md`](02_LEAD.md) | Now (after step 0 below) | All evening |
| Worker O1 | [`10_O1_OPERATIONS.md`](10_O1_OPERATIONS.md) | Now, it needs no foundation | 1 to 2 h |
| Worker R1-S | [`11_R1_REBIRTH_SERVER.md`](11_R1_REBIRTH_SERVER.md) | After the foundation commit | 2 to 3 h |
| Worker R1-C | [`12_R1_REBIRTH_CLIENT.md`](12_R1_REBIRTH_CLIENT.md) | After the foundation commit | 2 to 3 h |
| Worker D1 | [`13_D1_DAILY_STREAK.md`](13_D1_DAILY_STREAK.md) | After the foundation commit | 1.5 to 2 h |
| Worker M1 | [`14_M1_MUTATIONS.md`](14_M1_MUTATIONS.md) | After the foundation commit | 3 to 4 h |
| Worker H1 | [`15_H1_HALLOWEEN.md`](15_H1_HALLOWEEN.md) | After the foundation commit | 1.5 h of code, plus art |

Five workers at once is the useful maximum. More sessions only make a longer merge queue for the lead.

## Order of the evening

```
Step 0  You: get the admin-panel chat to commit its work (PlayerSession, GameServer,
        LeaderboardService, AppController, ChickenBrowser, MergeBrowser ... are modified).
        Nobody starts editing until main is clean.
Step 1  You: Phase 0 in the dashboard.                 Lead: the foundation (02_LEAD.md §3).
        Worker O1 starts right away in its own worktree.
Step 2  Lead commits the foundation and creates the worktrees.
Step 3  Workers R1-S, R1-C, D1, M1, H1 start in parallel.
Step 4  Lead merges in this order as handoffs arrive: O1 → R1-S → R1-C → D1 → (M1 → H1).
        After every merge: Rojo sync, run the feature's tests and the core tests, quick playtest.
Step 5  Publish 1: Phase 0 + O1 + R1 + D1. Restart all servers. Watch analytics for an hour.
Step 6  Tomorrow: finish M1 and H1, publish 2, restart all servers.
```

## How to start a worker session

Open a new Claude Code session on the worker's worktree folder (the lead creates them in step 2; their paths are in [`02_LEAD.md`](02_LEAD.md) §4). Paste this as the first message, changing the file name:

```
You are a worker in the My Chicken Army launch sprint.
Read AGENTS.md, then docs/team/launch/00_START_HERE.md, then docs/team/launch/11_R1_REBIRTH_SERVER.md.
Follow the worker doc exactly: edit only the files it lists as yours, do not open or sync Studio,
do not touch main, do not push. Commit only on your branch. When done, write your handoff note
where the doc says and stop.
```

If the desktop app offers to run a new session in its own worktree, that works too. Just make sure each worker's session sits on its own branch, never on `main`.

## Rules for every worker

1. **Edit only your listed files.** If you need a change in a file you don't own, write it in your handoff note as "Request for lead". Don't make it yourself.
2. **No Studio.** Don't sync Rojo, don't run playtests, don't use the studio-flow or Roblox_Studio tools. Write tests; the lead runs them.
3. **Saves are real player data.** New saved values are additive, junk loads as the default, and nothing ever rejects a profile. See [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §3.
4. **Match the code style around you:** tabs or spaces as the file already uses, the same comment density, `--!strict` where the file has it.
5. **Commit on your branch** with a clear message. Never rebase, never push, never touch `main`.
6. **Finish with a handoff note** at `docs/team/launch/handoff/<ID>.md`: what you changed, the tests you wrote and how to run them, anything you're unsure of, and requests for the lead.

## Contracts

The foundation (lead, [`02_LEAD.md`](02_LEAD.md) §3) adds every shared hook in one commit, with neutral stubs, so the game behaves exactly as before until workers fill the stubs in. Workers code against these signatures and never edit the shared files:

| Module | Function | Owner after foundation | Stub behaviour |
|---|---|---|---|
| `src/server/RebirthService.luau` | `Quote(session) -> quote` | R1-S | `{rank = session.rebirths, eligible = false, reason = "Coming soon"}` |
| | `Rebirth(session, expectedRank, server) -> ok, message` | R1-S | `false, "Coming soon"` |
| | `EnemyScale(rank) -> number` | R1-S | `1` |
| | `Multiplier(rank) -> number` | R1-S | `1` |
| `src/server/DailyService.luau` | `Check(session, now, server)` | D1 | does nothing |
| `src/shared/MutationCatalog.luau` | `Multiplier(id) -> number` | M1 | `1` |
| | `Roll(rng, rebirths) -> id?` | M1 | `nil` |
| | `Best(pets) -> id?` | M1 | `nil` |
| | `IsValid(id) -> boolean` | M1 | `false` |
| `src/server/EventService.luau` | `Active(now) -> boolean` | H1 | `false` |
| | `MaybeReplace(session, species, rng, slot, now) -> species` | H1 | returns `species` unchanged |
| `src/client/RebirthPanel.luau` | `new(app)`, `:Render(state)` | R1-C | does nothing |
| `src/client/DailyRewardController.luau` | `new(app)`, `:Render(state)` | D1 | does nothing |

Snapshot fields the client receives (added by the foundation in `PlayerSession:Snapshot`): `state.rebirth` (the quote), `state.daily` (`{streak, lastDay, best, granted}`), and `mutation` on every pet entry.
