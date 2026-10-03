--!strict
local Catalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.ResearchCatalog)
local Abilities={}

function Abilities.Rally(session,battles,now)
	local duration=session.researchEffects.rallySeconds
	if duration<=0 then return false,"Complete Rally research first." end
	if now<session.research.rallyReadyAt then return false,"Rally is cooling down." end
	local battle=battles.battles[session.outgoing]
	if not battle or (battle.phase~="Fight" and battle.phase~="Capture") then return false,"Rally your deployed army during a battle." end
	local side=if battle.attacker==session.userId then "A" else "B"
	if battle:Alive(side)==0 then return false,"Your army has no active chickens to rally." end
	session.rallyActiveUntil=now+duration
	session.research.rallyReadyAt=now+Catalog.RallyCooldown
	session:Touch()
	return true,"Rally! +20% army damage."
end

return Abilities
