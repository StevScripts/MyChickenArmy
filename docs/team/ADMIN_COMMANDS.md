# Admin commands (October 13, 2026)

Owner request: admin commands for Stevin and anyone he chooses, usable in live servers. Separate from the Studio-only test tools (`DebugService`, F8), which stay Studio-only.

## Using them

- **Chat:** type `/a <command>` (or `/admin <command>`). The message is not shown to other players. Examples: `/a cash me 1m`, `/a chicken bob golden 5 2`, `/a tp bob`.
- **Panel:** press **F2**, or Settings > **Admin commands**. Type a command and press Enter or Run. Quick buttons cover the common ones, and the page lists every command you can use. Replies appear in the panel's output; chat replies appear as a notification.
- **Targets:** `me`, `all`, `others`, the start of a username or display name, or a user ID.
- **Amounts:** `250k`, `1.5m`, `2b`, `3t`.

| Command | What it does | Who |
|---|---|---|
| `help [command]`, `players`, `logs` | Command list, who's here with IDs, recent admin actions | Admin |
| `cash <target> <amount>` / `setcash` | Give (negative takes) or set cash | Admin |
| `chicken <target> <species> [level] [count]` | Give chickens; flock limit applies | Admin |
| `research <target> <all\|node>` | Finish research instantly | Admin |
| `army <target> <size>` | Set army size (3 to 10) | Admin |
| `roll <target> [species]` | Next roll ready now, optionally forced | Admin |
| `camps <target>` / `king <target>` | Mark home camps (and the King) beaten | Admin |
| `clearflags <target>` | Remove every territory flag they hold | Admin |
| `hill <open\|close>` | Start or end a Hill round | Admin |
| `tp`, `bring`, `home` | Teleport to a player, bring players, send them home | Admin |
| `speed <target> <0-200\|reset>` | Walk speed (lasts until reset or respawn) | Admin |
| `announce <message>` | Filtered message to everyone in the server | Admin |
| `kick <target> [reason]` | Remove from the server (not owners or admins) | Admin |
| `ban <player or ID> <30m\|6h\|3d\|2w\|perm> [reason]` | Ban from every server (Roblox ban API) | Owner |
| `unban <username or ID>` | Lift a ban | Owner |
| `admin <add\|remove> <player or ID>`, `admins` | Manage admins; saved for every server | Owner |

## Who has access

`src/server/AdminConfig.luau` (server-only; clients never see it):

- `Owners`: 146710616 (Stevin). Owners can do everything.
- `Admins`: user IDs added in code (needs a republish).
- In game, an owner can run `/a admin add <name or ID>`; that list is saved in the DataStore `DuckArmy_Pond_v2_Admins_v1` and other servers pick it up within a minute. Studio keeps it in memory only.
- Optional: `GroupId` and `GroupAdminRank` make a group rank and above admins.

Admins cannot ban, manage admins, or kick owners and other admins.

## Safety

- The server checks every command against the sender's rank; the panel and command list grant nothing.
- Commands change the normal saved session, so changes persist and saves stay valid.
- `KeepRankingsClean` (on): a player given chickens, research, camp or King wins, army size or a forced roll is marked `adminAssisted` (saved) and removed from the Strongest Army board. Cash grants do not count.
- Announcements go through Roblox's text filter.
- Every action is logged in the server output (`[Admin] ...`) and kept for `logs`.
- Bans use `Players:BanAsync`, which only works in live servers (Studio returns an error).

## Code

`server/AdminService.luau` (parser, ranks, commands, `/admin` TextChatCommand), `server/AdminConfig.luau`, `shared/AdminCommands.luau` (command list for both sides), `client/AdminPanel.luau`; wiring in `GameServer` (`Admin` request, `state.admin`, `PushState`, `Reply`), `AppController` (Admin page, F2), `WorldService:UpdatePlayerSpeed` (`AdminWalkSpeed`), `PlayerSession` (`adminAssisted`), `LeaderboardService`.

## Verification

`tests/AdminChecks.luau` (7 checks) passed in Studio edit mode against fresh module clones: access by rank, cash amounts and floors, chicken grants with limits, research/camps/King/army/roll persisting through save and load, target errors, owner-only commands and admin add/remove, help/logs/rate limit. The chat command, panel, teleports, kicks, bans and announcements still need a live playtest: Studio's playtest start returned "Unknown error".
