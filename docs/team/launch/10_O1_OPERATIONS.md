# Worker O1: unlock Operations by beating the King

**Branch:** `launch/o1-operations` · **Worktree:** `~/Documents/Projects/mca-o1` · **Plan:** [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §5
**Needs the foundation?** No. You can start right away.

## Why

The nine Operations are the only content after the Chicken King, and no player has started one. Today the gates are research only: Veteran needs S15 (1 h), Elite needs S16 (8 h), Royal needs S17 (48 h). Players beat the King in about 45 minutes and then hit a wall.

## Files you own (only these)

- `src/server/OperationService.luau`
- `src/shared/ResearchCatalog.luau`
- `src/shared/TutorialGuide.luau`
- `src/client/ResearchExtras.luau` (the Operations panel; confirm by searching for where Operation tiers and the locked text are shown. If the panel lives in `ResearchBrowser.luau` instead, you own that file instead, and say so in your handoff.)
- `tests/OperationUnlockChecks.luau` (new)
- `docs/team/launch/handoff/O1.md` (new)

Read anything else, edit nothing else. Never open Studio.

## What to change

### 1. Beating the King unlocks Veteran Operations

In `OperationService.luau`, add:

```lua
-- October 14 launch: a King clear opens Veteran Operations without research.
function OperationService.Tier(session): number
	return math.max(session.researchEffects.operations or 0, if session.kingCleared then 1 else 0)
end
```

Use it at line 52 (the start check, which today reads `session.researchEffects.operations < definition.tier`) and at line 160 (the state the client receives, `tier = ...`). Search the file for any other read of `researchEffects.operations` and switch it too.

Research S15 still unlocks Veteran Operations on its own. Either path is enough.

### 2. Shorter Elite and Royal gates

In `ResearchCatalog.luau`:
- `S16` (Elite Operations): `duration = 7200` (was 28800).
- `S17` (Royal Operations): `duration = 21600` (was 172800).
- `S15` description: `"Unlock Veteran Operations early (defeating the Chicken King also unlocks them)"`.

Leave prices and every other node untouched. Running research jobs keep their saved finish times; nothing in the save changes.

### 3. Client text

In the Operations panel, the locked Veteran set should read **"Defeat the Chicken King or research Operations Board"**. Elite and Royal keep their research wording. The panel should show Veteran as open when the state's tier is 1 or more (the server now sends the combined tier).

### 4. Next goal after the King

In `TutorialGuide.luau`, find the next-goal logic used after the guide is complete (`NextGoal`, added in the Oct 8 fixes). After the first King clear, when no Veteran Operation has been won, the next goal should point at **Veteran Patrol** ("Next: win Veteran Patrol in Operations"). Keep every existing goal before the King unchanged.

## Tests (`tests/OperationUnlockChecks.luau`)

Follow the pattern of `tests/LaneConquestChecks.luau` (fresh module clones, Studio Edit mode). Cover:

1. `kingCleared = true`, no S15: Veteran Patrol can start; Elite is refused.
2. S15 completed, no King clear: Veteran Patrol can start (the old path still works).
3. Neither: refused with the locked message.
4. The state tier sent to the client equals `OperationService.Tier(session)`.
5. The S16 quote is 7,200 s and the S17 quote is 21,600 s at research speed 0.
6. The next goal after a King clear names Veteran Patrol.

You can't run them; the lead will. Make them self-contained and print clear pass/fail lines.

## How the lead verifies

1. Run `tests/OperationUnlockChecks.luau` and `tests/ResearchChecks.luau`.
2. In a disposable playtest, use a test profile with the King cleared and no S15: open Operations, see Veteran unlocked, start Veteran Patrol.

## Handoff

Commit on your branch, then write `docs/team/launch/handoff/O1.md`: files changed, the test file, anything unsure (especially if the Operations UI lives somewhere other than `ResearchExtras.luau`), and requests for the lead.
