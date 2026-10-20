--!strict
-- October 20 overhaul: Gem Upgrade purchases, the Auto Rebirth switch and their
-- snapshot (docs/team/OVERHAUL_CONTRACT_20261020.md §6). Gems are earned by
-- Rebirths (RebirthService) and never reset; PlayerSession saves them.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Gems = require(Shared.GemUpgradeCatalog)
local Service = {}

local function ready(session): boolean
	return session.loaded == true and not session.closing and not session.saveLost
end

-- "Locked" (row not open yet), "Available", "Unaffordable" or "Maxed"; level; next price.
function Service.Status(session, id: string): (string, number, number?)
	local upgrade = Gems.Upgrades[id]
	local level = Gems.Level(session.gemUpgrades, id)
	local price = Gems.Price(id, level)
	if not price then return "Maxed", level, nil end
	if (session.rebirths or 0) < upgrade.unlockRank then return "Locked", level, price end
	return if (session.gems or 0) >= price then "Available" else "Unaffordable", level, price
end

function Service.Buy(session, id: any, expectedLevel: any, expectedPrice: any): (boolean, string)
	if not ready(session) then return false, "Your flock is not ready yet." end
	local upgrade = if type(id) == "string" then Gems.Upgrades[id] else nil
	if not upgrade then return false, "Choose a Gem Upgrade." end
	local status, level, price = Service.Status(session, id)
	if status == "Maxed" or not price then return false, upgrade.name .. " is at its maximum." end
	if status == "Locked" then return false, "Reach Rebirth " .. upgrade.unlockRank .. " to unlock " .. upgrade.name .. "." end
	-- A replay or stale card never buys another level at an unexpected price.
	if expectedLevel ~= level or expectedPrice ~= price then return false, "This upgrade changed. Try again." end
	if status ~= "Available" then
		local short = price - (session.gems or 0)
		return false, "Need " .. short .. " more " .. (if short == 1 then "Gem." else "Gems.")
	end
	-- Non-yielding: the balance check, spend and level are one step.
	session.gems -= price
	session.gemUpgrades[id] = level + 1
	-- Auto Rebirth starts switched on (plan v2); the card becomes an On/Off toggle.
	if id == "AutoRebirth" then session.autoRebirth = true end
	session:RefreshEffects()
	session:Touch()
	return true, upgrade.name .. (if upgrade.maxLevel > 1 then " is now level " .. (level + 1) .. "!" else " unlocked!")
end

function Service.SetAutoRebirth(session, enabled: any): (boolean, string)
	if not ready(session) then return false, "Your flock is not ready yet." end
	if type(enabled) ~= "boolean" then return false, "Invalid Auto Rebirth setting." end
	if (session.researchEffects.autoRebirth or 0) < 1 then return false, "Unlock Auto Rebirth in Gem Upgrades first." end
	session.autoRebirth = enabled
	session:Touch()
	return true, if enabled then "Auto Rebirth on." else "Auto Rebirth off."
end

function Service.Snapshot(session)
	local items = {}
	for _, id in Gems.Order do
		local upgrade = Gems.Upgrades[id]
		local status, level, price = Service.Status(session, id)
		items[id] = {id = id, name = upgrade.name, level = level, maxLevel = upgrade.maxLevel, price = price,
			status = status, row = upgrade.row, column = upgrade.column, unlockRank = upgrade.unlockRank,
			text = Gems.Text(id, level), icon = upgrade.icon}
	end
	return {order = table.clone(Gems.Order), items = items,
		autoRebirth = {owned = (session.researchEffects.autoRebirth or 0) >= 1, enabled = session.autoRebirth == true}}
end

return Service
