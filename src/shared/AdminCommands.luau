--!strict
-- Admin command reference shared by AdminService (server) and the Admin panel.
-- Listing commands grants nothing: the server checks every sender's rank.
-- Targets: me, all, others, a name (start of a username or display name) or a user ID.
-- Amounts accept k/m/b/t: 250k, 1.5m, 2b.
local Commands = {}

export type Command = {name: string, usage: string, help: string, rank: string, group: string}

Commands.List = {
	{name="help", usage="help [command]", help="List commands or explain one.", rank="Admin", group="Info"},
	{name="players", usage="players", help="Everyone in this server with their user ID.", rank="Admin", group="Info"},
	{name="logs", usage="logs", help="Recent admin actions in this server.", rank="Admin", group="Info"},

	{name="cash", usage="cash <target> <amount>", help="Give cash (a negative amount takes it).", rank="Admin", group="Economy"},
	{name="setcash", usage="setcash <target> <amount>", help="Set a player's cash exactly.", rank="Admin", group="Economy"},
	{name="chicken", usage="chicken <target> <species> [level] [count]", help="Give chickens (flock limit applies).", rank="Admin", group="Economy"},
	{name="research", usage="research <target> <all|node>", help="Finish all research, or one node by ID or name.", rank="Admin", group="Economy"},
	{name="army", usage="army <target> <size>", help="Set army size (deployment slots).", rank="Admin", group="Economy"},
	{name="roll", usage="roll <target> [species]", help="Make the next roll ready now, optionally forcing a species.", rank="Admin", group="Economy"},

	{name="camps", usage="camps <target>", help="Mark all home camps beaten.", rank="Admin", group="War"},
	{name="king", usage="king <target>", help="Mark camps and the Chicken King beaten.", rank="Admin", group="War"},
	{name="clearflags", usage="clearflags <target>", help="Remove every territory flag the target holds.", rank="Admin", group="War"},
	{name="hill", usage="hill <open|close>", help="Start or end a Hill round now.", rank="Admin", group="War"},

	{name="tp", usage="tp <target>", help="Teleport yourself to a player.", rank="Admin", group="Players"},
	{name="bring", usage="bring <target>", help="Teleport players to you.", rank="Admin", group="Players"},
	{name="home", usage="home <target>", help="Send players to their own base.", rank="Admin", group="Players"},
	{name="speed", usage="speed <target> <number|reset>", help="Set walk speed (0 to 200).", rank="Admin", group="Players"},
	{name="announce", usage="announce <message>", help="Show a filtered message to everyone in the server.", rank="Admin", group="Players"},
	{name="kick", usage="kick <target> [reason]", help="Remove players from the server.", rank="Admin", group="Moderation"},

	{name="ban", usage="ban <player or ID> <1h|3d|perm> [reason]", help="Ban from every server of the game.", rank="Owner", group="Moderation"},
	{name="unban", usage="unban <username or ID>", help="Lift a ban.", rank="Owner", group="Moderation"},
	{name="admin", usage="admin <add|remove> <player or ID>", help="Give or take admin (saved for every server).", rank="Owner", group="Moderation"},
	{name="admins", usage="admins", help="List owners and admins.", rank="Owner", group="Moderation"},
}

Commands.ByName = {} :: {[string]: Command}
for _, command in Commands.List do Commands.ByName[command.name] = command end
-- Short forms typed in chat.
Commands.Aliases = {money="cash", give="chicken", teleport="tp", to="tp", ws="speed", walkspeed="speed",
	msg="announce", m="announce", unlockall="research", h="help", cmds="help", commands="help"}

function Commands.Resolve(name: string): Command?
	name = string.lower(name)
	return Commands.ByName[Commands.Aliases[name] or name]
end

function Commands.Allowed(rank: string?, command: Command): boolean
	return rank == "Owner" or (rank == "Admin" and command.rank == "Admin")
end

return Commands
