-- Isolated research/rolling checks. Does not open profiles, buy passes or create world objects.
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Config=require(Shared.Config)
local Catalog=require(Shared.PetCatalog)
local ResearchCatalog=require(Shared.ResearchCatalog)
local ResearchRules=require(Shared.ResearchRules)
local Rules=require(Shared.Rules)
local ShopCatalog=require(Shared.ShopCatalog)
local Server=game.ServerStorage.PetRoll
local Session=require(Server.PlayerSession)
local Rolls=require(Server.RollService)
local Station=require(Server.RollStation)
local Commerce=require(Server.CommerceService)
local Upgrades=require(Server.UpgradeService)
local Checks={}

local function near(actual,expected)
	assert(math.abs(actual-expected)<1e-10,tostring(actual).." differs from "..tostring(expected))
end
local function grant(session,id)
	while id do
		local node=assert(ResearchCatalog.Nodes[id],"Missing research "..id)
		session.research.completed[id]=true;id=node.prerequisite
	end
	session.researchEffects=ResearchRules.Effects(session.research)
end
local function setup()
	local session=Session.new(-67001,"Research roll fixture",1)
	session.loaded=true;session.coins=1e9
	return session,Rolls.new()
end
local function sameOdds(actual,expected)
	for _,species in Catalog.Order do near(actual[species],expected[species]) end
end

function Checks.Run()
	local results={}
	local function check(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end
	check("Research families use the highest tier rather than stacking",function()
		local session=setup();grant(session,"L6");grant(session,"R6")
		near(session.researchEffects.rollingLuck,1);near(session.researchEffects.rollingSpeed,.6)
	end)
	check("No research preserves the original cash and paid luck weights",function()
		for _,paid in {1,2} do
			for _,level in {0,4,#Config.LuckPrices} do
				local odds=Rules.Odds(level,1,paid);sameOdds(odds,Rules.Odds(level,1,paid,0))
				local expected,total={},0
				for _,species in Catalog.Order do
					local definition=Catalog[species]
					local rare=table.find({"Rare","Epic","Legendary","Mythic"},definition.rarity)~=nil
					expected[species]=definition.weight*(if rare then Rules.LuckMultiplier(level)*paid else 1)
					total+=expected[species]
				end
				for species,weight in expected do near(odds[species],weight/total) end
			end
		end
	end)
	check("Every research tier normalizes and real draw intervals match displayed chances",function()
		for _,bonus in {.1,.2,.35,.5,.75,1} do
			for _,paid in {1,2} do
				local odds=Rules.Odds(4,1,paid,bonus);local total=0
				for _,species in Catalog.Order do
					local chance=odds[species];assert(chance>0 and chance<1)
					assert(Rules.Draw(4,total+chance/2,1,paid,bonus)==species)
					total+=chance
				end
				near(total,1)
				local baseline=Rules.Odds(4,1,paid)
				-- Relative Rare/Common weight receives precisely the additional multiplier.
				local common,rare
				for _,species in Catalog.Order do
					if Catalog[species].rarity=="Common" then common=species end
					if Catalog[species].rarity=="Rare" then rare=species end
				end
				near((odds[rare]/odds[common])/(baseline[rare]/baseline[common]),1+bonus)
			end
		end
	end)
	check("Draw, frozen offer, player snapshot and shop disclosures agree",function()
		local session,rolls=setup();grant(session,"L3")
		session.luck=4;session.entitlements.DoubleLuck=true;session.paidRandomAllowed=true
		rolls.random={NextNumber=function() return .95 end}
		assert(rolls:Roll(session,100))
		local expected=Rules.Odds(4,1,2,.35)
		assert(session.offer.species==Rules.Draw(4,.95,1,2,.35))
		near(session.offer.chance,expected[session.offer.species]);near(session.offer.researchLuck,.35)
		sameOdds(session:Snapshot(100).odds,expected)
		local shop=Commerce.Snapshot({records={},catalog=ShopCatalog},session)
		sameOdds(shop.luckOdds.withPass,expected)
		sameOdds(shop.luckOdds.withoutPass,Rules.Odds(4,1,1,.35))
		local offer=session.offer;grant(session,"L6")
		near(offer.chance,expected[offer.species]);near(offer.researchLuck,.35)
		sameOdds(session:Snapshot(100).odds,Rules.Odds(4,1,2,1))
	end)
	check("Upgrade board current and next luck retain research and paid bonuses",function()
		local session=setup();grant(session,"L6")
		session.entitlements.DoubleLuck=true;session.paidRandomAllowed=true
		local offers=Upgrades.Offers({},session)
		near(tonumber(offers.Luck.currentText:match("[%d.]+")),4)
		near(tonumber(offers.Luck.nextText:match("[%d.]+")),Rules.LuckMultiplier(1)*4)
		assert(offers.Luck.price==Config.LuckPrices[1] and offers.Luck.unlocked)
	end)
	check("Accepted duration is frozen; cooldown and early purchase cannot bypass it",function()
		local session,rolls=setup();grant(session,"R1")
		session.debugNext="Duck";assert(rolls:Roll(session,100))
		local offer=session.offer;local deadline=100+Config.RollRevealSeconds/1.1
		near(offer.duration,Config.RollRevealSeconds/1.1)
		near(session.rollRevealAt,deadline);near(session.rollReadyAt,deadline)
		grant(session,"R6")
		assert(not rolls:Roll(session,deadline-.001));assert(session.offer==offer)
		local cash=session.coins
		assert(not rolls:Buy(session,offer.id,deadline-.001));assert(session.coins==cash)
		near(session.rollRevealAt,deadline);near(offer.duration,Config.RollRevealSeconds/1.1)
		assert(rolls:Buy(session,offer.id,deadline))
		assert(rolls:Roll(session,deadline));near(session.offer.duration,Config.RollRevealSeconds/1.6)
		near(session.rollRevealAt,deadline+Config.RollRevealSeconds/1.6)
	end)
	check("Station publishes the accepted timing and weights unchanged by mid-roll research",function()
		local session,rolls=setup();grant(session,"R1");grant(session,"L3")
		session.entitlements.DoubleLuck=true;session.paidRandomAllowed=true
		assert(rolls:Roll(session,100))
		local model=Instance.new("Model")
		local station=setmetatable({model=model,slot=1,random=Random.new(9),buyPrompt={},Step=function() end},Station)
		station:Sync(session)
		near(model:GetAttribute("RollDuration"),Config.RollRevealSeconds/1.1)
		near(model:GetAttribute("RollResearchLuck"),.35);near(model:GetAttribute("RollPaidLuck"),2)
		local started=model:GetAttribute("RollStartedAt")
		grant(session,"R6");grant(session,"L6");station:Sync(session)
		near(model:GetAttribute("RollStartedAt"),started)
		near(model:GetAttribute("RollDuration"),Config.RollRevealSeconds/1.1)
		near(model:GetAttribute("RollResearchLuck"),.35)
		model:Destroy()
	end)
	check("Restricted paid guarantees retain cadence and forced debug rolls never consume it",function()
		local session,rolls=setup();grant(session,"L6");grant(session,"R6")
		session.entitlements.DoubleLuck=true;session.paidRandomAllowed=false;session.paidRandomRestricted=true
		session.guaranteedLuckRolls=ShopCatalog.GuaranteedLuck.interval-1
		local expected=session:LuckGuarantee().nextSpecies
		assert(rolls:Roll(session,100));assert(session.offer.guaranteed and session.offer.species==expected)
		near(session.offer.chance,1);near(session.offer.paidLuck,1)
		local progress=session.guaranteedLuckRolls
		assert(not rolls:Roll(session,100));assert(session.guaranteedLuckRolls==progress)
		session.debugNext="StormDuck";assert(rolls:Roll(session,session.rollReadyAt))
		assert(session.offer.species=="StormDuck" and session.offer.debug and not session.offer.guaranteed)
		assert(session.guaranteedLuckRolls==progress)
	end)
	check("Unresearched timing and eight physical offer slots remain unchanged",function()
		local session,rolls=setup();session.rollSlotCount=8
		assert(rolls:Roll(session,100));near(session.offer.duration,Config.RollRevealSeconds)
		near(session.rollRevealAt,100+Config.RollRevealSeconds)
		assert(#session.offers==8 and session.rollSlotCount==8)
		for _,offer in session.offers do
			near(offer.duration,Config.RollRevealSeconds)
			assert(offer.price==Rules.RecruitPrice(offer.species,offer.level))
		end
	end)
	return results
end

return Checks
