--!strict
-- Client presentation for the October 20 Upgrades tree (docs/team/UPGRADES_SCREEN.md).
-- Layout, names, icons and value text come from UpgradeCatalog; statuses, prices and
-- badges only ever come from the server snapshot (state.upgradeTree).
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Tree=require(Shared.UpgradeCatalog)
local View={Categories={},Roots={},Nodes={},Order={},Families={}}

-- Before S7's tree lands the catalog has no Nodes; the screen then stays empty
-- instead of breaking every client that requires this module.
local ready=type(Tree.Nodes)=="table" and type(Tree.Order)=="table" and type(Tree.Families)=="table"
if ready then
	View.Categories,View.Roots,View.Nodes,View.Order=Tree.Categories,Tree.Roots,Tree.Nodes,Tree.Order
end

-- Board keys from before the tree (My Army's Flock/Army Size shortcuts, the guide).
local LEGACY={PlotSize="Flock",RollSlots="RollSlot"}

function View.Family(key:string):any
	if not ready then return nil end
	return Tree.Families[LEGACY[key] or key]
end

-- The last snapshot's owned tiers ({[family]=tier}); the browser refreshes it.
function View.Remember(families:any)
	View.Families=if type(families)=="table" then families else {}
end

function View.Tier(familyId:string,families:any?):number
	local tier=(families or View.Families)[familyId]
	return if type(tier)=="number" then tier else 0
end

-- The family's next node to buy, or its last node once maxed. The second argument
-- may be state.upgradeTree; anything else (the guide's old board offer) uses the
-- last snapshot.
function View.NextId(key:string,tree:any?):string?
	local family=View.Family(key)
	if not family then return nil end
	local families=if type(tree)=="table" and type(tree.families)=="table" then tree.families else nil
	return Tree.NodeId(family.id,math.min(#family.tiers,View.Tier(family.id,families)+1))
end

-- The big tier number on a hex: only for families with more than one tier.
function View.Numeral(node:any):string?
	local family=node.family and Tree.Families[node.family]
	return if family and #family.tiers>1 and node.tier then tostring(node.tier) else nil
end

-- "x1.25", "x1.5": the value before and after this node's tier.
function View.Change(node:any):(string,string)
	return Tree.ValueText(node.family,node.tier-1),Tree.ValueText(node.family,node.tier)
end

-- Unlocks (Gold Machine, Chicken Feed) and named levels (Gold Rate) read better by
-- name than as "Locked → Unlocked".
function View.Plain(node:any):boolean
	local family=node.family and Tree.Families[node.family]
	return family~=nil and (family.format=="unlock" or family.format=="level")
end

-- Gold rolls (S12's Config.GoldRolls; absent before it merges): the machine and rate
-- hexes say what they change, "Every 10 → 8 rolls" or "x2 → x5 Luck". Returns the
-- card's change line and the owned line, or nil.
function View.GoldText(node:any,effects:any):(string?,string?)
	local gold=Config.GoldRolls
	local family=node.family and Tree.Families[node.family]
	local entry=family and family.tiers[node.tier]
	if type(gold)~="table" or type(gold.Every)~="table" or type(gold.Luck)~="table" or not entry then return nil,nil end
	local value=entry.value
	if family.effect=="goldRate" and gold.Every[value] and gold.Every[value+1] then
		return "Every "..gold.Every[value].." → "..gold.Every[value+1].." rolls","Every "..gold.Every[value+1].." rolls"
	elseif family.effect=="goldMachine" and gold.Luck[value] then
		local boost="x"..gold.Luck[value].." Luck"
		if gold.Luck[value-1] then return "x"..gold.Luck[value-1].." → "..boost,boost end
		local rate=type(effects)=="table" and tonumber(effects.goldRate) or 0
		local every=gold.Every[math.clamp(math.floor(rate),0,#gold.Every-1)+1]
		return "Every "..every.." rolls: "..boost,boost.." every "..every.." rolls"
	end
	return nil,nil
end

function View.Description(node:any):string
	local family=node.family and Tree.Families[node.family]
	return if family and type(family.description)=="string" then family.description else ""
end

-- The Open hex that leads to a category (its name titles the subtree).
function View.OpenNode(category:string):any
	for _,id in View.Order.Main or {} do
		local node=View.Nodes[id]
		if node.kind=="open" and node.opens==category then return node end
	end
	return nil
end

return View
