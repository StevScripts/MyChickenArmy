--!strict
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local CombatRewards=require(Shared.CombatRewards)
local ShopCatalog=require(Shared.ShopCatalog)
local Progression=require(Shared.Progression)
local FlockLayout=require(Shared.FlockLayout)
local Battle=require(script.Parent.Battle)
local LiveBattleActors=require(script.Parent.LiveBattleActors)
local KingEncounter=require(script.Parent.KingEncounter)
local CampaignRoute=require(Shared.CampaignRoute)
local March=require(Shared.ArmyMarch)
local MapLayout=require(Shared.MapLayout)
local Reinforcements=require(script.Parent.ArmyReinforcements)
local TerritoryContest=require(script.Parent.TerritoryContest)
local TerritoryIncome=require(script.Parent.TerritoryIncome)
local BattleService={}
BattleService.__index=BattleService

function BattleService.new(sessions,world)
	return setmetatable({sessions=sessions,world=world,battles={},campBusy={},campOwners={},territoryReclaims={},departingCamps={},departingSides={},campClearedAt={},campLocations={},
  territoryIncome=TerritoryIncome.new((Config.IncomeOutpost and Config.IncomeOutpost.Rate) or 0),
  income={graceUntil=0,retry={},eligibleTime=0,warningAfter=(Config.IncomeOutpost and Config.IncomeOutpost.WarningAfter) or 120}},BattleService)
end

local function pvpRank(attacker,defender)
 return math.min(attacker.promotion or 1,defender.promotion or 1)
end

-- The battle identity (not presence of its defender session) excludes PvP.
local function killReward(session,unit,rank,isNpc)
 local amount=CombatRewards.ForUnit(unit,rank)
 if isNpc and not unit.boss and session.entitlements and session.entitlements.DoubleBounty==true then
  amount*=ShopCatalog.BountyMultiplier
 end
 if isNpc then amount=math.floor(amount*(1+(session.researchEffects and session.researchEffects.bounty or 0))) end
 return amount
end

local function campKey(plot,index) return tostring(plot)..":"..tostring(index) end
function BattleService:CampPosition(index,plot)
 if self.world.CampPosition then return self.world:CampPosition(index,plot) end
 local p=Config.Camps[index].position;return Vector3.new(p[1],1,p[2])
end

function BattleService:TerritoryKey(session,target)
 return if target:sub(1,5)=="camp:" then campKey(session.plotIndex,tonumber(target:sub(6))) else target
end

-- Only this player's outgoing NPC encounter can be redirected. Shared income
-- contests retain their separate participant/withdrawal rules.
function BattleService:CanRedirect(session,battle)
 return battle~=nil and not battle.operationId and battle.attacker==session.userId and not battle.defender
  and (not battle.incomeSite or battle.phase=="Holding")
  and (battle.phase=="Travel" or battle.phase=="Fight" or battle.phase=="Capture" or battle.phase=="Holding")
end

function BattleService:TerritoryBlocked(key,previous)
 local reserved=self.campBusy[key]
 return reserved~=nil and not (previous and reserved==previous.id
  and self.departingCamps[key]==previous.id and key~=previous.campKey)
end

function BattleService:PlanOrder(session,target,camps,outposts,keepRoute)
 local route=CampaignRoute.Plan(target,camps,outposts)
 -- A manual camp redirect replaces the current encounter immediately. Orders
 -- from home, automatic route steps and the King's prerequisites stay ordered.
 if route and not keepRoute and target:sub(1,5)=="camp:"
  and self:CanRedirect(session,self.battles[session.outgoing]) then return {target} end
 return route
end

-- Current occupancy and this forward main-route push grant passage. Saved wins
-- never bypass a newly restored garrison, and side trips discard route passage.
function BattleService:RouteProgress(session)
 local camps,outposts={},{}
 for i=1,#Config.Camps do
  local owner=self.campOwners[campKey(session.plotIndex,i)]
  if owner and owner.userId==session.userId then camps[i]=true end
 end
 for i=1,#Progression.Outposts() do
  local owner=self.campOwners["outpost:"..i]
  if owner and owner.userId==session.userId then outposts[i]=true end
 end
 local active=self.battles[session.outgoing]
 if active and active.phase~="Returning" and (active.campIndex or active.isKing) then
  local frontier=if active.isKing then #Config.Camps else active.campIndex
  for i=1,frontier do
   if active.routeCamps and active.routeCamps[i] then camps[i]=true end
  end
 end
 return camps,outposts
end

function BattleService:SetTerritoryOwner(key,session,location)
 local previous=self.campOwners[key]
 if session then self.territoryReclaims[key]=nil end
 if key=="income:1" then
  -- Observation history only; never consulted for income or command permission.
  self.income.lostOwners=self.income.lostOwners or {}
  if previous and previous.userId~=(session and session.userId) then self.income.lostOwners[previous.userId]=true end
  if session then self.income.lostOwners[session.userId]=nil end
 end
 location=location or (previous and previous.location)
 self.campOwners[key]=if session then {userId=session.userId,name=session.name,location=location} else nil
 if location and self.world.SetTerritoryOwner then
  self.world:SetTerritoryOwner(location,session and session.userId,session and session.name)
 end
 if previous and previous.userId~=(session and session.userId) then
  local old=self.sessions[previous.userId]
  if old then
   if session then old.lastResult="A territory was captured by another army." end
   old:Touch()
  end
 end
 if session then session:Touch() end
end

-- Moving an army never releases its flag. Only the owning player's explicit
-- command starts this recovery; existing combat/kill/recruit rules still apply.
function BattleService:Unclaim(session,targetId,now)
 if type(targetId)~="string" or #targetId>60 then return false,"Invalid territory." end
 local kind,index=targetId:match("^(%a+):(%d+)$")
 index=tonumber(index)
 if not index or (kind~="camp" and kind~="outpost" and targetId~=KingEncounter.Target) then return false,"Invalid territory." end
 local key=self:TerritoryKey(session,targetId)
 local owner=self.campOwners[key]
 if not owner or owner.userId~=session.userId then return false,"You do not own this base." end
 local location=owner.location or self.campLocations[key]
 if not location then return false,"This base is unavailable." end
 local battle=self.battles[self.campBusy[key]]
 local active=battle and battle.campKey==key and battle.phase~="Returning"
 local reclaim={id="unclaim:"..key,ownerId=session.userId,target=targetId,location=location,
  name=CampaignRoute.Name(targetId),captureElapsed=Config.CaptureSeconds}
 self.territoryReclaims[key]=reclaim
 self:SetTerritoryOwner(key,nil,location)
 if location.index then
  for _,other in self.battles do
   if other.plotIndex==location.plot and other.routeCamps then other.routeCamps[location.index]=nil end
  end
 end
 if active and battle.attacker==session.userId and (battle.phase=="Holding" or battle.friendlyTerritory) then
  -- Unclaim does not recall/heal/replace the player's squad. A fresh garrison
  -- fights those same units, which can win the territory back themselves.
  local roster=if location.king then KingEncounter.Definition(battle.promotion).roster
   elseif location.outpost then Progression.OutpostRoster(location.outpost)
   else Progression.Roster(battle.promotion,location.index)
  battle:CancelAttacks()
  battle.paid,battle.friendlyTerritory,battle.outcome=false,false,nil
  battle.phase=if battle.phase=="Travel" then "Travel" else "Fight"
  battle.phaseAt,battle.captureStarted,battle.captureElapsed=now,true,Config.CaptureSeconds
  battle.routeGoal=nil
  battle:AddArmy("B",roster,battle.destination)
  reclaim.battleId=battle.id
  if battle.actors then battle.actors:Sync(now);battle.actors:Publish(now) end
  session.armyState,session.stationedAt=if battle.phase=="Travel" then "Traveling" else "Fighting",nil
 elseif active then
  -- An army already contesting this base keeps its own capture progress.
  self.territoryReclaims[key]=nil
 end
 session:Touch()
 return true,"Base unclaimed. Enemies are taking it back."
end

function BattleService:StepTerritoryReclaims(dt,now)
 for key,reclaim in self.territoryReclaims do
  local battle=self.battles[reclaim.battleId]
  local fighting=battle and battle.campKey==key and battle.phase~="Returning"
  if fighting and battle:Alive("B")==0 then
   -- Ordinary capture resumes from the remaining control once defenders fall.
   self.territoryReclaims[key]=nil
   continue
  end
  if fighting or not self.campBusy[key] then
   reclaim.captureElapsed=math.max(0,reclaim.captureElapsed-dt)
   if fighting then battle.captureElapsed=reclaim.captureElapsed end
   if reclaim.captureElapsed==0 then
    reclaim.completedAt=reclaim.completedAt or now
    if now-reclaim.completedAt>=1 then self.territoryReclaims[key]=nil end
   end
  end
 end
end

function BattleService:Targets(session,now)
	local targets={}
 local previous=self.battles[session.outgoing]
 local canMove=self:CanRedirect(session,previous) or ((not session:IsArmyLocked() or session.armyState=="Following") and not session.outgoing)
 local routeCamps,routeOutposts=self:RouteProgress(session)
 local camps=Progression.Camps(session.promotion)
	for i,camp in camps do
  local key=campKey(session.plotIndex,i)
		local occupied=self.battles[self.campBusy[key]]
		local nextIndex=i
  for earlier=1,i-1 do if not routeCamps[earlier] then nextIndex=earlier;break end end
		local blocked=self.campBusy[campKey(session.plotIndex,nextIndex)]~=nil
		table.insert(targets,{id="camp:"..i,name=camp.name,kind="Camp",power=Rules.Power(Progression.Roster(session.promotion,i)),
			count=#camp.roster,
			available=not blocked and not self.campBusy[key],
			via=if nextIndex<i then camps[nextIndex].name else nil,
			reason=if occupied and occupied.phase=="Holding" then (if occupied.attacker==session.userId then "Your army is stationed here" else "Occupied by another army")
			elseif self.campBusy[key] then "Occupied · army has not cleared this camp"
			elseif blocked then "Route blocked · "..camps[nextIndex].name.." is occupied"
			elseif nextIndex<i then "First conquer "..camps[nextIndex].name else "Ready"})
	end
 for i,camp in Progression.Outposts() do
  local key="outpost:"..i
  local unlocked=(session.promotion or 1)>=camp.tier
  table.insert(targets,{id=key,name=i.." · "..camp.name,kind="Outpost",
   power=Rules.Power(Progression.OutpostRoster(i)),count=#camp.roster,
   
   available=unlocked and not self.campBusy[key],
   reason=if not unlocked then Progression.Requirement(camp.tier)
    elseif self.campBusy[key] then "Occupied · wait for the army to leave" else "Explore this territory"})
 end
 local king=KingEncounter.Definition(4)
 local occupied=self.battles[self.campBusy[KingEncounter.Target]]
 local unlocked=Progression.KingUnlocked(routeCamps,routeOutposts,false)
 table.insert(targets,{id=KingEncounter.Target,name=king.name.." · FINAL BOSS",
  kind="King",power=king.power,count=#king.roster,
  available=unlocked and not self.campBusy[KingEncounter.Target],
  reason=if not unlocked then "Conquer all "..#camps.." home camps"
   elseif occupied then (if occupied.attacker==session.userId then "Your army holds the center" else "Center occupied by another army")
   elseif self.campBusy[KingEncounter.Target] then "Wait for the previous army to clear the arena"
   else "Challenge the Chicken King"})
 for _,entry in targets do
  local route=self:PlanOrder(session,entry.id,routeCamps,routeOutposts)
  if route then
   local first=route[1]
   local firstKey=if first:sub(1,5)=="camp:" then campKey(session.plotIndex,tonumber(first:sub(6))) else first
   local finalKey=if entry.kind=="Camp" then campKey(session.plotIndex,tonumber(entry.id:sub(6))) else entry.id
   entry.available=canMove and not self:TerritoryBlocked(firstKey,previous) and not self:TerritoryBlocked(finalKey,previous)
   entry.via=if #route>1 then CampaignRoute.Name(first) else nil
   entry.reason=if previous and previous.target==entry.id then "Your army is already attacking or stationed here"
    elseif not canMove then "Your army is returning or defending"
    elseif not entry.available then "Occupied by an army" elseif entry.via then "Via "..entry.via else "Ready"
   local owner=self.campOwners[finalKey]
   entry.owned=owner~=nil and owner.userId==session.userId
   entry.canUnclaim=entry.owned
   entry.ownerId=owner and owner.userId
   if owner then
    entry.power,entry.count=0,0
    if entry.available and not entry.via then entry.reason=if entry.owned then "Conquered · station army" else "Capture from "..owner.name end
   end
  end
  local kind,index=string.match(entry.id,"^(%a+):([%-]?%d+)$")
  index=tonumber(index)
  local roster={}
  if kind=="camp" then roster=Progression.Roster(session.promotion,index)
  elseif kind=="outpost" then roster=Progression.OutpostRoster(index)
  elseif kind=="king" then roster=king.roster end
  local low,high=math.huge,0
  for _,unit in roster do
   local amount=killReward(session,unit,nil,true)
   low,high=math.min(low,amount),math.max(high,amount)
  end
  entry.killRewardMin,entry.killRewardMax=if low==math.huge then 0 else low,high
  if entry.ownerId then entry.killRewardMin,entry.killRewardMax=0,0 end
 end
 local income=self:IncomeSummary(session,now)
 if income then
  local entry=table.clone(income);entry.id=income.targetId;entry.kind="Income"
  entry.owned=income.ownerId==session.userId;entry.killRewardMin,entry.killRewardMax=0,0
  table.insert(targets,entry)
 end
 return targets
end

local function incomeEnabled()
 return Config.IncomeOutpost and Config.IncomeOutpost.Enabled==true
end

local function readySession(session)
 return session and session.loaded==true and not session.closing and not session.saveLost
end

local function clientDeadline(deadline,now)
 return if deadline and deadline>now then workspace:GetServerTimeNow()+(deadline-now) else nil
end

function BattleService:IncomeHolder()
 local battle=self.battles[self.campBusy["income:1"]]
 return if battle and battle.target=="income:1" and battle.phase=="Holding" then battle else nil
end

function BattleService:IncomeSummary(session,now)
 if not incomeEnabled() then return nil end
 local config,state=Config.IncomeOutpost,self.income
 local owner=self.campOwners["income:1"]
 local ownerSession=owner and self.sessions[owner.userId]
 local contest=self.battles[state.contestId]
 local raid=self.battles[state.raidId]
 local holder=self:IncomeHolder()
 local garrison=if contest and contest.defender then contest else holder
 local side=if garrison==contest then "B" else "A"
 local power,count=0,0
 if garrison then for _,unit in garrison.units do
  if unit.side==side and unit.hp>0 and not unit.retiring then
   count+=1;power+=Rules.PetPower(unit.species,unit.stars,unit.level)
  end
 end end
 if not owner and not garrison then power=Rules.Power(config.NeutralRoster);count=#config.NeutralRoster end
 local active=contest~=nil and contest.incomeActiveAt~=nil and not contest.paid
 local owned=session and owner and owner.userId==session.userId
 local action=if not owner then "Conquer" elseif owned then "Station army" elseif count>0 then "Attack defenders" else "Capture territory"
 local available,reason=true,"Ready"
 if owned and contest then
  action="Defend territory"
  if contest.defender==session.userId then available,reason=false,"Your army is defending"
  elseif session.outgoing and self.battles[session.outgoing] and self.battles[session.outgoing].incomeJoin then available,reason=false,"Your army is returning to defend"
  elseif contest.committedUsers and contest.committedUsers[session.userId] then available,reason=false,"Your army has already fought in this contest" end
 elseif contest then available,reason=false,"A contest is already underway"
 elseif holder and owned then available,reason=false,"Your army is stationed here"
 elseif owner and not owned and not config.ContestsEnabled then available,reason=false,"Player contests are disabled in this test"
 elseif not owned and state.graceUntil>now then available,reason=false,"Territory recovering"
 elseif session and not owned and (state.retry[session.userId] or 0)>now then available,reason=false,"Try again shortly"
 elseif not contest and not holder and self.campBusy["income:1"] then available,reason=false,"Wait for the previous army to clear" end
 if available and session then
  local previous=self.battles[session.outgoing]
  local canMove=self:CanRedirect(session,previous) or ((not session:IsArmyLocked() or session.armyState=="Following") and not session.outgoing)
  if not canMove then available,reason=false,"Your army is busy · finish the current attack" end
 end
 return {targetId="income:1",name=config.Name,ownerId=owner and owner.userId,ownerName=owner and owner.name,
  configuredRate=config.Rate,effectiveRate=if readySession(ownerSession) and not active then config.Rate else 0,
  contested=active,garrisonOwnerId=if garrison then (if side=="A" then garrison.attacker else garrison.defender) else nil,
  contestId=contest and contest.id,graceEndsAt=clientDeadline(state.graceUntil,now),
  retryEndsAt=clientDeadline(session and state.retry[session.userId],now),
  npcWarningEndsAt=clientDeadline(state.warningUntil,now),npcApproaching=raid~=nil and not raid.incomeActiveAt,
  available=available,action=action,reason=reason,power=power,count=count}
end

function BattleService:NewIncomeBattle(attacker,origin,now)
 local frame=self.world:IncomeFrame()
 local battle=Battle.new(HttpService:GenerateGUID(false),attacker,"income:1",origin,frame.Position,now)
 battle.name=Config.IncomeOutpost.Name;battle.frame=frame;battle.incomeSite=true;battle.preserveHealth=true
 battle.marchDestination=(frame*CFrame.new(0,0,Config.CampHalfSize-2)).Position
 battle.campKey="income:1";battle.routeCamps={};battle.routeOutposts={}
 battle.contestSeconds=Config.IncomeOutpost.ContestSeconds
 battle.committedUsers={}
 TerritoryContest.CreateActors(battle,self.world)
 return battle
end

function BattleService:ReserveIncome(battle)
 self.campBusy["income:1"]=battle.id;self.departingCamps["income:1"]=nil;self.departingSides["income:1"]=nil
 self.campLocations["income:1"]={income=true,position=battle.destination,frame=self.world:IncomeFrame(),halfSize=Config.CampHalfSize}
 if self.world.SetIncomeBusy then self.world:SetIncomeBusy(true) end
end

function BattleService:RecordIncomeContest(name,battle,now,outcome,activeAt)
 if not self.telemetry then return end
 local kind=if battle.npcRaid then "NPC" elseif battle.incumbent then "Player" else "Neutral"
 for _,participant in {{id=battle.attacker,role="Challenger"},{id=battle.incumbent,role="Owner"}} do
  if not participant.id or not self.sessions[participant.id] then continue end
  local result
  if outcome then
   if participant.role=="Owner" then result=if outcome=="A" then "Lost" elseif outcome=="B" then "Defended" else "Retained"
   else result=if outcome=="A" then "Captured" elseif outcome=="Retreat" then "Returning" elseif outcome=="Draw" then "Timed out" elseif outcome=="Cancelled" then "Cancelled" else "Defeated" end
  end
  self.telemetry:Record(name,{userId=participant.id,role=participant.role,kind=kind,result=result,
   duration=if activeAt then math.max(0,now-activeAt) else 0,active=activeAt~=nil,
   participated=participant.role=="Challenger" or (battle.committedUsers and battle.committedUsers[participant.id])==true},
   battle.id..":"..participant.role)
 end
end

function BattleService:ActivateIncome(battle,now)
 if battle.incomeActiveAt then return end
 if battle.npcRaid then
  local owner=self.campOwners["income:1"]
  if not owner or owner.userId~=battle.incumbent then return "Cancelled" end
  local holder=self:IncomeHolder()
  if holder and holder.attacker==owner.userId then self:CommitIncomeDefender(battle,holder,now) end
  local ownerSession=self.sessions[owner.userId]
  local returning=ownerSession and self.battles[ownerSession.outgoing]
  if returning and returning~=battle and returning.target=="income:1" and returning.phase=="Travel" then
   battle.committedUsers[owner.userId]=true
   returning.incomeJoin=battle.id;returning.friendlyTerritory=false;returning.captureElapsed=0
   returning.beforeIncomeArrival=function() return "Join" end
   TerritoryContest.Lock(returning)
  end
  self.income.raidId=nil;self.income.contestId=battle.id
  self:ReserveIncome(battle)
  TerritoryContest.Lock(battle)
 end
 battle.incomeActiveAt=now
 self:RecordIncomeContest("TerritoryContestStarted",battle,now,nil,now)
end

function BattleService:CancelIncomeApproach(now)
 local state=self.income
 local raid=self.battles[state.raidId]
 if raid and not raid.incomeActiveAt then self:Remove(raid) end
 state.raidId=nil;state.warningUntil=nil;state.eligibleTime=0
end

function BattleService:StartIncomeRaid(owner,now)
 local frame=self.world:IncomeFrame()
 local origin=(frame*CFrame.new(0,0,-48)).Position
 local battle=self:NewIncomeBattle(0,origin,now)
 battle.npcRaid=true;battle.incumbent=owner.userId;battle.campKey=nil
 battle:AddArmy("A",Config.IncomeOutpost.RaidRoster,origin)
 for index,unit in battle.units do
  local x,z=FlockLayout.Offset(index,#battle.units)
  local at=(CFrame.new(origin)*CFrame.new(x,0,z)).Position
  unit.x,unit.z,unit.startX,unit.startZ=at.X,at.Z,at.X,at.Z
  unit.homeX,unit.homeZ=at.X,at.Z
  March.Approach(unit,battle.destination,now)
 end
 TerritoryContest.Lock(battle)
 battle.beforeIncomeArrival=function(b,t) return self:ActivateIncome(b,t) end
 self.battles[battle.id]=battle;self.income.raidId=battle.id;self.income.warningUntil=nil
 if battle.actors then battle.actors:Sync(now) end
end

function BattleService:StepIncome(dt,now)
 if not incomeEnabled() then return end
 local state,config=self.income,Config.IncomeOutpost
 local owner=self.campOwners["income:1"]
 local session=owner and self.sessions[owner.userId]
 local contest=self.battles[state.contestId]
 local active=contest and contest.incomeActiveAt and not contest.paid
 -- Settle the elapsed simulation slice before this tick can activate, resolve
 -- or transfer a contest. Neither a wall-clock stall nor a client pays catchup.
 if readySession(session) and not active then
  local amount=self.territoryIncome:Step(session,dt)
  if amount>0 then
   state.receipts=state.receipts or {};state.receipts[session.userId]=(state.receipts[session.userId] or 0)+amount
  end
 end
 state.receiptElapsed=(state.receiptElapsed or 0)+math.max(0,dt)
 if state.receiptElapsed>=10 then
  if self.telemetry then for id,amount in state.receipts or {} do self.telemetry:Record("TerritoryIncome",{userId=id,amount=amount}) end end
  state.receipts={};state.receiptElapsed=0
 end
 if not config.NpcEnabled or not config.ContestsEnabled or not readySession(session) then
  if not active then self:CancelIncomeApproach(now) end
  return
 end
 local real=if self.isRealPlayer then self.isRealPlayer(owner.userId) else game:GetService("Players"):GetPlayerByUserId(owner.userId)~=nil
 if not real then if not active then self:CancelIncomeApproach(now) end;return end
 if state.clockOwner~=owner.userId then
  self:CancelIncomeApproach(now);state.clockOwner=owner.userId
  state.warningAfter=if state.warnedOnce then config.RepeatAfter else config.WarningAfter
 end
 if contest then return end
 local raid=self.battles[state.raidId]
 if raid then
  if raid.incumbent~=owner.userId then self:CancelIncomeApproach(now) end
  return
 end
 if state.warningUntil then
  if now>=state.warningUntil then self:StartIncomeRaid(owner,now) end
  return
 end
 if state.graceUntil>now or self.departingCamps["income:1"] then return end
 state.eligibleTime+=math.max(0,dt)
 if state.eligibleTime>=state.warningAfter then
  state.eligibleTime=0;state.warningUntil=now+config.WarningSeconds;state.warnedOnce=true
  session.banner="Raid approaching the Supply Outpost. Send your army to defend if you want.";session:Touch()
  if self.telemetry then self.telemetry:Record("NPCWarning",{userId=session.userId,warningSeconds=config.WarningSeconds}) end
 end
end

function BattleService:CommitIncomeDefender(battle,holder,now)
 local defender=self.sessions[holder.attacker]
 if not defender then return end
 battle.defender=defender.userId
 battle.committedUsers[defender.userId]=true
 TerritoryContest.AddPlayer(battle,defender,self.world,now,"B",holder,true)
 self:Remove(holder,battle,"B")
 TerritoryContest.Assign(defender,battle,"B",if battle.incomeActiveAt then "Fighting" else "Deployed")
 defender.banner="Your Supply Outpost is under attack!";defender:Touch()
 self:ReserveIncome(battle)
end

function BattleService:AttackIncome(session,now)
 if not incomeEnabled() then return false,"Target does not exist." end
 local summary=self:IncomeSummary(session,now)
 if not summary.available then return false,summary.reason end
 local previous=self.battles[session.outgoing]
 local moving=self:CanRedirect(session,previous)
 if #session:Lineup()==0 then return false,"Add at least one chicken first." end
 local owner=self.campOwners["income:1"]
 local owned=owner and owner.userId==session.userId
 local joining=owned and self.battles[self.income.contestId]
 if not owned then self:CancelIncomeApproach(now);self.income.eligibleTime=0 end
 local origin=if moving then previous.destination else self.world:Position(session.plotIndex)
 local battle=self:NewIncomeBattle(session.userId,origin,now)
 battle.plotIndex,battle.promotion=session.plotIndex,session.promotion or 1
 battle.incumbent=owner and owner.userId
 battle.friendlyTerritory=owned and not joining
 if battle.friendlyTerritory then battle.captureElapsed=Config.CaptureSeconds end
 if moving then self:RewardKills(previous,now) end
 TerritoryContest.AddPlayer(battle,session,self.world,now,"A",if moving then previous else nil,false)
 if moving then self:Remove(previous,battle) end
 if joining then
  joining.committedUsers[session.userId]=true
  battle.incomeJoin=joining.id
  battle.beforeIncomeArrival=function() return "Join" end
  TerritoryContest.Lock(battle)
 elseif not owned then
  local holder=self:IncomeHolder()
  if holder and owner and holder.attacker==owner.userId then self:CommitIncomeDefender(battle,holder,now)
  elseif not owner then battle:AddArmy("B",Config.IncomeOutpost.NeutralRoster,battle.destination) end
  TerritoryContest.Lock(battle)
  battle.beforeIncomeArrival=function(b,t) return self:ActivateIncome(b,t) end
  self.income.contestId=battle.id
 end
 self.battles[battle.id]=battle
 TerritoryContest.Assign(session,battle,"A","Traveling")
 if not owned and self.telemetry and self.income.lostOwners and self.income.lostOwners[session.userId] then
  self.telemetry:Record("TerritoryRetakeStarted",{userId=session.userId,kind="Player order"},"retake:"..battle.id)
 end
 if not joining then self:ReserveIncome(battle) end
 if self.world.root then
  self.world:UpdateSession(session)
  if battle.defender and self.sessions[battle.defender] then self.world:UpdateSession(self.sessions[battle.defender]) end
  battle.actors:Sync(now)
  battle.actors:Publish(now)
 end
 return true,if joining then "Army returning to defend the outpost." elseif owned then "Army marching to your outpost." else "Army sent to the Supply Outpost."
end

function BattleService:Attack(session,targetId,now,keepRoute)
	if type(targetId)~="string" or #targetId>60 then return false,"Invalid target." end
	if targetId:sub(1,5)=="base:" then return false,"Home bases are safe. Challenge a camp instead." end
	if targetId=="income:1" then return self:AttackIncome(session,now) end
	local requestedTarget=targetId
 local routeCamps,routeOutposts=self:RouteProgress(session)
 local route=self:PlanOrder(session,targetId,routeCamps,routeOutposts,keepRoute)
	if not route then return false,"Target does not exist." end
	targetId=route[1]
	local previous=self.battles[session.outgoing]
	local moving=self:CanRedirect(session,previous)
	if not moving and (session:IsArmyLocked() or session.outgoing) then return false,"Your army is returning or defending. Wait until it is ready." end
	if previous and (previous.target==requestedTarget or previous.target==targetId) then return false,"Your army is already attacking or stationed at this camp." end
	local roster=session:Lineup()
	if #roster==0 then return false,"Add at least one animal to your army first." end
	local kind,id=string.match(targetId,"^(%a+):([%-]?%d+)$")
	local index=tonumber(id)
	local defender,defenders,destination,name,campIndex,routeGoal
 local isKing=targetId==KingEncounter.Target
 local outpostIndex=if kind=="outpost" and index and Progression.Outposts()[index] then index else nil
 local camps=Progression.Camps(session.promotion)
	if isKing then
  if not Progression.KingUnlocked(routeCamps,routeOutposts,false) then
   return false,"Conquer all "..#camps.." home camps before challenging the Chicken King."
  end
  if self:TerritoryBlocked(KingEncounter.Target,previous) then return false,"The center is occupied. Wait for that army to leave." end
  local king=KingEncounter.Definition(session.promotion or 1)
  defenders,destination,name=king.roster,Vector3.new(0,1.05,0),king.name
 elseif outpostIndex then
  local camp=Progression.Outposts()[outpostIndex]
  if self:TerritoryBlocked(targetId,previous) then return false,"This outpost is occupied. Wait for the army to leave." end
  defenders=Progression.OutpostRoster(outpostIndex)
  destination=self.world:OutpostFrame(outpostIndex).Position
  name=camp.name
 elseif kind=="camp" and index and camps[index] then
		if self:TerritoryBlocked(campKey(session.plotIndex,index),previous) then return false,camps[index].name.." is occupied." end
		local camp=camps[index]
		campIndex=index
		defenders=Progression.Roster(session.promotion,index)
		destination=self:CampPosition(index,session.plotIndex)
		name=camp.name
	else return false,"Target does not exist." end
	-- Cleared territories have no hostile garrison. A rival must still complete
	-- the capture meter; the current owner may simply station their army here.
	local territoryOwner=self.campOwners[self:TerritoryKey(session,targetId)]
	if territoryOwner then defenders={} end
	local battleId=HttpService:GenerateGUID(false)
	local origin=if moving then previous.destination else self.world:Position(session.plotIndex)
	local battle=Battle.new(battleId,session.userId,targetId,origin,destination,now)
	battle.name,battle.campIndex=name,campIndex
 battle.routeCamps,battle.routeOutposts=table.clone(routeCamps),table.clone(routeOutposts)
 battle.plotIndex=session.plotIndex
 battle.isKing=isKing
 battle.outpostIndex=outpostIndex
 battle.promotion=session.promotion or 1
 battle.campCount=#camps
 battle.campKey=if isKing then KingEncounter.Target elseif outpostIndex then targetId elseif campIndex then campKey(session.plotIndex,campIndex) else nil
 battle.friendlyTerritory=territoryOwner~=nil and territoryOwner.userId==session.userId
 if campIndex and not battle.friendlyTerritory then battle.routeCamps[campIndex]=nil end
 if battle.friendlyTerritory then battle.captureElapsed=Config.CaptureSeconds end
 local reclaim=self.territoryReclaims[battle.campKey]
 if reclaim then
  if reclaim.ownerId==session.userId then
   battle.captureElapsed=reclaim.captureElapsed;battle.captureStarted=true;reclaim.battleId=battleId
  else self.territoryReclaims[battle.campKey]=nil end
 end
 if isKing then
  local outward=Vector3.new(origin.X,0,origin.Z)
  if outward.Magnitude<1 then outward=self.world:Position(session.plotIndex) end
  local angle=math.atan2(outward.Z,outward.X)
  local spoke=-math.pi/2+math.round((angle+math.pi/2)/(math.pi/3))*math.pi/3
  battle.frame=CFrame.lookAt(destination,destination-Vector3.new(math.cos(spoke),0,math.sin(spoke)))
 elseif outpostIndex then battle.frame=self.world:OutpostFrame(outpostIndex)
 elseif campIndex and self.world.CampFrame then battle.frame=self.world:CampFrame(campIndex,session.plotIndex)
 elseif defender and self.world.PlotFrame then battle.frame=self.world:PlotFrame(defender.plotIndex)*CFrame.new(0,0,-16) end
	battle.target=if campIndex then "camp:"..campIndex else targetId
	battle.routeGoal=if #route>1 then requestedTarget else nil
 battle.routeGoalName=if battle.routeGoal then CampaignRoute.Name(battle.routeGoal) else nil
	battle.defender=if defender then defender.userId else nil
	if moving then
		-- Carry the same lives and every incoming/relieved bird across encounter boundaries.
		battle.serial=previous.serial
		for _,old in previous.units do if old.side=="A" then
			local u=table.clone(old);u.pendingAttack=nil;u.targetId=nil;u.firstAttack=true
			local x,z=FlockLayout.Entry(u.slot or 1,session:Capacity(),"A")
			local at=((battle.frame or CFrame.new(destination))*CFrame.new(x,0,z)).Position
			u.entryX,u.entryZ=at.X,at.Z;u.startX,u.startZ=u.x,u.z
			table.insert(battle.units,u)
		end end
	else battle:AddArmy("A",roster,origin) end
	battle.marchDestination=((battle.frame or CFrame.new(destination))*CFrame.new(0,0,if isKing then MapLayout.King.Radius*(20/29) else Config.CampHalfSize-2)).Position
	for i,u in battle.units do
		if moving then continue end
		local slot=roster[i].slot
		local hx,hz=FlockLayout.Home(slot)
		local home=if self.world.ReturnPosition then self.world:ReturnPosition(session,u.petId,slot)
			elseif self.world.HomePosition then self.world:HomePosition(session.plotIndex,slot)
			else self.world:Position(session.plotIndex)+Vector3.new(hx,0,hz)

		local start=(if self.world.PetPosition then self.world:PetPosition(session.plotIndex,u.petId) else nil) or home
		u.x,u.z,u.startX,u.startZ=start.X,start.Z,start.X,start.Z
		u.homeX,u.homeZ=home.X,home.Z
	end

	battle:AddArmy("B",defenders,destination)
	if self.world.root then
		local folder=self.world.root:FindFirstChild("Battles")
		if not folder then folder=Instance.new("Folder");folder.Name="Battles";folder.Parent=self.world.root end
		battle.actors=LiveBattleActors.new(folder,battle)
		for _,u in battle.units do
			local actor=nil
			if u.side=="A" then
				if moving and previous.actors then actor=previous.actors:TakePet(u.petId,"A")
				elseif self.world.TakeActor then actor=self.world:TakeActor(session.plotIndex,u.petId) end
			elseif defender and self.world.TakeActor then actor=self.world:TakeActor(defender.plotIndex,u.petId) end
			if actor then battle.actors:Adopt(u,actor) end
		end
	end
	-- All adopted rigs receive the same departure time and source gate.
	local departure=if moving then previous:DepartureSite() else nil
	for _,u in battle.units do if u.side=="A" and not u.retiring then
		March.Approach(u,battle.destination,now,departure)
	end end
	if moving then
  self:RewardKills(previous,now)
  self:Remove(previous,battle)
 end
	self.battles[battleId]=battle
	session.outgoing,session.armyState=battleId,"Traveling"
	session.stationedAt=nil;session.returnAt=0
	session.awayPets={};for _,u in battle.units do if u.side=="A" and u.petId then session.awayPets[u.petId]=true end end
	session:Touch()
	if campIndex then
  self.campBusy[battle.campKey]=battleId;self.campLocations[battle.campKey]={index=campIndex,plot=session.plotIndex,position=destination,frame=battle.frame,halfSize=Config.CampHalfSize}
  self.world:SetCampBusy(campIndex,true,session.plotIndex)
 elseif outpostIndex then
  self.campBusy[battle.campKey]=battleId
  self.campLocations[battle.campKey]={position=destination,outpost=outpostIndex,frame=battle.frame,halfSize=Config.CampHalfSize}
  self.world:SetOutpostBusy(outpostIndex,true)
 elseif isKing then
  self.campBusy[battle.campKey]=battleId
  self.campLocations[battle.campKey]={position=destination,frame=battle.frame,king=true,halfSize=MapLayout.King.Radius}
  if self.world.kingArena then self.world.kingArena:SetBusy(true,session.name) end
 end
 if battle.campKey then
  self.departingCamps[battle.campKey],self.departingSides[battle.campKey],self.campClearedAt[battle.campKey]=nil,nil,nil
 end
	if defender then
		defender.incoming=battleId
		defender.banner=session.name.." is attacking your base!"
		if defender.armyState=="Home" then defender.armyState="Defending";defender.defending=battleId end
		defender:Touch()
	end
-- State now excludes the deployed squad from HomePets; reserve actors keep their idle targets.
 if self.world.root then
  self.world:UpdateSession(session)
  if defender then self.world:UpdateSession(defender) end
  battle.actors:Sync(now)
  battle.actors:Publish(now)
 end
	return true,if battle.routeGoal then "Marching to "..name..", then onward to "..battle.routeGoalName.."."
		else "Army sent to "..name.."."
end

function BattleService:RewardKills(battle,now)
 for _,kill in battle:DrainKills() do
  if battle.operationId then continue end -- Operations budget only completion rewards.
  local earner=self.sessions[if kill.side=="B" then battle.attacker else battle.defender]
  if not earner or earner.closing or earner.saveLost then continue end
  local opponent=self.sessions[if kill.side=="B" then battle.defender else battle.attacker]
  if (battle.defender==nil and kill.side=="B") or (battle.npcRaid and kill.side=="A") then
   earner.enemyKills=(earner.enemyKills or 0)+1;earner:Touch()
  end
  if battle.incomeSite then continue end
  local rank=if battle.defender and opponent then pvpRank(earner,opponent) else nil
  local amount=killReward(earner,kill,rank,battle.defender==nil)
  if amount<=0 then continue end
  amount=earner:Credit(amount,"battle")
  table.insert(battle.coinDrops,{serial=kill.serial,userId=earner.userId,amount=amount,x=kill.x,z=kill.z,at=now})
  if #battle.coinDrops>40 then table.remove(battle.coinDrops,1) end
 end
end

function BattleService:Finish(battle,outcome,now)
	if battle.paid then return end
 if battle.operationId then return self.operations:Resolve(battle,outcome,now) end
 if battle.incomeJoin then return self:ResolveIncomeJoin(battle,outcome,now) end
 if battle.incomeContest then return self:FinishIncome(battle,outcome,now) end
 self:RewardKills(battle,now)
	local attacker=self.sessions[battle.attacker]
	local defender=self.sessions[battle.defender]
 if outcome=="A" and attacker and not battle.friendlyTerritory then
  if battle.isKing then
   attacker.kingCleared=true
  elseif battle.outpostIndex then
   battle.routeOutposts[battle.outpostIndex]=true
   attacker.frontierWins[battle.outpostIndex]=true
   attacker:UnlockProgress()
  elseif battle.campIndex then
   battle.routeCamps[battle.campIndex]=true
   attacker.firstWins[battle.campIndex]=true
   attacker.tutorial.wonCamp=true
   attacker.campUnlocked=math.max(attacker.campUnlocked,math.min(battle.campCount,battle.campIndex+1))
   attacker:UnlockProgress()
  end
 end
 if outcome=="A" and attacker and battle.campKey then
  self:SetTerritoryOwner(battle.campKey,attacker,self.campLocations[battle.campKey])
 end
	battle.paid=true
	if battle.actors and (outcome == "A" or outcome == "B") then
		for _, actor in battle.actors.actors do
			local model = actor.model
			if model:GetAttribute("Side") == outcome and model:GetAttribute("Defeated") ~= true then
				model:SetAttribute("VictorySerial", (model:GetAttribute("VictorySerial") or 0) + 1)
			end
		end
	end
	local hold=outcome=="A" and (battle.campIndex~=nil or battle.isKing or battle.outpostIndex~=nil or battle.incomeSite) and attacker~=nil
	if hold then battle:Hold(now) else battle:Finish(outcome,now) end
	if not hold then
		battle.routeGoal=nil
		if battle.campKey then self.departingCamps[battle.campKey]=battle.id end
	end
	if attacker and attacker.outgoing==battle.id then
		attacker.armyState,attacker.returnAt=if hold then "Deployed" else "Returning",if hold then 0 else now+Config.ReturnSeconds
		attacker.stationedAt=if hold then battle.name else nil
		attacker.lastResult=if hold and battle.routeGoal then "Conquered! Marching toward "..battle.routeGoalName.."."
			elseif hold then "Conquered! Army stays at "..battle.name..". Approach another camp or change your lineup in My Army."
			elseif outcome=="A" then "Victory at "..battle.name.."!"
			elseif outcome=="B" then "Squad wiped out. Enemy control is recovering; your chickens are returning home."
			elseif outcome=="Draw" then "Draw — all pets are returning."
			else outcome.." — returning home. Kill coins kept."
		attacker:Touch()
	end
	if defender then
		defender.banner=if outcome=="A" then "Base defeated. Your pets and coins are safe."
			elseif outcome=="B" then "Base defended!" else "Raid ended: "..outcome
		if defender.defending==battle.id then
			defender.defending=nil
			defender.armyState,defender.returnAt="Recovering",now+Config.ReturnSeconds
		end
		defender:Touch()
	end
end

function BattleService:ReconcileIncomeReturns(contestId,now)
 local pending={}
 for _,battle in self.battles do if battle.incomeJoin==contestId then table.insert(pending,battle) end end
 for _,battle in pending do
  local owner=self.campOwners["income:1"]
  local session=self.sessions[battle.attacker]
  battle.incomeJoin=nil;battle.beforeIncomeArrival=nil
  battle.incomeContest=false;battle.rosterLocked=false
  for _,unit in battle.units do if unit.hp<=0 then unit.respawnAt=unit.respawnAt or now+Config.AttackerRespawnSeconds*(unit.recoveryMultiplier or 1) end end
  if session and owner and owner.userId==session.userId then
   battle.friendlyTerritory=true;battle.captureElapsed=Config.CaptureSeconds
   self:ReserveIncome(battle)
   session.lastResult="Outpost defended. Your army is continuing to station there.";session:Touch()
  else
   battle.paid=true;battle.incomeDeparture=true;battle:Finish("Too late",now)
   if session then
    session.armyState,session.returnAt="Returning",now+Config.ReturnSeconds
    session.lastResult="The outpost changed hands. Your army is returning home.";session:Touch()
   end
  end
 end
end

function BattleService:ResolveIncomeJoin(join,outcome,now)
 local session=self.sessions[join.attacker]
 local owner=self.campOwners["income:1"]
 local contest=self.battles[join.incomeJoin]
 if outcome=="Join" and session and owner and owner.userId==session.userId and contest and not contest.paid and not contest.defender then
  contest.defender=session.userId
  contest.committedUsers[session.userId]=true
  TerritoryContest.AddPlayer(contest,session,self.world,now,"B",join,true)
  TerritoryContest.Lock(contest)
  self:Remove(join,contest,"B")
  self:ReserveIncome(contest)
  TerritoryContest.Assign(session,contest,"B",if contest.incomeActiveAt then "Fighting" else "Deployed")
  if contest.phase=="Capture" and contest:Alive("B")>0 then contest.phase,contest.phaseAt,contest.capturers="Fight",now,0 end
  session.lastResult="Your army arrived to defend the outpost.";session:Touch()
  return
 end
 if outcome=="Join" and session and owner and owner.userId==session.userId and not contest then
  join.incomeJoin=nil;join.beforeIncomeArrival=nil;join.incomeContest=false;join.rosterLocked=false
  join.friendlyTerritory=true;join.captureElapsed=Config.CaptureSeconds
  for _,unit in join.units do if unit.hp<=0 then unit.respawnAt=unit.respawnAt or now+Config.AttackerRespawnSeconds*(unit.recoveryMultiplier or 1) end end
  self:ReserveIncome(join);self:Finish(join,"A",now)
  return
 end
 join.incomeJoin=nil;join.beforeIncomeArrival=nil;join.incomeContest=false;join.rosterLocked=false;join.paid=true
 for _,unit in join.units do if unit.hp<=0 then unit.respawnAt=unit.respawnAt or now+Config.AttackerRespawnSeconds*(unit.recoveryMultiplier or 1) end end
 join.incomeDeparture=true;join:Finish(outcome,now)
 if session then
  session.armyState,session.returnAt="Returning",now+Config.ReturnSeconds
  session.lastResult="Defense ended before arrival. Your army is returning home.";session:Touch()
 end
end

function BattleService:FinishIncome(battle,outcome,now)
 if battle.paid then return end
 if battle.npcRaid and not battle.incomeActiveAt then self:CancelIncomeApproach(now);return end
 battle.paid=true;battle.rosterLocked=false;battle:DrainKills()
 local activeAt=battle.incomeActiveAt
 local state,config=self.income,Config.IncomeOutpost
 local attacker,defender=self.sessions[battle.attacker],self.sessions[battle.defender]
 local owner=self.campOwners["income:1"]
 if outcome=="A" then
  self:SetTerritoryOwner("income:1",attacker,{income=true,position=battle.destination,frame=self.world:IncomeFrame(),halfSize=Config.CampHalfSize})
  owner=self.campOwners["income:1"]
 end
 local protected=outcome=="A" or (battle.incomeActiveAt and (outcome=="B" or outcome=="Draw"))
 if protected then state.graceUntil=now+config.GraceSeconds end
 if attacker and battle.incumbent~=attacker.userId then state.retry[attacker.userId]=now+config.RetrySeconds end
 state.contestId=nil;state.raidId=nil;state.warningUntil=nil;state.eligibleTime=0
 state.warningAfter=if state.warnedOnce then config.RepeatAfter else config.WarningAfter
 state.clockOwner=owner and owner.userId
 local continuations={}
 for _,participant in {{session=attacker,side="A"},{session=defender,side="B"}} do
  local session=participant.session
  if not session or session.outgoing~=battle.id then continue end
  local holding=owner~=nil and owner.userId==session.userId and not session.closing and not session.saveLost
  local nextBattle=TerritoryContest.Continue(battle,session,participant.side,self.world,now,holding)
  nextBattle.incomeDeparture=not holding
  self.battles[nextBattle.id]=nextBattle;continuations[participant.side]=nextBattle
  session.lastResult=if holding then "Supply Outpost secured · +"..config.Rate.." coins/sec. Swap chickens anytime in My Army."
   elseif outcome=="A" then "Outpost lost. Your chickens recover at home."
   else "Contest ended. Your chickens are returning home."
  session:Touch()
 end
 -- Remap each old physical reservation to the participant that actually stood
 -- there. The site itself follows its new holder, or both departures below.
 for key,id in self.campBusy do if id==battle.id and key~="income:1" then
  local nextBattle=continuations[self.departingSides[key] or "A"]
  if nextBattle then self.campBusy[key]=nextBattle.id;self.departingCamps[key]=nextBattle.id;self.departingSides[key]="A"
  else self:ReleaseCamp(key) end
 end end
 local siteSuccessor
 for _,nextBattle in continuations do if nextBattle.phase=="Holding" then siteSuccessor=nextBattle;break end end
 if not siteSuccessor then siteSuccessor=continuations.A or continuations.B end
 if siteSuccessor then
  self:ReserveIncome(siteSuccessor)
  if siteSuccessor.phase~="Holding" then self.departingCamps["income:1"]=siteSuccessor.id;self.departingSides["income:1"]="A" end
 end
 if battle.npcRaid then
  -- Raiders walk back out. Their dead NPCs do not revive and own no saved flock.
  local survivors={};for _,unit in battle.units do if unit.side=="A" and unit.hp>0 then table.insert(survivors,unit) end end
  battle.units=survivors;battle.incomeContest=false;battle.beforeIncomeArrival=nil;battle.incomeActiveAt=nil
  battle.incomeDeparture=true;battle:Finish("Raid ended",now)
  if not siteSuccessor then self:ReserveIncome(battle);self.departingCamps["income:1"]=battle.id;self.departingSides["income:1"]="A" end
 else self:Remove(battle) end
 if self.telemetry then
  self:RecordIncomeContest("TerritoryContestResolved",battle,now,outcome,activeAt)
  if outcome=="A" then self.telemetry:Record("TerritoryCaptured",{userId=attacker and attacker.userId,rate=if attacker then config.Rate else 0,
   kind=if battle.npcRaid then "NPC" elseif battle.incumbent then "Player" else "Neutral"},"capture:"..battle.id) end
 end
 self:ReconcileIncomeReturns(battle.id,now)
 if self.world.root then for _,participant in {attacker,defender} do if participant then self.world:UpdateSession(participant) end end end
end

-- Player birds can still be crossing a camp after its original holder moves or
-- disconnects. Hidden casualties and neutral NPCs are not physical occupants.
function BattleService:CampOccupant(location,excludedBattle)
 if not location or not location.position then return nil end
 for _,battle in self.battles do
  if battle==excludedBattle then continue end
  for _,unit in battle.units do
   local player=if unit.side=="A" then battle.attacker else battle.defender
   if not unit.petId or unit.hp<=0 or not self.sessions[player] then continue end
   if MapLayout.Contains(location,unit.x,unit.z,unit.size*1.35+1) then
    return battle,unit.side
   end
  end
 end
 return nil
end

function BattleService:ReleaseCamp(key)
 -- Release only the army reservation. WorldService keeps a claimed site empty
 -- while its owner flag remains, regardless of where that army goes next.
 local location=self.campLocations[key]
 if location and location.index and not self.campOwners[key] then
  for _,battle in self.battles do
   if battle.plotIndex==location.plot and battle.routeCamps then battle.routeCamps[location.index]=nil end
  end
 end
 self.campBusy[key],self.departingCamps[key],self.departingSides[key],self.campClearedAt[key]=nil,nil,nil,nil
 if location then
  if location.income then if self.world.SetIncomeBusy then self.world:SetIncomeBusy(false) end
  elseif location.king then if self.world.kingArena then self.world.kingArena:SetBusy(false) end
  elseif location.outpost then self.world:SetOutpostBusy(location.outpost,false)
  else self.world:SetCampBusy(location.index,false,location.plot) end
 end
 self.campLocations[key]=nil
end

function BattleService:Remove(battle,successor,successorSide)
 if battle.operationId and self.operations then self.operations:Detach(battle) end
 -- Occupied ground follows the moving squad until every rig clears its old bay.
 for key,owner in self.campBusy do if owner==battle.id then
  if successor then self.campBusy[key]=successor.id;self.departingCamps[key]=successor.id;self.departingSides[key]=successorSide or "A";self.campClearedAt[key]=nil
  elseif key~="income:1" then
   local occupant,side=self:CampOccupant(self.campLocations[key],battle)
   -- If no battle remains, keep the reservation ID until the normal vacancy
   -- check confirms a full grace period. Removal must not bypass that check.
   local reservation=if occupant then occupant.id else battle.id
   self.campBusy[key],self.departingCamps[key]=reservation,reservation
   self.departingSides[key]=side or "A";self.campClearedAt[key]=nil
  else
   local departure
   if key=="income:1" then for _,other in self.battles do
    if other~=battle and other.incomeDeparture and other.phase=="Returning" then departure=other;break end
   end end
   if departure then self.campBusy[key]=departure.id;self.departingCamps[key]=departure.id;self.departingSides[key]="A"
   else self:ReleaseCamp(key) end
  end
 end end
 local defender=self.sessions[battle.defender]
 if defender and defender.incoming==battle.id then defender.incoming=nil;defender:Touch() end
 battle:Destroy()
 self.battles[battle.id]=nil
end

function BattleService:ReleaseClearedCamps(now)
 for key,id in self.departingCamps do
  local battle=self.battles[id]
  local location=self.campLocations[key]
  -- A new order alone cannot release ground. Its army must first physically
  -- arrive; redirecting again while en route restarts this arrival boundary.
  local awaitingArrival=battle and battle.phase=="Travel" and not battle.arrivedAt
  if awaitingArrival and not self.territoryReclaims[key] then self.campClearedAt[key]=nil;continue end
  local clear=true
  if key=="income:1" then
   local occupants={}
   if battle then table.insert(occupants,battle) end
   for _,other in self.battles do if other~=battle and other.incomeDeparture then table.insert(occupants,other) end end
   if location then for _,occupant in occupants do for _,u in occupant.units do if u.side==(self.departingSides[key] or "A") then
    if MapLayout.Contains(location,u.x,u.z,u.size*1.35+1) then clear=false;break end
   end end end end
  else
   clear=self:CampOccupant(location)==nil
  end
  if not clear then self.campClearedAt[key]=nil
  elseif self.campBusy[key]==id then
   self.campClearedAt[key]=self.campClearedAt[key] or now
   if now-self.campClearedAt[key]>=Config.CampRespawnGrace then self:ReleaseCamp(key) end
  end
 end
end

function BattleService:Step(dt,now)
 self:StepIncome(dt,now)
 self:StepTerritoryReclaims(dt,now)
 local expired={}
 for _,battle in self.battles do
  if battle.phase=="Returning" then
   battle:Step(dt,now)
   if battle:Returned(now) or now-battle.phaseAt>=Config.ReturnTimeout then table.insert(expired,battle) end
  end
 end
 for _,battle in expired do
  local session=self.sessions[battle.attacker]
  if session and session.outgoing==battle.id then
   session.returnAt=now
   if not battle:Returned(now) then session.banner="The route was blocked. Your squad recovered at the yard." end
  end
  if session and battle:Returned(now) and battle.actors and self.world.RestoreActor then
   for _,u in battle.units do if u.side=="A" and u.petId then
    local actor=battle.actors:TakePet(u.petId,"A")
    if actor then self.world:RestoreActor(session,u.petId,actor) end
   end end
  end
  self:Remove(battle)
 end
 -- Physical homecoming precedes capture resolution. A traveling rig cannot defend remotely.
 for _,session in self.sessions do
  local outgoing=self.battles[session.outgoing]
  if session.returnAt>0 and now>=session.returnAt and not outgoing then
			session.returnAt,session.outgoing,session.armyState=0,nil,"Home"
			session.awayPets={}
   session:RefreshArmy();session.tutorial.returned=true
   session.lastResult="Army home. Your chickens have rejoined the flock."
   local incoming=self.battles[session.incoming]
   if incoming and (incoming.phase=="Travel" or incoming.phase=="Capture") then
    incoming:AddDefenders(session:Lineup(),self.world:Position(session.plotIndex),now)
    session.armyState,session.defending="Defending",incoming.id
    if incoming.actors and self.world.TakeActor then
     for _,unit in incoming.units do if unit.side=="B" and unit.petId and not incoming.actors.actors[unit.id] then
      local actor=self.world:TakeActor(session.plotIndex,unit.petId)
      if actor then incoming.actors:Adopt(unit,actor) end
     end end
    end
    session.banner="Your army returned in time to defend!"
   end
   session:Touch()
  end
 end
	local advance={}
	local active={};for _,battle in self.battles do table.insert(active,battle) end
	for _,battle in active do
  if self.battles[battle.id]~=battle then continue end
		-- Reconcile both player sides. Emptying the lineup withdraws its real rigs.
		for _,userId in {battle.attacker,battle.defender} do
			local owner=self.sessions[userId]
			if owner and owner.outgoing==battle.id then
				Reinforcements.Sync(owner,battle,self.world,now)
				if battle.phase~="Returning" and #owner:BestPetIds()==0 then self:ReturnHome(owner,now) end
			end
		end
		for _,side in {"A","B"} do
			local owner=self.sessions[if side=="A" then battle.attacker else battle.defender]
			battle:ApplyResearch(side,owner and owner.researchEffects,owner and os.time()<(owner.rallyActiveUntil or 0))
		end
		local outcome=if battle.phase=="Returning" then nil else battle:Step(dt,now)
  self:RewardKills(battle,now)
		local attacker=self.sessions[battle.attacker]
		if attacker and attacker.outgoing==battle.id and (battle.phase=="Fight" or battle.phase=="Capture") and attacker.armyState~="Fighting" then
			attacker.armyState="Fighting";attacker:Touch()
		end
  if battle.incomeContest and battle.defender and (battle.phase=="Fight" or battle.phase=="Capture") then
   local defender=self.sessions[battle.defender]
   if defender and defender.outgoing==battle.id and defender.armyState~="Fighting" then defender.armyState="Fighting";defender:Touch() end
  end
		if outcome then self:Finish(battle,outcome,now) end
		if battle.phase=="Holding" and battle.routeGoal and now-battle.phaseAt>=Config.RouteRegroupSeconds then
			table.insert(advance,battle)
		end
	end
	self:ReleaseClearedCamps(now)
	-- Start the next encounter after iteration; never mutate the active battle set mid-loop.
	for _,battle in advance do
		local session=self.sessions[battle.attacker]
		if session and session.outgoing==battle.id then
			local goal=battle.routeGoal
			battle.routeGoal=nil
   local ok,why=self:Attack(session,goal,now,true)
			if not ok then session.lastResult="Route stopped. "..why.." Your army is staying here.";session:Touch() end
		end
	end
 if incomeEnabled() and self.world.SetIncomeStatus then self.world:SetIncomeStatus(self:IncomeSummary(nil,now)) end
end

function BattleService:ReturnHome(session,now)
	local battle=self.battles[session.outgoing]
	if not battle or battle.phase=="Returning" then return false,"Your army is already home or returning." end
	if battle.operationId then self.operations:Resolve(battle,"Abandoned",now);return true,"Operation ended. Your army is home." end
 if battle.incomeContest and battle.defender==session.userId then
  local continuation=TerritoryContest.Continue(battle,session,"B",self.world,now,false)
  continuation.incomeDeparture=true;self.battles[continuation.id]=continuation
  for key,id in self.campBusy do
   if key~="income:1" and id==battle.id and self.departingSides[key]=="B" then
    self.campBusy[key]=continuation.id;self.departingCamps[key]=continuation.id
    self.departingSides[key]="A";self.campClearedAt[key]=nil
   end
  end
  battle.defender=nil
  session.lastResult="Army returning home. The challenger can still capture the outpost.";session:Touch()
  return true,"Army returning home."
 end
	battle.routeGoal=nil
	if battle.phase=="Holding" then
		battle:Finish("Recall",now)
		self.departingCamps[battle.campKey]=battle.id
  self.departingSides[battle.campKey]="A"
  if battle.incomeSite then battle.incomeDeparture=true end
		session.armyState,session.returnAt,session.stationedAt="Returning",now+Config.ReturnSeconds,nil
		session:Touch()
	else self:Finish(battle,"Retreat",now) end
	return true,"Army returning home."
end

-- A HUD recall withdraws only this army through the existing encounter rules.
-- Transfer its real actors before destroying its returning encounter; rivals stay intact.
function BattleService:RecallForCommand(session,now,keepSelectedPositions)
	local battle=self.battles[session.outgoing]
	if session.defending and not battle then return false,"Your army is defending. Try again when it is ready." end
	if battle and battle.phase~="Returning" then
		local ok,why=self:ReturnHome(session,now)
		if not ok then return false,why end
		battle=self.battles[session.outgoing] -- Territory defense can create a separate return encounter.
	end
	if battle and (battle.attacker~=session.userId or battle.phase~="Returning") then
		return false,"Your army is still resolving its battle."
	end
	local selected={}
	if keepSelectedPositions then for _,id in session:BestPetIds() do selected[id]=true end end
	if battle then
		if battle.actors then for _,unit in battle.units do
			if unit.side~="A" or not unit.petId then continue end
			local actor=battle.actors:TakeUnit(unit.id)
			if actor then
				if not selected[unit.petId] then actor:Teleport(self.world:ReturnPosition(session,unit.petId)) end
				self.world:RestoreActor(session,unit.petId,actor)
			end
		end end
		self:Remove(battle)
	end
	session.outgoing,session.stationedAt,session.returnAt,session.armyState=nil,nil,0,"Home"
	session.awayPets={}
	session:RefreshArmy();session:Touch()
	return true
end

function BattleService:CancelPlayer(userId,now)
	-- Resolve only this participant. The other territory army must retain its
	-- live continuation rather than being destroyed as a cancelled home raid.
 local territory={}
 for _,battle in self.battles do if battle.incomeSite and (battle.attacker==userId or battle.defender==userId) then table.insert(territory,battle) end end
 for _,battle in territory do
  if self.battles[battle.id]~=battle then continue end
  if battle.incomeContest and not battle.incomeJoin and not battle.paid then
   if battle.defender==userId then self:ReturnHome(self.sessions[userId],now)
   else self:FinishIncome(battle,"Cancelled",now) end
  end
 end
	local ownTerritory={}
 for _,battle in self.battles do if battle.incomeSite and battle.attacker==userId then table.insert(ownTerritory,battle) end end
 for _,battle in ownTerritory do self:Remove(battle) end
 local departing=self.sessions[userId]
 if #ownTerritory>0 and departing then
  departing.outgoing=nil;departing.awayPets={};departing.returnAt=now+Config.ReturnSeconds;departing.armyState="Recovering";departing:Touch()
 end
	local remove={}
	for _,battle in self.battles do
		if battle.incomeSite then continue end
		if battle.attacker==userId or battle.defender==userId then
			if battle.phase=="Holding" then self:ReturnHome(self.sessions[battle.attacker],now)
			else self:Finish(battle,"Cancelled",now) end
			table.insert(remove,battle)
		end
	end
	for _,battle in remove do
  self:Remove(battle)
  local attacker=self.sessions[battle.attacker]
  if attacker and attacker.outgoing==battle.id then attacker.outgoing=nil;attacker.awayPets={};attacker.returnAt=now+Config.ReturnSeconds;attacker.armyState="Recovering";attacker:Touch() end
 end
 -- Departure/reset also clears this player's remaining server-session ownership.
 local released={}
 for key,owner in self.campOwners do if owner.userId==userId then table.insert(released,key) end end
 for _,key in released do self:SetTerritoryOwner(key,nil) end
 for key,reclaim in self.territoryReclaims do if reclaim.ownerId==userId then self.territoryReclaims[key]=nil end end
 if self.income.clockOwner==userId or (self.campOwners["income:1"]==nil and self.income.raidId) then self:CancelIncomeApproach(now);self.income.clockOwner=nil end
 self.income.retry[userId]=nil
 if self.income.lostOwners then self.income.lostOwners[userId]=nil end
 if self.income.receipts then self.income.receipts[userId]=nil end
 self.territoryIncome:Release(userId)
end

function BattleService:Snapshots(now)
	local result={}
	local byId={}
	for _,battle in self.battles do
  local snapshot=battle:Snapshot(now);table.insert(result,snapshot);byId[battle.id]=snapshot
 end
 for _,reclaim in self.territoryReclaims do
  local snapshot=byId[reclaim.battleId]
  if not snapshot or snapshot.phase=="Returning" then
   if snapshot then snapshot.enemyReclaiming=false end
   snapshot={id=reclaim.id,territoryReclaim=true,target=reclaim.target,units={},
    name=reclaim.name,x=reclaim.location.position.X,z=reclaim.location.position.Z,captureRadius=Config.CaptureRadius}
   table.insert(result,snapshot)
  end
  snapshot.enemyReclaiming,snapshot.enemyReclaimComplete=true,reclaim.captureElapsed==0
  snapshot.reclaimReason="Unclaimed · enemies taking back the base"
  snapshot.enemyControl=1-reclaim.captureElapsed/Config.CaptureSeconds
  snapshot.playerControl=reclaim.captureElapsed/Config.CaptureSeconds
 end
	return result
end

function BattleService:Destroy()
 for _,battle in self.battles do battle:Destroy() end
	self.battles,self.campBusy,self.campOwners,self.departingCamps,self.departingSides,self.campClearedAt={},{},{},{},{},{}
 self.territoryIncome:Destroy()
 self.territoryReclaims={}
end

return BattleService
