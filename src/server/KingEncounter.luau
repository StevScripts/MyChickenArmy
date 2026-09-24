--!strict
-- Fixed final boss: its strength is independent of the player challenging it.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Progression = require(Shared.Progression)
local Rules = require(Shared.Rules)
local KingEncounter = {Target = "king:1", Scale = 1.69}

function KingEncounter.Definition(_rank)
 local rank=2
	local stats = {hp = 2800, damage = 32,
		interval = 1.4, size = 2.25 * KingEncounter.Scale, splash = false}
	local roster = {{species = "Duck", stars = 1, level = rank, slot = 1,
		boss = true, noRespawn = true, combatStats = stats}}
	-- Six guards screen the King. Guards can return during capture; the boss stays defeated.
	for index=1,6 do
		table.insert(roster,{species=if index<=4 then "Sailor" else "Bucket",stars=1,level=2,slot=index+1})
	end
	local power = math.sqrt(stats.hp * stats.damage / stats.interval)
	for i = 2, #roster do local pet = roster[i]; power += Rules.PetPower(pet.species, pet.stars, pet.level) end
	return {name = "Chicken King's Court", roster = roster, power = math.floor(power),
		rank = rank}
end

return KingEncounter
