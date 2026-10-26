--!strict
-- Permanent combat limits and fixed encounters. All species can roll from the start.
-- Legacy pool metadata stays compatible; Rules.Odds uses one full roster at every rank.
-- Stronger locations never replace earlier camps, reset wins, or scale to the player.
local Progression = {}
local ranks = {
	{name="Rookie Flock",capacityCap=5,levelCap=3,benchmarkIncome=12,
		pool={"Duck","Mallard","Chunky","Sailor","Bucket"},luckPool={"Chunky","Sailor","Bucket"},recruit="Duck",
		nextUnlock="7 fighters",
		camps={
			{name="Bread Bandits",roster={"Duck","Duck","Duck"}},
			{name="Sailor Outpost",roster={"Sailor","Mallard","Mallard"}},
			{name="Bucket Barricade",roster={"Bucket","Bucket","Sailor","Sailor"}},
		}},
	{name="Iron Feathers",capacityCap=7,levelCap=5,benchmarkIncome=50,
		pool={"Chunky","Sailor","Bucket","Viking","Knight"},luckPool={"Viking","Knight"},recruit="Viking",
		nextUnlock="9 fighters",
		camps={
			{name="Iron Watch",roster={{species="Bucket",level=3},{species="Sailor",level=3},{species="Sailor",level=3},{species="Viking",level=2},"Viking"}},
			{name="Viking Stronghold",roster={{species="Viking",level=2},{species="Viking",level=2},{species="Bucket",level=3},{species="Bucket",level=3},"Knight"}},
			{name="Knight Keep",roster={{species="Knight",level=4},{species="Knight",level=4},{species="Viking",level=4},{species="Viking",level=4},{species="Bucket",level=5},{species="Bucket",level=5}}},
		}},
	{name="Royal Wings",capacityCap=9,levelCap=7,benchmarkIncome=140,
		pool={"Viking","Knight","Wizard","Dragon"},luckPool={"Wizard","Dragon"},recruit="Wizard",
		nextUnlock="10 fighters",
		camps={
			{name="Royal Guard",roster={{species="Knight",level=4},{species="Knight",level=4},{species="Viking",level=4},{species="Viking",level=4},"Wizard"}},
			{name="Wizard Assembly",roster={{species="Wizard",level=2},{species="Wizard",level=2},{species="Knight",level=4},{species="Knight",level=4},{species="Viking",level=5},{species="Viking",level=5}}},
			{name="Dragon Citadel",roster={{species="Dragon",level=3},{species="Wizard",level=4},{species="Knight",level=7},{species="Knight",level=7},{species="Viking",level=7},{species="Viking",level=7}}},
		}},
	{name="Storm Legion",capacityCap=10,levelCap=10,benchmarkIncome=350,
		pool={"Knight","Wizard","Dragon","IceDuck","StormDuck"},luckPool={"IceDuck","StormDuck"},recruit="IceDuck",
		nextUnlock="Conquer the Storm King · Champion flag",
		camps={
			{name="Frozen Frontier",roster={{species="IceDuck",level=4},{species="Wizard",level=6},{species="Knight",level=8},{species="Knight",level=8},{species="Knight",level=8},{species="Viking",level=9}}},
			{name="Thunder Bastion",roster={{species="Dragon",level=6},{species="IceDuck",level=5},{species="Wizard",level=7},{species="Knight",level=6},{species="Knight",level=6},{species="Knight",level=6}}},
			{name="Storm King's Roost",roster={{species="StormDuck",level=4},{species="IceDuck",level=3},{species="Dragon",level=3},{species="Knight",level=7},{species="Knight",level=7},{species="Knight",level=7}}},
		}},
}

function Progression.Count(): number
	return #ranks
end

function Progression.Get(rank: number?)
	local value = if type(rank)=="number" and rank==rank then math.clamp(math.floor(rank),1,#ranks) else 1
	return ranks[value]
end

-- Stable main-route IDs: new camps append after the existing landmarks.
-- The surrounding outposts use authored later rosters and remain independent.
local homeCamps = {ranks[1].camps[1], ranks[1].camps[3]}
homeCamps[1] = table.clone(homeCamps[1])
homeCamps[1].name = "Cluck Camp"
-- October 23 empty start (Stevin: three rolled chickens must be enough): one basic
-- Chicken (Rules.Power 12, was three at 38), so three level-1 chickens "Should win".
-- Bread Bandits above keeps its three.
homeCamps[1].roster = {"Duck"}
homeCamps[2] = table.clone(homeCamps[2])
homeCamps[2].name = "Fort Roost"
-- October 8: level-1 garrison (power ~107, was ~146) so about five Uncommon/Rare
-- level-1 chickens can take it. Ironbeak HQ and the King are unchanged.
homeCamps[2].roster = {{species="Bucket",level=1},{species="Sailor",level=1},{species="Mallard",level=1},{species="Mallard",level=1}}
homeCamps[3] = {name="Ironbeak HQ",roster={{species="Bucket",level=2},{species="Bucket",level=2},{species="Sailor",level=2},{species="Viking",level=1}}}
local outposts = {}
for i, source in {{2,1},{2,3},{3,1},{3,3},{4,1},{4,2}} do
 local definition = table.clone(ranks[source[1]].camps[source[2]])
 definition.tier, definition.index = source[1], i
 table.insert(outposts, definition)
end

function Progression.Camps(_rank) return homeCamps end
function Progression.Outposts() return {} end -- Builder map has only the main route and King.
function Progression.Normalize(roster)
 local result = {}
 for slot, entry in roster do
  table.insert(result, {species=if type(entry)=="string" then entry else entry.species,
   stars=1, level=if type(entry)=="string" then 1 else entry.level, slot=slot})
 end
 return result
end
function Progression.Roster(_rank, index)
 local camp=homeCamps[index]
 return if camp then Progression.Normalize(camp.roster) else {}
end
function Progression.OutpostRoster(index)
 return Progression.Normalize(outposts[index].roster)
end
function Progression.KingSource() return ranks[4].camps[3] end
function Progression.KingUnlocked(firstWins, frontierWins, kingCleared): boolean
 -- Previously earned access stays valid. New flocks conquer the fixed map first.
 if kingCleared then return true end
 for i in homeCamps do if not firstWins[i] then return false end end
 return true
end
function Progression.EarnedRank(firstWins, frontierWins)
 -- Preserve legacy outpost achievements; main-route victories replace their unlock gates.
 local rank=if frontierWins[4] then 4 elseif frontierWins[2] then 3 else 1
 for i in homeCamps do if not firstWins[i] then break end;rank=math.max(rank,i+1) end
 return rank
end
function Progression.Requirement(tier)
 if tier>=2 and tier<=4 then return "Conquer "..homeCamps[tier-1].name end
 return "Available from the start"
end
function Progression.NextGoal(firstWins, frontierWins, kingCleared)
 for i,camp in homeCamps do if not firstWins[i] then return camp.name end end
 if not kingCleared then return "Challenge the Chicken King" end
 return if kingCleared then "All territories explored!" else "Challenge the Chicken King"
end
return Progression
