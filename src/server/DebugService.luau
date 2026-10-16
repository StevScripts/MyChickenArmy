--!strict
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Progression=require(Shared.Progression)
local Catalog=require(Shared.PetCatalog)
local ShopCatalog=require(Shared.ShopCatalog)
local PlayerSession=require(script.Parent.PlayerSession)
local Giant=require(Shared.GiantChicken)
local Mutations=require(Shared.MutationCatalog)
local Research=require(Shared.ResearchCatalog)
local ResearchRules=require(Shared.ResearchRules)
local UpgradeCatalog=require(Shared.UpgradeCatalog)
local RebirthService=require(script.Parent.RebirthService)
local DailyService=require(script.Parent.DailyService)
local DebugService={}
DebugService.__index=DebugService

function DebugService.new(sessions,battles,commerce)
	return setmetatable({sessions=sessions,battles=battles,commerce=commerce},DebugService)
end

-- Every command below writes session/profile/battle state, so all of them are
-- Studio-only. Config.DebugUserIds grants nothing in live servers: a live
-- account must never mint cash, grant crate species or move global rankings.
function DebugService.Allowed(_player): boolean
	return RunService:IsStudio()
end

function DebugService:Run(player,session,command,argument,now)
	if not RunService:IsStudio() or not DebugService.Allowed(player) then return false,"Debug access denied." end
	if type(command)~="string" then return false,"Invalid debug action." end
	if command=="TestPurchases" then
		if not self.commerce then return false,"Purchase tests unavailable." end
		return self.commerce:SetTestPreset(player,session,argument)
	elseif command=="FreshEconomy" then
		local presets={Free="NoPasses",LowRobux="EggSpawn",CashPack="NoPasses",AllPasses="AllPasses",AllItems="AllPasses"}
		local preset=if type(argument)=="string" then presets[argument] else nil
		if not preset or not self.commerce then return false,"Choose a valid economy test." end
		local ok,message=self.commerce:SetTestPreset(player,session,preset)
		if not ok then return false,message end
		self.battles:CancelPlayer(session.userId,now)
		session:Reset()
		-- Consumable balances are cleared only in this disposable Studio profile.
		-- Receipt acknowledgements remain intact even here.
		session.crateCredits,session.guaranteedLuckRolls=0,0
		session.eggProcessor.finishCredits=0
		session.commerceAutomatic={AutoCollectEggs=true,AutoMerge=true}
		if argument=="CashPack" then session:Credit(ShopCatalog.Products.PocketCoins.coins,"debug") end
		if argument=="AllItems" then
			for _,product in ShopCatalog.Products do
				if product.enabled~=false and product.coins then session:Credit(product.coins,"debug") end
			end
		end
		session:RefreshArmy();session:Touch()
		return true,"TEST: fresh "..argument.." session. Saved progress and real purchases are untouched."
	elseif command=="ResetProtected" then
  if argument~="RESET MY TEST SAVE" then return false,"Reset requires the explicit test-save confirmation." end
		self.battles:CancelPlayer(session.userId,now)
		session:Reset()
		return true,"TEST: saved test progress reset."
	elseif command=="Knockout" then
		local battle=self.battles.battles[session.outgoing]
		if not battle or (battle.phase~="Fight" and battle.phase~="Capture") then return false,"Send your squad into a fight first." end
		for _,unit in battle.units do
			if unit.side=="A" and unit.hp>0 and not unit.reinforcing then
				unit.hp=0;unit.respawnAt=now+Config.AttackerRespawnSeconds
				if battle.actors then battle.actors:Stop(unit) end
				return true,"TEST: one fighter knocked out. It respawns at home in five seconds."
			end
		end
		return false,"All your fighters are already recovering."
	elseif command=="Coins" then session:Credit(10000,"debug")
	elseif command=="Grant" then
		if type(argument)~="string" or not Catalog[argument] or argument=="Order" then return false,"Unknown species." end
		if session:Count()>=Config.CollectionLimit then return false,"Collection full." end
		session:AddPet(argument,1)
	elseif command=="Offer" then
		if type(argument)~="string" or not Catalog[argument] or argument=="Order" then return false,"Unknown species." end
		session.debugNext=argument;session.rollReadyAt=0
	elseif command=="Seed" then
		session.debugRandom=Random.new(20260906);session.rollReadyAt=0
	elseif command=="Promotion" then
  if type(argument)~="number" or argument~=argument or argument%1~=0 or argument<1 or argument>Progression.Count() then
   return false,"Choose a valid test promotion."
  end
  if session:IsArmyLocked() or session.incoming then return false,"Bring your squad home first." end
  session.promotion,session.recruitTier=math.max(session.promotion,argument),argument
  session.capacity=Progression.Get(argument).capacityCap
  if argument>=2 then
   for i=1,#Progression.Camps(1) do session.firstWins[i]=true end
   session.campUnlocked=#Progression.Camps(1)
  end
  if argument>=3 then session.frontierWins[1],session.frontierWins[2]=true,true end
  if argument>=4 then session.frontierWins[3],session.frontierWins[4]=true,true end
  session.offer=nil;session.offers={};session.rollReadyAt=0;session.rollRevealAt=0
  session.stationedAt,session.banner=nil,"TEST: "..Progression.Get(argument).name
  for slot in session.slots do if slot>session.capacity then session.slots[slot]=nil end end
	elseif command=="Unlock" then
  if session:IsArmyLocked() or session.incoming then return false,"Bring your squad home first." end
  session.capacity=Config.MaxSlots
  for i=1,#Config.Camps do session.firstWins[i]=true end
  session.campUnlocked=#Config.Camps
  session:UnlockProgress()
	elseif command=="Opponent" or command=="EmptyOpponent" or command=="AwayOpponent" then
		local bot=self.sessions[-999]
		if bot then self.battles:CancelPlayer(bot.userId,now)
		else
			local used={};for _,other in self.sessions do used[other.plotIndex]=true end
			local index=nil;for i=#Config.PlotPositions,1,-1 do if self.battles.world.plots[i] and not used[i] then index=i;break end end
			if not index then return false,"No empty plots are available for a test opponent." end
			bot=PlayerSession.new(-999,"Test Opponent",index);self.sessions[-999]=bot
		end
		bot:Reset();bot.pets,bot.slots={},{}
		bot.capacity,bot.campUnlocked=Config.MaxSlots,#Config.Camps
		for i=1,Config.MaxSlots do local pet=bot:AddPet(Catalog.Order[(i-1)%5+1],1);bot.slots[i]=pet.id end
		if command=="EmptyOpponent" then bot.slots={} end
		if command=="AwayOpponent" then bot.armyState="Returning";bot.returnAt=now+7 end
		bot:Touch()
	elseif command=="BotAttack" then
		local bot=self.sessions[-999]
		if not bot then return false,"Create a Test Opponent first." end
		return self.battles:Attack(bot,"base:"..session.userId,now)
	elseif command=="FillCommon" or command=="FillMixed" or command=="FillReserves" or command=="Pair" or command=="Capacity" then
		if session:IsArmyLocked() then return false,"Wait for your army to return." end
		if command=="FillReserves" then
			while session:Count()<Config.CollectionLimit do session:AddPet("Duck",1) end
		elseif command=="Pair" then
			if session:Count()>Config.CollectionLimit-2 then return false,"Collection full." end
			session:AddPet("Duck",1);session:AddPet("Duck",1)
		elseif command=="Capacity" then
			if not table.find(Config.SlotLevels,argument) then return false,"Choose a valid deployment capacity." end
			session.capacity=argument;session.legacyCapacityGrant=math.min(session.legacyCapacityGrant or 0,argument)
   session.campUnlocked=1;while session.firstWins[session.campUnlocked] and session.campUnlocked<#Config.Camps do session.campUnlocked+=1 end
			for slot in session.slots do if slot>argument then session.slots[slot]=nil end end
		else
			session.pets,session.slots={},{}
			for i=1,session.capacity do
				local species=if command=="FillCommon" then "Duck" else Catalog.Order[(i-1)%#Catalog.Order+1]
				local pet=session:AddPet(species,1)
				session.slots[i]=pet.id
			end
		end
	elseif DebugService.Launch[command] then
		-- October 14 launch-feature tools. They rewrite a lot of the profile, so they
		-- only run in a session-only test profile (a normal Studio play can save).
		if session.saveStatus~="studio-session" then
			return false,"Use a session-only test profile first (Settings → Test as a new player, or workspace PetRollPlaytestSessionOnly)."
		end
		local ok,message=DebugService.Launch[command](self,player,session,argument,now)
		session:RefreshArmy();session:Touch()
		return ok,message
	else return false,"Unknown debug command." end
	session:RefreshArmy()
	session:Touch()
	return true,"TEST: "..command.." applied."
end

-- Launch-feature test commands (Studio test tools → Launch features).
local function giveChicken(session,species,level,giantSize,mutation)
	local pet=session:AddPet(species,1,mutation)
	pet.level=math.clamp(level,1,Config.MaxPetLevel)
	pet.giantSize=giantSize
	return pet
end

local function readyForRebirth(session)
	session.kingCleared=true
	for i=1,#Progression.Camps(1) do session.firstWins[i]=true end
	session.campUnlocked=#Progression.Camps(1)
	local cost=RebirthService.Cost((session.rebirths or 0)+1)
	if cost then session.coins=math.max(session.coins,cost+1e6) end
end

DebugService.Launch={}

-- One button that unlocks every system and hands out one of everything to try.
DebugService.Launch.TestEverything=function(self,player,session,_argument,now)
	self.battles:CancelPlayer(session.userId,now)
	if self.commerce then self.commerce:SetTestPreset(player,session,"AllPasses") end
	for key in session.tutorial do if type(session.tutorial[key])=="boolean" then session.tutorial[key]=true end end
	session.tutorial.emptyStart,session.tutorial.guideSkipped,session.tutorial.goalsHidden=false,false,false
	session.introHoldUntil=nil
	session.promotion,session.recruitTier=Progression.Count(),Progression.Count()
	for i=1,#Progression.Outposts() do session.frontierWins[i]=true end
	readyForRebirth(session)
	session.capacity=Config.MaxSlots
	session.plotSizeLevel=#UpgradeCatalog.PlotPrices;session.plotBuild=nil
	session.rollSlotsUnlocked=Config.RollSlotsUnlocked
	-- Every research node done, so every menu and Invasion tier is open.
	for _,id in Research.Order do session.research.completed[id]=true end
	session.research.jobs={};session.research.revision+=1
	session.researchEffects=ResearchRules.Effects(session.research)
	session.fusionUnlocked=true
	-- Showcase flock: a strong army, a fusion that is guaranteed to make a Giant,
	-- three Giants for a Colossal try, a Colossal, mutations and the event chicken.
	session.pets,session.slots,session.armySelection={},{},nil
	for _=1,6 do giveChicken(session,"Dragon",8) end
	for _=1,3 do giveChicken(session,"Knight",3) end
	for _,size in {7,8,9} do giveChicken(session,"Bucket",2,size) end
	giveChicken(session,"StormDuck",6,22.5)
	local golden=if Mutations.IsValid("Golden") then "Golden" else nil
	local rainbow=if Mutations.IsValid("Rainbow") then "Rainbow" else nil
	giveChicken(session,"Wizard",5,nil,golden)
	giveChicken(session,"IceDuck",4,12,rainbow)
	if Catalog.Pumpkin then giveChicken(session,"Pumpkin",3) end
	session.giantPity=Giant.PityLimit-1
	-- Day 7 of the streak is granted within a few seconds.
	local today=math.floor(os.time()/DailyService.DaySeconds)
	session.daily={streak=6,lastDay=today-1,best=6}
	session.dailyGranted=nil
	DailyService.Check(session,os.time(),nil)
	return true,"TEST: everything unlocked. Try Rebirth, Missions (all tiers), Fuse (Knights = guaranteed Giant, "
		.."Bucket Giants = Colossal try), mutations, the Pumpkin, Day 7 streak and all passes."
end

DebugService.Launch.RebirthReady=function(_self,_player,session)
	readyForRebirth(session)
	return true,"TEST: King cleared and cash for the next rank. Open Rebirth."
end

DebugService.Launch.StartInvasion=function(self,_player,session,argument,now)
	local operations=self.battles.operations
	if not operations then return false,"Missions are unavailable." end
	session.kingCleared=true
	if session.research.pendingOperationReward>0 then require(script.Parent.OperationService).ClaimReward(session) end
	local id=if type(argument)=="string" and #argument<=8 then argument else "1:1"
	local tier=tonumber(string.match(id,"^(%d)")) or 1
	for t=2,tier do session.research.completed[({"S15","S16","S17"})[t]]=true end
	if tier>=2 then session.research.completed.S15=true end
	session.researchEffects=ResearchRules.Effects(session.research)
	-- October 14 Missions: spawn that encounter as a waiting site on the island.
	return operations:SpawnNow(session,now,id)
end

DebugService.Launch.DailyNextDay=function(_self,_player,session)
	local today=math.floor(os.time()/DailyService.DaySeconds)
	session.tutorial.guideCompleted=true
	session.daily.lastDay=today-1
	session.dailyGranted=nil
	local granted=DailyService.Check(session,os.time(),nil)
	if not granted then return false,"The streak could not advance." end
	return true,"TEST: Day "..granted.streak.." streak granted."
end

DebugService.Launch.GiantGuarantee=function(_self,_player,session)
	session.fusionUnlocked=true
	for _=1,3 do giveChicken(session,"Knight",3) end
	session.giantPity=Giant.PityLimit-1
	return true,"TEST: three Lv3 Knights added and the next fusion is a guaranteed Giant. Use the Fuse Machine."
end

DebugService.Launch.ColossalTry=function(_self,_player,session)
	session.fusionUnlocked=true
	for _,size in {7,8,9} do giveChicken(session,"Bucket",2,size) end
	return true,"TEST: three Lv2 Bucket Giants added. Fusing them is a 25% Colossal try."
end

DebugService.Launch.Mutations=function(_self,_player,session)
	local added={}
	for _,id in Mutations.Order do
		giveChicken(session,"Knight",2,nil,id);table.insert(added,id)
	end
	if #added==0 then return false,"Mutations are not available in this build." end
	return true,"TEST: one Knight with each mutation: "..table.concat(added,", ").."."
end

DebugService.Launch.Halloween=function(_self,_player,_session)
	local event=Config.Event
	event.Enabled=not event.Enabled
	if event.Enabled and not (event.StartsAt<=os.time() and os.time()<event.EndsAt) then
		event.StartsAt,event.EndsAt=os.time()-60,os.time()+86400
	end
	return true,"TEST: Halloween event "..(if event.Enabled then "ON (2% Pumpkin per podium)" else "OFF").." for this Studio server."
end

return DebugService
