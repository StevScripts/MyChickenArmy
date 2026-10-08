--!strict
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Progression=require(Shared.Progression)
local Catalog=require(Shared.PetCatalog)
local ShopCatalog=require(Shared.ShopCatalog)
local PlayerSession=require(script.Parent.PlayerSession)
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
	else return false,"Unknown debug command." end
	session:RefreshArmy()
	session:Touch()
	return true,"TEST: "..command.." applied."
end

return DebugService
