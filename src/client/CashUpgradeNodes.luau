--!strict
-- Presentation-only cash tracks. Saved levels and live server quotes remain
-- authoritative; these IDs never enter research completion or prerequisite data.
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Upgrades=require(Shared.UpgradeCatalog)
local Rules=require(Shared.Rules)
local Cash={Order={},Nodes={},ByKey={},ResearchPositions={}}

local function decimal(value)
	return (string.format("%.2f",value):gsub("0+$", ""):gsub("%.$", ""))
end

-- One hex per track sits beside Start and stays there: buying raises its level
-- and quote in place instead of revealing a new tier hex further out.
local tracks={
	{key="ArmySize",name="Army Size",icon="cashArmySize",q=0,r=-1,prices={},description="Deploy more chickens in your army."},
	{key="Luck",name="Luck",icon="cashLuck",q=1,r=-1,prices=Config.LuckPrices,description="Favor stronger chickens in normal rolls."},
	{key="RollSlots",name="Roll Slots",icon="cashRollSlots",q=1,r=0,prices=Upgrades.RollSlotPrices,description="Roll on more of your plot's podiums."},
	{key="PlotSize",name="Flock Size",icon="cashPlotSize",q=-1,r=0,prices=Upgrades.PlotPrices,description="Expand your yard and keep more chickens."},
	{key="EggValue",name="Egg Value",icon="cashEggValue",q=0,r=1,prices=Config.IncomePrices,description="Each new egg is worth more cash."},
	{key="EggSpeed",name="Egg Speed",icon="cashEggSpeed",q=-1,r=1,prices=Upgrades.EggSpeedPrices,description="Every chicken produces more eggs."},
}
for capacity=Config.StartingSlots,Config.MaxSlots-1 do
	table.insert(tracks[1].prices,Config.SlotUnlocks[capacity].price)
end
for _,track in tracks do
	local id="Cash"..track.key
	local tiers={}
	for tier,price in track.prices do
		local name=track.name.." "..tier
		if track.key=="Luck" then name..="/"..#track.prices end
		local benefit
		-- Count tracks name the result they buy: "Army Size → 4", "Flock Size → 30".
		if track.key=="RollSlots" then
			name="Roll Slots";benefit=(tier+1).." owned roll slots."
		elseif track.key=="PlotSize" then
			local capacity=Upgrades.PlotCapacity(tier)
			name="Flock Size → "..capacity;benefit="Flock capacity: "..capacity.." chickens."
		elseif track.key=="ArmySize" then
			name="Army Size → "..(Config.StartingSlots+tier);benefit=(Config.StartingSlots+tier).." base army slots, plus any paid bonus."
		elseif track.key=="EggSpeed" then benefit="Base egg production: "..decimal(Upgrades.EggSpeedRates[tier+1]).."x."
		elseif track.key=="EggValue" then benefit="Base egg value: $"..Rules.EggUnitValue(tier).."."
		else
			local window=Rules.LuckWindow(tier)
			benefit="Base Luck strength: "..decimal(window.multiplier).."x. Favored bands: "..window.rangeText.."."
		end
		tiers[tier]=table.freeze({tier=tier,name=name,price=price,benefit=benefit})
	end
	-- The hex shows the track name and a level badge; tooltips and messages keep the tier name.
	Cash.Nodes[id]={id=id,upgradeKey=track.key,maxTier=#tiers,tiers=table.freeze(tiers),name=track.name,tileName=track.name,
		description=track.description,icon=track.icon,q=track.q,r=track.r,prerequisite="Start"}
	Cash.ByKey[track.key]=id;table.insert(Cash.Order,id)
end

function Cash.Completed(key,offer)
	local level=if offer then offer.level else 0
	local offset=if key=="ArmySize" then Config.StartingSlots elseif key=="RollSlots" then 1 else 0
	return math.clamp(level-offset,0,Cash.Nodes[Cash.ByKey[key]].maxTier)
end

-- The tier a track's hex presents: the next purchase, or the last one once maxed.
function Cash.Shown(key,offer)
	local node=Cash.Nodes[Cash.ByKey[key]]
	local completed=Cash.Completed(key,offer)
	return node.tiers[math.min(node.maxTier,completed+1)],completed>=node.maxTier,completed
end

function Cash.NextId(key,_offer)
	return Cash.ByKey[key]
end

-- Research positions are a client-only composition override. The existing
-- prerequisite IDs, timers, effects and saved completion data do not change.
local positions={
	L1={1,-2},L2={1,-3},L3={1,-4},
	L4={2,-5},L5={2,-6},L6={1,-5},
	R1={2,-3},R2={2,-4},R3={3,-5},
	R4={4,-5},R5={4,-6},R6={3,-6},
	A1={-1,-1},A2={-2,-1},A3={-3,-2},A4={-1,-2},
	A5={-1,-3},A6={-2,-4},A7={-2,-2},A8={-3,-3},
	A9={-4,-3},A10={-1,-4},A11={-1,-5},A12={-2,-3},
	A13={-3,-4},A14={-3,-1},A15={-4,-1},A16={-4,-2},
	E1={-2,1},E2={-3,1},E3={-4,2},E4={-5,2},
	E5={-6,2},E6={-7,2},E7={-3,2},E8={-4,3},
	E9={-5,4},E10={-4,1},E11={-5,1},E12={-6,1},
	E13={-5,3},E14={-6,3},E15={-7,3},
	S1={1,1},S2={3,1},S3={4,2},S4={2,2},
	S5={3,3},S6={2,3},S7={2,4},S8={3,4},
	S9={4,1},S10={5,1},S11={5,2},S12={1,2},
	S13={1,3},S14={1,4},S15={3,2},S16={4,3},S17={4,4},
	H1={4,5},H2={3,6},
}
for id,position in positions do Cash.ResearchPositions[id]={q=position[1],r=position[2]} end
-- Re-enlist sits after the cash tracks as its own hex. It is deliberately outside
-- Order/Nodes/ByKey: it has no tiers or upgradeKey, and RebirthPanel draws it from
-- the live server quote (state.rebirth) as a fixed overlay on the research screen.
Cash.Reenlist=table.freeze({id="Reenlist",name="Rebirth",icon="army",
	-- Matches RebirthService: Egg Speed, Egg Value and Luck reset with Cash and the
	-- war; chicken levels, research, plot and Army Size are kept.
	description="Reset Cash, Egg Speed, Egg Value, Luck and the war for a permanent egg bonus. Chickens, chicken levels, research, plot and Army Size stay."})
for _,node in Cash.Nodes do table.freeze(node) end
for _,position in Cash.ResearchPositions do table.freeze(position) end
table.freeze(Cash.Order);table.freeze(Cash.Nodes);table.freeze(Cash.ByKey);table.freeze(Cash.ResearchPositions)

return table.freeze(Cash)
