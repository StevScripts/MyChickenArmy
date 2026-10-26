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
- **Gift box and 5 minutes of play (October 23, Stevin):** the HUD button shows the chunky
  gift box (`gift-box.png`, rbxassetid://85740083144452) instead of the chicken, 1.2x
  bigger (`FreeGiftCorner` 0.0984 x 0.192 at y 0.3); the chicken is revealed only in the
  popup's reward card. The claim also needs `Config.FreeGift.MinPlaySeconds` (300) of
  total playtime. `PlayerSession.playSeconds` is a saved, additive total of earlier visits
  (missing or bad = 0, never rejects a save); `PlayerSession:PlaySeconds()` adds this
  visit's Playtime clock. The snapshot sends `minPlaySeconds`, `playSeconds` and the
  server time `playedAt`; the popup's third row "3. Play for 5 minutes" counts on
  ("2:13/5:00") once a second and turns into a check at 5:00. An early Claim! shakes and
  says how long is left without asking the server; `FreeGiftService.Claim` refuses it too.
