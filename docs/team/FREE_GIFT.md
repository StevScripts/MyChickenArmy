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
- **Client:** `client/FreeGiftController.luau` (popup; the Join card only says where
  to join), HUD button in `HudController` above Rebirth (shows the gift chicken's portrait),
  hidden once claimed. "Like the game" is honor-system copy only: Roblox has no API
  to check likes.
- **Art:** `assets/free-gift-20261016/` (gift, thumbs-up and group icons, asset IDs in
  its README).
- **No join from inside the game (October 21, Stevin):** the in-game join prompt
  (`GroupService:PromptJoinAsync`, added October 16) is removed. Players join the group
  themselves from the game page, so the ones who join have sought the game out. The
  Join card and a failed claim both show "Join our group from the game page to claim
  this reward!"; the server still verifies membership on Claim, and a member's Join row
  starts checked.
