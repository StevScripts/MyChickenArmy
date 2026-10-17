# Free Chicken gift (October 16, 2026)

Owner request: like the game + join the group = one free chicken, once per profile.

- **Config:** `shared/Config.luau` → `FreeGift={Enabled,GroupId=778575811,Species="Bucket"}` (Robo-Cluck).
  Change `Species` to give a different chicken; `Enabled=false` hides the button.
- **Server:** `server/FreeGiftService.luau`. `InGroup` uses `GroupService:GetGroupsAsync`
  (fresh; `Player:IsInGroup` is cached per server session, so someone who joins after
  arriving would fail), falling back to `IsInGroup`. `Claim` grants the chicken with
  `investment=0`, sets saved `freeGiftClaimed`, and refuses while the Flock is full
  (the claim stays available). `GameServer` handles `ClaimFreeGift` with a 3 s
  per-player lookup cooldown and rechecks the session after the yield.
- **Save:** additive `freeGiftClaimed` boolean in `PlayerSession` (missing = false).
- **Client:** `client/FreeGiftController.luau` (popup; the Join card opens Roblox's
  `GroupService:PromptJoinAsync`), HUD button in `HudController` above Rebirth (shows the gift chicken's portrait),
  hidden once claimed. "Like the game" is honor-system copy only: Roblox has no API
  to check likes.
- **Art:** `assets/free-gift-20261016/` (gift, thumbs-up and group icons, asset IDs in
  its README).
- **Join from inside the game (October 16):** if Verify finds the player isn't in the group,
  the server flags `freeGift.notInGroup` and the client opens Roblox's native join prompt
  (`GroupService:PromptJoinAsync`). Joining (or "already a member") retries Verify after the
  3 s lookup cooldown; a pending join request gets a notice. Tapping the Join card uses the
  same flow.
