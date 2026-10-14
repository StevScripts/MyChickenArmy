--!strict
-- Fixed final boss: its strength is independent of the player challenging it,
-- except for the attacker's Re-enlist scale (RebirthService.EnemyScale, 1 at rank 0).
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Progression = require(Shared.Progression)
local Rules = require(Shared.Rules)
local KingEncounter = {Target = "king:1", Scale = 1.69}

function KingEncounter.Definition(_rank, scale: number?)
 local rank=2
 local enemyScale=scale or 1
	local stats = {hp = 2800 * enemyScale, damage = 32 * enemyScale,
		interval = 1.4, size = 2.25 * KingEncounter.Scale, splash = false}
	local roster = {{species = "Duck", stars = 1, level = rank, slot = 1,
		boss = true, noRespawn = true, combatStats = stats}}
	-- Six guards screen the King. Guards can return during capture; the boss stays defeated.
	for index=1,6 do
		local guard = {species=if index<=4 then "Sailor" else "Bucket",stars=1,level=2,slot=index+1}
		if enemyScale ~= 1 then
			local guardStats = table.clone(Rules.Stats(guard.species, guard.stars, guard.level))
			guardStats.hp *= enemyScale; guardStats.damage *= enemyScale
			guard.combatStats = guardStats
		end
		table.insert(roster,guard)
	end
	local power = math.sqrt(stats.hp * stats.damage / stats.interval)
	for i = 2, #roster do local pet = roster[i]; power += Rules.PetPower(pet.species, pet.stars, pet.level) * enemyScale end
	return {name = "Chicken King's Court", roster = roster, power = math.floor(power),
		rank = rank}
end

return KingEncounter
