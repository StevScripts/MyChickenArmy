--!strict
-- Client presentation for the October 20 Upgrades tree (docs/team/UPGRADES_SCREEN.md).
-- Layout, names, icons and value text come from UpgradeCatalog; statuses, prices and
-- badges only ever come from the server snapshot (state.upgradeTree).
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Currency=require(Shared.CurrencyLimits)
local Mutations=require(Shared.MutationCatalog)
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

-- The big tier number on a hex, from the catalog: none for single hexes or mutations,
-- and restarting at 1 for each Luck chain (Super Luck I shows 1).
function View.Numeral(node:any):string?
	return if type(node.numeral)=="number" then tostring(node.numeral) else nil
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

-- Each Gold roll kind's count list (S12's Config.GoldRolls; tree v2 makes Diamond and
-- Prism per-tier too) and the tree effect that picks its tier.
local RATES={goldRate="Gold",diamondRate="Diamond",prismRate="Prism"}
local RATE_EFFECT={Gold="goldRate",Diamond="diamondRate",Prism="prismRate"}
local function counts(kind:string):{number}?
	local gold=Config.GoldRolls
	local list=if type(gold)~="table" then nil elseif kind=="Gold" then gold.Every else type(gold.KindEvery)=="table" and gold.KindEvery[kind]
	return if type(list)=="number" then {list} elseif type(list)=="table" then list else nil
end

-- Cards that read better as what they change than as tier values. Returns the card's
-- change line and its owned line, or nil:
--   Gold/Diamond/Prism Rate "Every 10 → 8 rolls", their machines "Every 100 rolls: x5 Luck",
--   Roll Speed the real roll time "4.0 s → 3.3 s" (Stevin), mutations "1 in 250 rolls · x1.5 eggs".
function View.Lines(node:any,effects:any):(string?,string?)
	local family=node.family and Tree.Families[node.family]
	local entry=family and family.tiers[node.tier]
	if not entry then return nil,nil end
	local value=entry.value
	effects=if type(effects)=="table" then effects else {}
	local kind=RATES[family.effect]
	local list=kind and counts(kind)
	if list and list[value] and list[value+1] then
		return "Every "..list[value].." → "..list[value+1].." rolls","Every "..list[value+1].." rolls"
	end
	local gold=Config.GoldRolls
	if family.effect=="goldMachine" and type(gold)=="table" and type(gold.Luck)=="table" and type(gold.Kinds)=="table" then
		kind=gold.Kinds[value]
		list=kind and counts(kind)
		if list and gold.Luck[value] then
			local rate=tonumber(effects[RATE_EFFECT[kind]]) or 0
			local every=list[math.clamp(math.floor(rate),0,#list-1)+1]
			return "Every "..every.." rolls: x"..gold.Luck[value].." Luck","Every "..every.." rolls"
		end
	end
	if family.effect=="rollingSpeed" then
		-- Today's speed minus this family's own tier is what Gem Roll Speed adds.
		local owned=View.Tier(family.id)
		local extra=math.max(0,(tonumber(effects.rollingSpeed) or 0)-(if owned>0 then family.tiers[owned].value else 0))
		local before=if node.tier>1 then family.tiers[node.tier-1].value else 0
		local seconds=Config.RollRevealSeconds
		local now,after=seconds/(1+extra+before),seconds/(1+extra+value)
		return string.format("%.1f s → %.1f s",now,after),string.format("%.1f s per roll",after)
	end
	if family.effect=="mutations" then
		local def=Mutations.Defs[Mutations.Order[value]]
		if not def then return nil,nil end
		local chance=def.chance*(1+math.max(0,tonumber(effects.mutationLuck) or 0))
		local line=string.format("1 in %s rolls · x%s eggs",Currency.Grouped(math.floor(1/chance+.5)),tostring(def.multiplier))
		return line,line
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
