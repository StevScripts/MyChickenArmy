--!strict
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage.PetRoll.Shared
local Config=require(Shared.Config)
local Progression=require(Shared.Progression)
local PlayerSession=require(script.Parent.PlayerSession)
local RollService=require(script.Parent.RollService)
local ArmyService=require(script.Parent.ArmyService)
local ArmyCommandService=require(script.Parent.ArmyCommandService)
local BattleService=require(script.Parent.BattleService)
local WorldService=require(script.Parent.WorldService)
local DebugService=require(script.Parent.DebugService)
local DataService=require(script.Parent.DataService)
local EggService=require(script.Parent.EggService)
local LeaderboardService=require(script.Parent.LeaderboardService)
local CommerceService=require(script.Parent.CommerceService)
local ProductService=require(script.Parent.ProductService)
local CrateService=require(script.Parent.CrateService)
local LoopTelemetry=require(script.Parent.LoopTelemetry)
local Analytics=require(script.Parent.Analytics)
local TutorialService=require(script.Parent.TutorialService)
local UpgradeService=require(script.Parent.UpgradeService)
local ResearchService=require(script.Parent.ResearchService)
local ArmyAbilities=require(script.Parent.ArmyAbilities)
local OperationService=require(script.Parent.OperationService)
local HillService=require(script.Parent.HillService)
local GameServer={}
GameServer.__index=GameServer
local SYNC_COOLDOWN=1 -- Extra Sync requests are answered by the next periodic snapshot.
local IDLE_SNAPSHOT_SECONDS=1 -- Unchanged idle sessions refresh timers at this slower cadence.

function GameServer.new()
	local self=setmetatable({sessions={},connections={},playerConnections={},limits={},stepAccumulator=0,
		snapshotAccumulator=0,recruitObservations={},awayObservations={},syncs={},sent={}},GameServer)
	self.world=WorldService.new()
	self.eggs=EggService.new(self.world)
	self.leaderboards=LeaderboardService.new(self.world,self.sessions)
	self.commerce=CommerceService.new()
	self.rolls=RollService.new()
	self.upgrades=UpgradeService.new(self.world,self.rolls)
	self.battles=BattleService.new(self.sessions,self.world)
	self.operations=OperationService.new(self.battles,self.world,self.sessions)
	self.hill=HillService.new(self.battles,self.world,self.sessions,os.clock())
	self.armyCommands=ArmyCommandService.new(self.world,self.battles,self.sessions)
	-- Local loop observations also feed the agent analytics ledger.
	self.telemetry=LoopTelemetry.new(function(event) if self.analytics then self.analytics:LoopEvent(event) end end)
	self.tutorial=TutorialService.new()
	self.battles.telemetry=self.telemetry
	self.debug=DebugService.new(self.sessions,self.battles,self.commerce)
 self.data=DataService.new()
 self.products=ProductService.new(self.data,self.sessions)
 self.crates=CrateService.new()
	-- Observation only (docs/analytics/AGENT_GUIDE.md). Hooks never change gameplay.
	self.analytics=Analytics.new({tutorial=self.tutorial,battles=self.battles})
	TutorialService.Transport=function(player,name,value,fields) self.analytics:Custom(player,name,value,fields) end
	TutorialService.onProgress=function(userId,name,value,step,detail) self.analytics:Progress(userId,name,value,step,detail) end
	TutorialService.onIncome=function(session,source,amount,balance) self.analytics:Income(session,source,amount,balance) end
	self.products.onGranted=function(session,productId,product) self.analytics:ProductGranted(session,productId,product) end
	self.commerce.onPassPurchased=function(player,key) self.analytics:PassPurchased(player,key) end
	return self
end

function GameServer:Send(player,result)
	local session=self.sessions[player.UserId]
	if not session then return end
	local now=os.clock()
	local state=session:Snapshot(now)
	state.boardUpgrades=self.upgrades:Offers(session)
 local routeCamps,routeOutposts=self.battles:RouteProgress(session)
 state.routeCamps,state.routeOutposts=table.clone(routeCamps),table.clone(routeOutposts)
 local kingOwner=self.battles.campOwners["king:1"]
 state.ownsKing=kingOwner~=nil and kingOwner.userId==session.userId
 state.routeCampsWon=0
 for i=1,#Progression.Camps(1) do if routeCamps[i] then state.routeCampsWon+=1 end end
	state.eggs=self.eggs:Snapshot(session,now)
	state.shop=self.commerce:Snapshot(session)
	state.shop.productReady=self.products:CanPurchase(session)
	state.targets=self.battles:Targets(session,now)
	state.incomeOutpost=if self.battles.IncomeSummary then self.battles:IncomeSummary(session,now) else nil
	state.hill=self.hill:Snapshot(session,now)
	state.mergeOptions=ArmyService.MergeOptions(session)
	state.operations=self.operations:Snapshot(session)
	local battle=self.battles.battles[session.outgoing]
	state.travelStage=if battle and battle.phase=="Travel" then (if battle.assembling then "Assembling" else "Marching") else nil
	state.recoveringCount,state.reinforcingCount=0,0
	local side=if battle and battle.defender==session.userId then "B" else "A"
	if battle then for _,unit in battle.units do if unit.side==side and not unit.retiring then
		if unit.hp<=0 then state.recoveringCount+=1 elseif unit.reinforcing then state.reinforcingCount+=1 end
	end end end
	state.marchingTo=if battle and battle.phase=="Travel" then battle.name else nil
	state.routeGoal=if battle and battle.routeGoal then battle.routeGoalName else nil
	self.tutorial:Observe(session,state)
	self.analytics:Observe(session,state)
	-- The client "Studio test tools" button follows the same Studio-only gate.
	state.debugAllowed=RunService:IsStudio() and DebugService.Allowed(player)
	state.newPlayerTestAllowed=GameServer.NewPlayerTestAllowed(player)
	state.newPlayerTest=session.newPlayerTest==true
	self.sent[player.UserId]={at=now,revision=session.revision,eggs=state.eggs.revision,generation=state.eggs.generation}
	self.remotes.StateChanged:FireClient(player,{state=state,result=result})
end

-- The client replaces its whole state per packet, so every send stays a full
-- snapshot. Only the cadence drops while nothing session-owned has changed.
function GameServer:SnapshotDue(session,now)
	local last=self.sent[session.userId]
	if not last or now-last.at>=IDLE_SNAPSHOT_SECONDS or session.revision~=last.revision then return true end
	local yard=self.eggs.yards[session.userId]
	if yard and (yard.revision~=last.eggs or yard.generation~=last.generation) then return true end
	if session.armyState~="Home" or session.outgoing or session.incoming or session.defending then return true end
	return session.rollReadyAt>now or session.rollRevealAt>now
end

function GameServer:Handle(player,request)
	if type(request)~="table" or type(request.action)~="string" or #request.action>40
		or type(request.id)~="number" or request.id~=request.id or math.abs(request.id)>1e12 then return end
	local now=os.clock()
	local rate=self.limits[player.UserId] or {tokens=16,at=now}
	rate.tokens=math.min(16,rate.tokens+(now-rate.at)*8);rate.at=now;self.limits[player.UserId]=rate
	if rate.tokens<1 then return end
	rate.tokens-=1
	local session=self.sessions[player.UserId]
	if not session then return end
	-- Device/perf/error stats from AnalyticsClient; accepted while loading too.
	if request.action=="ClientReport" then self.analytics:ClientReport(session,request.report);return end
	if not session.loaded or session.closing or session.saveLost then self:Send(player,{id=request.id,ok=false,message=session.saveMessage or "Loading your flock…"});return end
 local action=request.action
	local ok,message,petId,recruit=false,"Unknown action.",nil,nil
	local balanceBefore=session.coins
	local receipt,purchase,crate
	local selectedBefore=#session:BestPetIds()
	local selectionBefore=if action=="SetArmy" or action=="SelectBest" then table.concat(session:BestPetIds(),":") else nil
	if action=="Sync" then
		local sync=self.syncs[player.UserId] or {readyAt=0};self.syncs[player.UserId]=sync
		if now<sync.readyAt then sync.pending=request.id;return end
		sync.readyAt,sync.pending=now+SYNC_COOLDOWN,nil
		self:Send(player,{id=request.id,action="Sync",ok=true});return
	elseif action=="TutorialSignal" then
		self.tutorial:Signal(session,request.signal,request.input)
		self.analytics:Signal(session,request.signal)
		self:Send(player);return
	elseif action=="StartResearch" then
		ok,message=ResearchService.Start(session,request.nodeId,request.expectedRevision,request.expectedPrice,request.expectedDuration,os.time())
	elseif action=="CancelResearch" then
		ok,message=ResearchService.Cancel(session,request.jobId,request.expectedRevision,os.time())
	elseif action=="Rally" then
		ok,message=ArmyAbilities.Rally(session,self.battles,os.time())
	elseif action=="PinResearch" then
		ok,message=ResearchService.Pin(session,request.nodeId)
	elseif action=="AcknowledgeResearch" then
		session.researchRecap={};ok,message=true,"Research updated."
	elseif action=="SaveFormation" then
		-- Yields for text filtering; ArmyService rechecks its own preconditions afterwards.
		ok,message=ArmyService.SaveFormation(session,request.slot,request.name,request.expectedIds,request.expectedRevision)
		if self.sessions[player.UserId]~=session or session.closing or session.saveLost then return end
	elseif action=="ApplyFormation" then
		ok,message=ArmyService.ApplyFormation(session,request.slot,request.expectedIds,request.expectedRevision)
	elseif action=="StartOperation" then
		ok,message=self.operations:Start(session,request.operationId,request.expectedRevision,now)
	elseif action=="LeaveOperation" then
		local operation=self.battles.battles[session.outgoing]
		if operation and operation.operationId then self.operations:Resolve(operation,"Abandoned",now);ok,message=true,"Operation ended."
		else message="You are not in an Operation." end
	elseif action=="EggCashCollect" then
		-- Old clients cannot bypass server-owned movement/one-second collection.
		return
	elseif action=="RefreshShop" then
		-- This may yield; no client-owned flag, price or product benefit is accepted.
		ok,message=self.commerce:Refresh(player,session)
		if self.sessions[player.UserId]~=session or session.closing or session.saveLost then return end
	elseif action=="PreparePurchase" then
		if request.key=="FinishEggs" and not self.eggs:CanUseBoard(player,session) then
			message="Walk up to your egg selling board."
		else ok,message,purchase=self.commerce:PreparePurchase(player,session,request.key,self.products:CanPurchase(session)) end
	elseif action=="OpenCrate" then
		if not self.products:CanPurchase(session) then message="Crates need a safely loaded, saved profile."
		else
			ok,message,crate=self.crates:Open(session)
			if ok then petId=crate.petId;self.world:Recruit(session,petId) end
		end
	elseif action=="TestCrate" then
		if not self.commerce:TestAllowed(session) then message="Test crates are only available in a disposable Studio session."
		elseif now<(session.testCrateReadyAt or 0) then message="Wait for your test roll to finish."
		else
			ok,message,crate=self.crates:OpenTest(session)
			if ok then
				session.testCrateReadyAt=now+12
				petId=crate.petId;self.world:Recruit(session,petId)
			end
		end
	elseif action=="SetCommerceToggle" then
		ok,message=self.commerce:SetAutomatic(session,request.key,request.enabled)
	elseif action=="Roll" or action=="Buy" then
		if not self.world:CanUseStation(player,session,request.stationIndex,action,request.offerId) then
			message="Walk up to your own pet rolling station."
		elseif action=="Roll" then ok,message=self.rolls:Roll(session,now)
		else
			local battle=self.battles.battles[session.outgoing]
			ok,message,petId,recruit=self.rolls:Buy(session,request.offerId,now,battle and {
				battleId=battle.id,phase=battle.phase})
		end
	elseif action=="SetArmy" then ok,message=ArmyService.SetSelection(session,request.petIds,request.expectedIds)
	elseif action=="SelectBest" then ok,message=ArmyService.SelectBest(session)
	elseif action=="Place" or action=="Equip" or action=="Unplace" then message="Choose chickens in the Army menu."
	elseif action=="Favorite" then ok,message=ArmyService.Favorite(session,request.petId)
	elseif action=="UpgradeChicken" then
		ok,message,petId=ArmyService.UpgradeChicken(session,request.petId,request.expectedLevel,request.expectedPrice)
	elseif action=="Sell" then
		-- Army-menu sales have no world-position requirement. Ownership, protection
		-- and the exact refund are still validated atomically by ArmyService.
		ok,message,receipt=ArmyService.Sell(session,request.petIds,true,request.expectedTotal)
	elseif action=="OpenSell" then message="Select a reserve chicken in the Army menu to sell it."
	elseif action=="OpenMerge" or action=="Merge" or action=="MergeAll" then
  local unlocked,requirement=session:MergeAccess()
  if not Config.Features.Merging then message="Merging is unavailable."
  elseif not unlocked then message=requirement
  elseif not self.world:CanUseMergeStand(player,session,request.stationIndex) then
   message="Walk to the merge stand at your base."
  elseif action=="OpenMerge" then ok,message=true,"Choose matching chickens to merge."
  elseif action=="MergeAll" then
   ok,message,receipt=ArmyService.MergeAll(session,request.triples)
   if ok then petId=receipt.results[1].petId;self.world:CelebrateMerge(session,petId) end
  else
   ok,message,petId=ArmyService.Merge(session,request.firstId,request.secondId,request.thirdId,request.level,request.expectedPrice)
   if ok then self.world:CelebrateMerge(session,petId) end
  end
	elseif action=="CashUpgrade" or action=="BoardUpgrade" then
		ok,message=self.upgrades:Buy(player,session,request.upgradeKey,request.expectedLevel,request.expectedPrice)
	elseif action=="EggSellerUpgrade" then
		ok,message=self.eggs:Upgrade(player,session,request.expectedLevel,request.expectedPrice)
	elseif action=="Expand" then ok,message=ArmyService.Expand(session)
	elseif action=="Promote" then ok,message=ArmyService.Promote(session)
	elseif action=="Income" then ok,message=ArmyService.UpgradeIncome(session)
 elseif action=="Luck" then ok,message=self.rolls:UpgradeLuck(session)
 elseif action=="Attack" then
  if not self.world:CanCommand(player,session,request.targetId,self.sessions) then message="Approach the camp and press E to send your army."
  else ok,message=self.armyCommands:Attack(session,request.targetId,now) end
 elseif action=="UnclaimTerritory" then
  if not self.world:CanCommand(player,session,request.targetId,self.sessions) then message="Approach your conquered base to unclaim it."
  else ok,message=self.battles:Unclaim(session,request.targetId,now) end
 elseif action=="CallArmy" then
  ok,message=self.armyCommands:CallArmy(player,session,now)
 elseif action=="GoBase" then
  ok,message=self.armyCommands:GoBase(player,session,now)
	elseif action=="Retreat" or action=="ReturnHome" then message="Manage your lineup in My Army. Chickens walk to and from the fight."
	elseif action=="Debug" then ok,message=self.debug:Run(player,session,request.command,request.argument,now)
	elseif action=="TestNewPlayer" then
		-- Yields while the real save is released; stop if this session ended meanwhile.
		ok,message=self:StartNewPlayerTest(player,session,now)
		if self.sessions[player.UserId]~=session or session.closing then return end
	end
	self.tutorial:Action(session,action,ok,balanceBefore,request,selectionBefore)
	self.analytics:Action(session,action,ok,message,balanceBefore,request,{petId=petId,crate=crate,purchase=purchase})
	if ok then session.lastResult=message;session:Touch() end
	if ok and (action=="Buy" or action=="Expand") then
		self.telemetry:Record("ArmyGrowth",{userId=session.userId,action=action,
			assignment=recruit and recruit.assignment,selectedBefore=selectedBefore,selectedAfter=#session:BestPetIds(),
			spent=math.max(0,balanceBefore-session.coins),balance=session.coins,version=Config.Version,
			profileContext=session.saveStatus,eggReceipts=session.sessionIncome.eggs,
			battleReceipts=session.sessionIncome.battle,territoryReceipts=session.sessionIncome.territory})
	end
	if ok and action=="Buy" and petId then
  self.world:Recruit(session,petId)
  local pending=self.recruitObservations[session.userId] or {};self.recruitObservations[session.userId]=pending
  pending[petId]={at=now,assignment=recruit and recruit.assignment}
  local count,oldestId,oldest=0,nil,math.huge
  for id,intent in pending do count+=1;if intent.at<oldest then oldest,oldestId=intent.at,id end end
  if count>24 and oldestId then pending[oldestId]=nil end
 end
 if ok and action=="Attack" then
  local battle=self.battles.battles[session.outgoing]
  if battle then
   local side=if battle.attacker==session.userId then "A" else "B"
   local count=0;for _,unit in battle.units do if unit.side==side and unit.hp>0 and not unit.contestUnavailable and not unit.retiring then count+=1 end end
   self.telemetry:Record("ArmyDeployed",{userId=session.userId,count=count,selectedCount=#session:BestPetIds(),
    kind=if battle.incomeSite then "Income" else "Conquest",version=Config.Version},"deploy:"..battle.id..":"..session.userId)
  end
 end
	self.armyCommands:Sync(session)
	self.world:UpdateSession(session)
	self:Send(player,{id=request.id,ok=ok,message=message,petId=petId,action=action,recruit=recruit,receipt=receipt,purchase=purchase,crate=crate})
end

-- Settings > Test as a new player: Studio, Config.DebugUserIds and the game's owner.
function GameServer.NewPlayerTestAllowed(player)
	return RunService:IsStudio() or table.find(Config.DebugUserIds or {},player.UserId)~=nil
		or (game.CreatorType==Enum.CreatorType.User and game.CreatorId==player.UserId)
end

-- Turns this session into a disposable brand-new profile. The real save is saved
-- and released FIRST (abort if that fails); afterwards nothing here saves, buys,
-- ranks or counts in analytics. Rejoining loads the real save again.
function GameServer:StartNewPlayerTest(player,session,now)
	if not GameServer.NewPlayerTestAllowed(player) then return false,"Only testers can start a new-player test." end
	self.battles:CancelPlayer(session.userId,now)
	self.armyCommands:Release(session,true)
	if session.saveStatus~="studio-session" then
		self.data:Release(session)
		if self.data.entries[session.userId] then
			return false,"Couldn't save your real progress first, so the test did not start. Try again."
		end
		task.spawn(function() self.leaderboards:Write(session,true) end)
	end
	self.analytics:Leave(session) -- a test session never counts as a real player
	if self.sessions[player.UserId]~=session or session.closing then return false,"Session ended." end
	session.newPlayerTest=true
	session.saveStatus="studio-session"
	session.saveMessage="Testing as a new player. Nothing is saved; rejoin to return to your real save."
	session:Reset()
	session.crateCredits,session.guaranteedLuckRolls=0,0
	session.eggProcessor.finishCredits=0
	session.commerceAutomatic={AutoCollectEggs=true,AutoMerge=true}
	self.commerce:SetTestPreset(player,session,"NoPasses")
	session:RefreshArmy();session:Touch()
	self.world:UpdateSession(session)
	return true,"Testing as a new player. Rejoin anytime to return to your real save."
end

function GameServer:AddPlayer(player)
	if self.sessions[player.UserId] then return end
	local used={}
	for _,session in self.sessions do used[session.plotIndex]=true end
	local index=nil
	for i=1,#Config.PlotPositions do if self.world.plots[i] and not used[i] then index=i;break end end
	if not index and self.sessions[-999] then
		local bot=self.sessions[-999];index=bot.plotIndex
		self.battles:CancelPlayer(bot.userId,os.clock());self.world:Release(bot);bot:Destroy();self.sessions[-999]=nil
	end
	if not index then player:Kick("All plots are full. Please join another server.");return end
	local session=PlayerSession.new(player.UserId,player.DisplayName,index)
	self.sessions[player.UserId]=session
	self.tutorial:Begin(player,session)
	self.analytics:Join(player,session)
	local function spawn(character)
		local root=character:WaitForChild("HumanoidRootPart",10)
		if root and self.sessions[player.UserId]==session then
			character:PivotTo(self.world:SpawnFrame(index))
		end
	end
	self.playerConnections[player.UserId]=player.CharacterAdded:Connect(spawn)
	if player.Character then task.spawn(spawn,player.Character) end
	self.world:UpdateSession(session)
 local testMode=workspace:GetAttribute("PetRollAcceptanceMode")==true
  or (RunService:IsStudio() and workspace:GetAttribute("PetRollPlaytestSessionOnly")==true)
 local unpublished=RunService:IsStudio() and game.GameId==0
 if testMode or unpublished or not Config.SaveEnabled then
  session.loaded=true;session.saveStatus="studio-session";session.saveMessage=if unpublished then "Unsaved local file: session only. Use Pet Roll Test for saved progress." else "Isolated test session; your saved flock is untouched."
 else
  local ok,why=self.data:Load(session)
  if self.sessions[player.UserId]~=session or player.Parent~=Players then
   self.data:Release(session);return
  end
  if not ok then
   warn("[PetRoll] Profile load failed for "..player.UserId..": "..tostring(why))
   self.analytics:LoadFailed(session,why)
   self:Send(player)
   -- Failed reads never create a writable replacement profile.
   task.delay(3,function() if player.Parent==Players then player:Kick(session.saveMessage) end end)
   return
  end
 end
 self.analytics:Loaded(session)
 self.world:UpdateSession(session);self:Send(player)
 task.spawn(function()
  if self.sessions[player.UserId]~=session or player.Parent~=Players then return end
  self.commerce:Load(player,session)
  if self.sessions[player.UserId]==session and player.Parent==Players and not session.closing then self:Send(player) end
 end)
 print("[PetRoll] Ready for "..player.Name.." on plot "..index)
end

function GameServer:RemovePlayer(player)
 local session=self.sessions[player.UserId]
 if not session or session.closing then return end
 self.tutorial:Release(session)
 self.analytics:Leave(session)
 session.closing=true
 self.armyCommands:Remove(player.UserId)
 self.commerce:Release(player)
 self.battles:CancelPlayer(player.UserId,os.clock())
 self.hill:Release(player.UserId)
 self.eggs:Release(session)
 self.world:Release(session)
 self.sessions[player.UserId],self.limits[player.UserId]=nil,nil
 self.syncs[player.UserId],self.sent[player.UserId]=nil,nil
 local connection=self.playerConnections[player.UserId]
 if connection then connection:Disconnect();self.playerConnections[player.UserId]=nil end
 -- Release the profile lease first; the ranking write captures values before yielding.
 self.data:Release(session)
 task.spawn(function() self.leaderboards:Write(session,true) end)
 self.telemetry:Release(player.UserId)
 self.recruitObservations[player.UserId],self.awayObservations[player.UserId]=nil,nil
 session:Destroy()
end

-- Session-local observation of confirmed server state; no gameplay decisions or external analytics.
function GameServer:ObserveLoop(dt,now)
 for id,session in self.sessions do
  if not session.loaded or session.closing or session.saveLost then continue end
  local away=self.awayObservations[id]
  if session.armyState~="Home" then
   if not away then away={at=now,lost=0};self.awayObservations[id]=away end
   local rate=0;for petId in session.pets do if not session:IsPetHome(petId) then rate+=session:PetIncome(petId) end end
   away.lost+=rate*dt
  elseif away then
   self.telemetry:Record("ArmyReturned",{userId=id,seconds=now-away.at,foregoneEggValue=math.floor(away.lost),estimated=true})
   self.awayObservations[id]=nil
  end
  local pending=self.recruitObservations[id]
  if not pending then continue end
  for petId,intent in pending do if now-intent.at>600 or not session.pets[petId] then pending[petId]=nil end end
  local battle=self.battles.battles[session.outgoing]
  if not battle or (battle.phase~="Fight" and battle.phase~="Capture" and battle.phase~="Holding") then continue end
  local side=if battle.attacker==id then "A" else "B"
  for _,unit in battle.units do
   local intent=unit.petId and pending[unit.petId]
   if intent and unit.side==side and unit.hp>0 and not unit.reinforcing and not unit.retiring and battle:ReachedCamp(unit) then
    self.telemetry:Record("RecruitArrived",{userId=id,assignment=intent.assignment,seconds=now-intent.at,
     kind=if battle.incomeSite then "Income" else "Conquest"},"recruit:"..unit.petId)
    pending[unit.petId]=nil
   end
  end
 end
end

function GameServer:Step(dt)
	local now=os.clock()
	self.analytics:Step(dt)
	self.operations:Step(now)
	local wallTime=os.time()
	if wallTime~=(self.researchCheckedAt or 0) then
		self.researchCheckedAt=wallTime
		for _,session in self.sessions do
			if session.loaded and not session.closing and not session.saveLost then ResearchService.Complete(session,wallTime) end
		end
	end
	if Config.Features.Merging and now>=(self.nextAutomaticAt or 0) then
		self.nextAutomaticAt=now+1
		for _,session in self.sessions do
			if session.loaded and not session.closing and not session.saveLost then ArmyService.AutoMerge(session) end
		end
	end
	self.armyCommands:Step(now)
	self.world:Step(now)
 self.hill:Step(dt,now)
 self.leaderboards:Step(now)
 self.data:Step()
	self.stepAccumulator+=dt
	self.snapshotAccumulator+=dt
	local steps=0
	while self.stepAccumulator>=Config.BattleStep and steps<10 do
		self.stepAccumulator-=Config.BattleStep;steps+=1
		self.battles:Step(Config.BattleStep,now-self.stepAccumulator)
		self.eggs:Step(self.sessions,Config.BattleStep,now-self.stepAccumulator)
  self:ObserveLoop(Config.BattleStep,now-self.stepAccumulator)
	end
	if self.snapshotAccumulator>=Config.SnapshotInterval then
		self.snapshotAccumulator=0
		for _,session in self.sessions do self.world:UpdateSession(session) end
		for _,player in Players:GetPlayers() do
			local session=self.sessions[player.UserId]
			local sync=self.syncs[player.UserId]
			if sync and sync.pending then
				local id=sync.pending;sync.pending=nil;sync.readyAt=now+SYNC_COOLDOWN
				self:Send(player,{id=id,action="Sync",ok=true})
			elseif session and self:SnapshotDue(session,now) then self:Send(player) end
		end
		self.remotes.BattleChanged:FireAllClients(self.battles:Snapshots(now))
	end
end

function GameServer:Start()
	assert(not self.started,"GameServer already started")
	self.started=true
	assert(self.products:Start(),"Could not initialize purchase delivery")
	self.world:Build()
	self.leaderboards:Build()
	self.analytics:Start()
	local folder=ReplicatedStorage.PetRoll:FindFirstChild("Remotes")
	if not folder then folder=Instance.new("Folder");folder.Name="Remotes";folder.Parent=ReplicatedStorage.PetRoll end
	for _,name in {"RequestAction","StateChanged","BattleChanged"} do
		if not folder:FindFirstChild(name) then local remote=Instance.new("RemoteEvent");remote.Name=name;remote.Parent=folder end
	end
	self.remotes=folder
	self.world.onAction=function(player,action,index,offerId)
		self:Handle(player,{action=action,id=0,stationIndex=index,offerId=offerId})
	end
	table.insert(self.connections,folder.RequestAction.OnServerEvent:Connect(function(player,request) self:Handle(player,request) end))
	table.insert(self.connections,Players.PlayerAdded:Connect(function(player) self:AddPlayer(player) end))
	table.insert(self.connections,Players.PlayerRemoving:Connect(function(player) self:RemovePlayer(player) end))
	for _,player in Players:GetPlayers() do task.spawn(function() self:AddPlayer(player) end) end
	table.insert(self.connections,RunService.Heartbeat:Connect(function(dt) self:Step(dt) end))
	game:BindToClose(function() self:Shutdown() end)
 print("[PetRoll] My Chicken Army! "..Config.Version.." ready. Yard chickens lay eggs; collect them for coins.")
end

-- The only BindToClose path: settle eggs, release every profile within the
-- DataService close budget, write rankings alongside, then tear down.
function GameServer:Shutdown()
	if self.shuttingDown then return end
	self.shuttingDown=true
	local closing={}
	for _,session in self.sessions do
		self.tutorial:Release(session);session.closing=true;self.eggs:Release(session);table.insert(closing,session)
	end
	local closed,analyticsClosed=false,false
	task.spawn(function() self.data:Close();closed=true end)
	-- Analytics leaves every session and flushes its ledger beside the save close.
	task.spawn(function() self.analytics:Close();analyticsClosed=true end)
	for _,session in closing do task.spawn(function() self.leaderboards:Write(session,true) end) end
	local deadline=os.clock()+27
	while (not closed or not analyticsClosed) and os.clock()<deadline do task.wait(0.1) end
	if self.started then self:Destroy() end
end

function GameServer:Destroy()
	for _,session in self.sessions do self.tutorial:Release(session);session.closing=true;self.eggs:Release(session) end
	for _,connection in self.connections do connection:Disconnect() end
	for _,connection in self.playerConnections do connection:Disconnect() end
	self.products:Destroy();self.leaderboards:Destroy();self.commerce:Destroy();self.eggs:Destroy();self.operations:Destroy();self.battles:Destroy();self.world:Destroy()
	self.telemetry:Destroy()
	self.analytics:Destroy()
	TutorialService.Transport,TutorialService.onProgress,TutorialService.onIncome=nil,nil,nil
 table.clear(self.recruitObservations);table.clear(self.awayObservations)
	self.started=false
end

return GameServer
