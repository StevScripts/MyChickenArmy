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
local RebirthService=require(script.Parent.RebirthService)
local CampaignRoute=require(Shared.CampaignRoute)
local March=require(Shared.ArmyMarch)
local MapLayout=require(Shared.MapLayout)
local Reinforcements=require(script.Parent.ArmyReinforcements)
local TerritoryContest=require(script.Parent.TerritoryContest)
local TerritoryIncome=require(script.Parent.TerritoryIncome)
local TutorialService=require(script.Parent.TutorialService)
local BattleService={}
-- A captured main-route camp or King keeps its flag, but the army only lingers
-- for the victory moment, then marches home where its chickens lay eggs again.
local VICTORY_LINGER_SECONDS=5
local FUNNEL_FAILURE_LIMIT=20
-- Saved "beaten once" records for other commanders' lanes (PlayerSession.laneCamps).
local LANE_WIN_LIMIT=100
BattleService.__index=BattleService

-- Re-enlist enemy scaling (docs/team/launch). A lane's camps use its owner's rank;
-- the King uses the attacker's. EnemyScale is 1 at rank 0, leaving rosters untouched.
local function enemyScale(owner): number
 return if owner then RebirthService.EnemyScale(owner.rebirths or 0) else 1
end
local function scaledRoster(roster,scale: number)
 if scale==1 then return roster end
 local result={}
 for i,pet in roster do
  local unit=table.clone(pet)
  local stats=table.clone(pet.combatStats or Rules.Stats(pet.species,pet.stars or 1,pet.level))
  stats.hp*=scale;stats.damage*=scale
  unit.combatStats=stats
  result[i]=unit
 end
 return result
end
-- Rules.Power reads species stats, so scaled odds multiply it (hp and damage both scale).
local function scaledPower(roster,scale: number): number
 return math.floor(Rules.Power(roster)*scale)
end
BattleService.EnemyScale=enemyScale

function BattleService.new(sessions,world)
	return setmetatable({sessions=sessions,world=world,battles={},campBusy={},campOwners={},releasedTerritories={},departingCamps={},departingSides={},campClearedAt={},campLocations={},funnelFailures={},leftProgress={},
  territoryIncome=TerritoryIncome.new((Config.IncomeOutpost and Config.IncomeOutpost.Rate) or 0),
  income={graceUntil=0,retry={},eligibleTime=0,warningAfter=(Config.IncomeOutpost and Config.IncomeOutpost.WarningAfter) or 120}},BattleService)
end

local function pvpRank(attacker,defender)
 return math.min(attacker.promotion or 1,defender.promotion or 1)
end

-- The battle identity (not presence of its defender session) excludes PvP.
local function killReward(session,unit,rank,isNpc)
 -- Full King bounty once: saved kingCleared, or a boss kill earlier this visit.
 local repeatBoss=isNpc and unit.boss==true and (session.kingCleared==true or session.kingBountyPaid==true)
 local amount=CombatRewards.ForUnit(unit,rank,repeatBoss)
 if isNpc and not unit.boss and session.entitlements and session.entitlements.DoubleBounty==true then
  amount*=ShopCatalog.BountyMultiplier
 end
 if isNpc then amount=math.floor(amount*(1+(session.researchEffects and session.researchEffects.bounty or 0))) end
 return amount
end

local function campKey(plot,index) return tostring(plot)..":"..tostring(index) end
local function armyCenter(battle)
 local x,z,count=0,0,0
 for _,u in battle.units do if u.side=="A" and u.hp>0 then x+=u.x;z+=u.z;count+=1 end end
 return if count>0 then Vector3.new(x/count,battle.destination.Y,z/count) else battle.destination
end
function BattleService:CampPosition(index,plot)
 if self.world.CampPosition then return self.world:CampPosition(index,plot) end
 local p=Config.Camps[index].position;return Vector3.new(p[1],1,p[2])
end

-- Camp index and lane plot for a camp order ("camp:N" is the commander's own lane).
function BattleService:CampTarget(session,target)
 local index,plot=CampaignRoute.Camp(target)
 if not index then return nil,nil end
 return index,plot or session.plotIndex
end

-- The commander whose home owns a lane. Open plots have no garrison to fight.
function BattleService:LaneOwner(plot)
 for _,other in self.sessions do
  if other.plotIndex==plot and not other.closing then return other end
 end
 return nil
end

function BattleService:TerritoryKey(session,target)
 local index,plot=self:CampTarget(session,target)
 return if index then campKey(plot,index) else target
end

-- Another commander's camps carry their name: "Stev's Cluck Camp".
function BattleService:TargetName(session,target)
 local index,plot=self:CampTarget(session,target)
 if not index or plot==session.plotIndex then return CampaignRoute.Name(target) end
 local owner=self:LaneOwner(plot)
 return (if owner then owner.name.."'s " else "")..CampaignRoute.Name(target)
end

-- A victorious, recalled, retreating or defeated squad can turn around on its way
-- home. After a wipe the fallen keep their respawn timers and rejoin from home.
local TURN_AROUND={A=true,Recall=true,Retreat=true,B=true}
function BattleService:CanTurnAround(battle)
 return battle.phase=="Returning" and TURN_AROUND[battle.outcome or ""]==true
  and not battle.incomeSite and not battle.incomeDeparture and (battle.outcome=="B" or battle:Alive("A")>0)
end

-- Only this player's outgoing NPC encounter can be redirected. Shared income
-- contests retain their separate participant/withdrawal rules.
function BattleService:CanRedirect(session,battle)
 if battle==nil or battle.attacker~=session.userId or battle.defender then return false end
 -- October 15: a Mission in progress can be left for another target (it is forfeited).
 if battle.operationId and not battle.paid then
  return battle.phase=="Travel" or battle.phase=="Fight" or battle.phase=="Capture"
 end
 if battle.phase=="Returning" then return self:CanTurnAround(battle) end
 return (not battle.incomeSite or battle.phase=="Holding")
  and (battle.phase=="Travel" or battle.phase=="Fight" or battle.phase=="Capture" or battle.phase=="Holding")
end

-- A defeated squad may retry the camp it just lost; its guards start fresh.
function BattleService:TerritoryBlocked(key,previous)
 local reserved=self.campBusy[key]
 return reserved~=nil and not (previous and reserved==previous.id
  and self.departingCamps[key]==previous.id and (key~=previous.campKey or previous.outcome=="B"))
end

-- Camps go in any order (Mini War style). Only an unopened King still marches
-- through the commander's own unbeaten camps first.
function BattleService:PlanOrder(session,target,camps,outposts)
 local options={kingOpen=self:KingOpen(session),lanes={}}
 local index,plot=self:CampTarget(session,target)
 if index and plot~=session.plotIndex then options.lanes[plot]=self:LaneCleared(session,plot) end
 return CampaignRoute.Plan(self:OrderId(session,target),camps,outposts,options)
end

-- "camp:P:N" naming the commander's own plot is the plain "camp:N".
function BattleService:OrderId(session,target)
 local index,plot=self:CampTarget(session,target)
 return if index then CampaignRoute.CampId(index,plot,session.plotIndex) else target
end

local function laneBit(index) return 2^(index-1) end

-- Camps beaten at least once on a lane: the own lane reads firstWins, another
-- commander's lane reads laneCamps (a bit per camp) by that commander's id.
-- Current holds and this forward push count too. Nil means nobody owns the lane.
function BattleService:LaneCleared(session,plot)
 local cleared={}
 local count=#Progression.Camps(1)
 if plot==session.plotIndex then
  for i=1,count do if session.firstWins[i] then cleared[i]=true end end
 else
  local owner=self:LaneOwner(plot)
  if not owner or owner==session then return nil end
  local mask=session.laneCamps and session.laneCamps[tostring(owner.userId)] or 0
  for i=1,count do if bit32.btest(mask,laneBit(i)) then cleared[i]=true end end
 end
 for i=1,count do
  local holder=self.campOwners[campKey(plot,i)]
  if holder and holder.userId==session.userId then cleared[i]=true end
 end
 local active=self.battles[session.outgoing]
 if active and active.phase~="Returning" and active.routeCamps and active.plotIndex==plot and (active.campIndex or active.isKing) then
  local frontier=if active.isKing then count else active.campIndex
  for i=1,frontier do if active.routeCamps[i] then cleared[i]=true end end
 end
 return cleared
end

function BattleService:RouteProgress(session)
 local outposts={}
 for i=1,#Progression.Outposts() do
  local owner=self.campOwners["outpost:"..i]
  if owner and owner.userId==session.userId then outposts[i]=true end
 end
 return self:LaneCleared(session,session.plotIndex),outposts
end

-- Beating all camps of any one lane, in any order, opens the King for good.
-- Earlier King clears and a fully won home lane keep it open.
function BattleService:KingOpen(session)
 if session.kingCleared then return true end
 local count=#Progression.Camps(1)
 local home=true
 for i=1,count do if not session.firstWins[i] then home=false;break end end
 if home then return true end
 local full=2^count-1
 for _,mask in session.laneCamps or {} do if bit32.band(mask,full)==full then return true end end
 return false
end

function BattleService:RecordLaneWin(session,ownerId,index)
 session.laneCamps=session.laneCamps or {}
 local key=tostring(ownerId)
 local mask=session.laneCamps[key] or 0
 if bit32.btest(mask,laneBit(index)) then return end
 if mask==0 then
  -- Bounded save: forget the lane with the fewest beaten camps.
  local entries,weakest,weakestCount=0,nil,math.huge
  for id,value in session.laneCamps do
   entries+=1
   local beaten=0;for i=1,#Progression.Camps(1) do if bit32.btest(value,laneBit(i)) then beaten+=1 end end
   if beaten<weakestCount then weakest,weakestCount=id,beaten end
  end
  if entries>=LANE_WIN_LIMIT and weakest then session.laneCamps[weakest]=nil end
 end
 session.laneCamps[key]=bit32.bor(mask,laneBit(index))
 session:Touch()
end

-- New commanders take their own Cluck Camp before anything else (the tutorial).
function BattleService:Started(session)
 if session.kingCleared or (session.tutorial and session.tutorial.wonCamp) then return true end
 for _,won in session.firstWins do if won then return true end end
 return next(session.laneCamps or {})~=nil
end

-- Territory limit (Config.Territories.HoldLimit, raised by research holdCap).
-- Camps, the King and held mission territories count; the Hill does not.
function BattleService:HoldCount(session)
 local count=if self.operations then self.operations:HoldCount(session.userId) else 0
 for key,owner in self.campOwners do
  if owner.userId==session.userId and key~="income:1" then count+=1 end
 end
 return count
end

function BattleService:HoldLimit(session)
 local research=session.researchEffects and session.researchEffects.holdCap or 0
 return math.max(Config.Territories.HoldLimit,research)
end

-- Egg value bonus a held territory gives: Camp 1/2/3 by index, King at the top.
function BattleService:HoldBonus(key)
 local bonuses=Config.Territories
 if key==KingEncounter.Target then return bonuses.KingBonus end
 local index=tonumber(key:match("^%d+:(%d+)$"))
 return index and bonuses.CampBonus[index] or 0
end

-- Recomputed every step; a territory under live attack pays ContestedShare.
function BattleService:RefreshTerritoryBonus()
 local totals={}
 for key,owner in self.campOwners do
  local bonus=self:HoldBonus(key)
  if bonus<=0 then continue end
  local battle=self.battles[self.campBusy[key]]
  local contested=battle~=nil and battle.attacker~=owner.userId and not battle.paid
   and (battle.phase=="Fight" or battle.phase=="Capture")
  totals[owner.userId]=(totals[owner.userId] or 0)+bonus*(if contested then Config.Territories.ContestedShare else 1)
 end
 if self.operations then
  for userId,bonus in self.operations:HoldBonuses() do totals[userId]=(totals[userId] or 0)+bonus end
 end
 for userId,session in self.sessions do
  local total=math.floor((totals[userId] or 0)*1000+0.5)/1000
  if session.territoryBonus~=total then session.territoryBonus=total;session:Touch() end
 end
end

function BattleService:SetTerritoryOwner(key,session,location)
 local previous=self.campOwners[key]
 if session then self.releasedTerritories[key]=nil end
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
-- command restores its native garrison; existing combat/kill/recruit rules apply.
function BattleService:Unclaim(session,targetId,now)
 if type(targetId)~="string" or #targetId>60 then return false,"Invalid territory." end
 local kind,index=targetId:match("^(%a+):(%d+)$")
 index=tonumber(index)
 local isCamp=self:CampTarget(session,targetId)~=nil
 if not isCamp and (not index or (kind~="outpost" and targetId~=KingEncounter.Target)) then return false,"Invalid territory." end
 local key=self:TerritoryKey(session,targetId)
 local owner=self.campOwners[key]
 if not owner or owner.userId~=session.userId then return false,"You do not own this base." end
 local location=owner.location or self.campLocations[key]
 if not location then return false,"This base is unavailable." end
 local battle=self.battles[self.campBusy[key]]
 local active=battle and battle.campKey==key and battle.phase~="Returning"
 -- The footage restores the native flag immediately. This record only allows
 -- vacancy release before the departing army reaches its next destination.
 self.releasedTerritories[key]=session.userId
 self:SetTerritoryOwner(key,nil,location)
 if location.index then
  for _,other in self.battles do
   if other.plotIndex==location.plot and other.routeCamps then other.routeCamps[location.index]=nil end
  end
 end
 if active and battle.attacker==session.userId and (battle.phase=="Holding" or battle.friendlyTerritory) then
  -- Unclaim does not recall/heal/replace the player's squad. A fresh garrison
  -- fights those same units, which can win the territory back themselves.
  -- October 20 (Rebirth v2): camps scale by the attacker's rank, like the King.
  local roster=if location.king then KingEncounter.Definition(battle.promotion,enemyScale(session)).roster
   elseif location.outpost then Progression.OutpostRoster(location.outpost)
   else scaledRoster(Progression.Roster(battle.lanePromotion or battle.promotion,location.index),enemyScale(session))
  battle:CancelAttacks()
  battle.paid,battle.friendlyTerritory,battle.outcome=false,false,nil
  battle.phase=if battle.phase=="Travel" then "Travel" else "Fight"
  battle.phaseAt,battle.captureStarted,battle.captureElapsed,battle.capturers=now,false,0,0
  battle.routeGoal=nil
  battle:AddArmy("B",roster,battle.destination)
  if battle.actors then battle.actors:Sync(now);battle.actors:Publish(now) end
  session.armyState,session.stationedAt=if battle.phase=="Travel" then "Traveling" else "Fighting",nil
 end
 session:Touch()
 return true,"Base unclaimed. Defeat its defenders to conquer it again."
end

function BattleService:Targets(session,now)
	local targets={}
 local previous=self.battles[session.outgoing]
 local canMove=self:CanRedirect(session,previous) or ((not session:IsArmyLocked() or session.armyState=="Following") and not session.outgoing)
 local routeCamps,routeOutposts=self:RouteProgress(session)
 local camps=Progression.Camps(session.promotion)
 local started=self:Started(session)
 local held,holdLimit=self:HoldCount(session),self:HoldLimit(session)
 -- The own lane first, then every other commander's lane (open plots have no garrison).
 local lanes={session}
 for _,other in self.sessions do
  if other~=session and other.plotIndex and not other.closing then table.insert(lanes,other) end
 end
 table.sort(lanes,function(a,b)
  if (a==session)~=(b==session) then return a==session end
  return a.plotIndex<b.plotIndex
 end)
 local lanePromotion={}
 for _,owner in lanes do
  local promotion=owner.promotion or 1
  for i,camp in Progression.Camps(promotion) do
   local id=CampaignRoute.CampId(i,owner.plotIndex,session.plotIndex)
   lanePromotion[id]=promotion
   table.insert(targets,{id=id,name=self:TargetName(session,id),kind="Camp",holdBonus=self:HoldBonus(campKey(owner.plotIndex,i)),
    power=scaledPower(Progression.Roster(promotion,i),enemyScale(owner)),count=#camp.roster,
    lanePlot=owner.plotIndex,laneOwnerId=owner.userId,laneOwnerName=if owner==session then nil else owner.name,
    available=false,reason="Ready"})
  end
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
 local king=KingEncounter.Definition(4,enemyScale(session))
 local occupied=self.battles[self.campBusy[KingEncounter.Target]]
 local unlocked=self:KingOpen(session) or Progression.KingUnlocked(routeCamps,routeOutposts,false)
 table.insert(targets,{id=KingEncounter.Target,name=king.name.." · FINAL BOSS",
  kind="King",holdBonus=Config.Territories.KingBonus,power=king.power,count=#king.roster,
  available=unlocked and not self.campBusy[KingEncounter.Target],
  reason=if not unlocked then "Beat all "..#camps.." camps on any lane"
   elseif occupied then (if occupied.attacker==session.userId then "Your army holds the center" else "Center occupied by another army")
   elseif self.campBusy[KingEncounter.Target] then "Wait for the previous army to clear the arena"
   else "Challenge the Chicken King"})
 for _,entry in targets do
  local route=self:PlanOrder(session,entry.id,routeCamps,routeOutposts)
  if route then
   local first=route[1]
   local firstKey=self:TerritoryKey(session,first)
   local finalKey=self:TerritoryKey(session,entry.id)
   -- The camp this army is already fighting is its own first step, not a blocker.
   local continuing=previous~=nil and previous.phase~="Returning" and previous.target==first and #route>1
   entry.available=canMove and (continuing or not self:TerritoryBlocked(firstKey,previous)) and not self:TerritoryBlocked(finalKey,previous)
   entry.via=if #route>1 then self:TargetName(session,first) else nil
   entry.reason=if previous and previous.phase~="Returning" and previous.target==entry.id then "Your army is already attacking or stationed here"
    elseif not canMove then "Your army is recovering or defending"
    elseif not entry.available then "Occupied by an army" elseif entry.via then "Via "..entry.via else "Ready"
   local owner=self.campOwners[finalKey]
   entry.owned=owner~=nil and owner.userId==session.userId
   entry.canUnclaim=entry.owned
   entry.ownerId=owner and owner.userId
   entry.current=previous~=nil and previous.target==entry.id
   if entry.owned then
    -- Held ground keeps its flag; armies no longer station there (see Finish).
    entry.power,entry.count,entry.available=0,0,false
    if not entry.current then entry.reason="Conquered" end
   elseif owner and entry.available and not entry.via then
    -- Rival-held ground still has its full garrison for each new challenger.
    entry.reason=if entry.kind=="King" then "Defeat the King to take it from "..owner.name
     else "Held by "..owner.name.." · beat it to take it back"
   end
   if not entry.owned and entry.kind~="Income" then
    if not started and entry.id~="camp:1" then entry.available,entry.reason=false,"Take your Cluck Camp first"
    elseif entry.available and held>=holdLimit then entry.available,entry.reason=false,"Holding "..held.."/"..holdLimit.." · unclaim one first" end
   end
  end
  local kind,index=string.match(entry.id,"^(%a+):([%-]?%d+)$")
  index=tonumber(index)
  local roster={}
  if entry.kind=="Camp" then roster=Progression.Roster(lanePromotion[entry.id],(CampaignRoute.Camp(entry.id)))
  elseif kind=="outpost" then roster=Progression.OutpostRoster(index)
  elseif kind=="king" then roster=king.roster end
  local low,high=math.huge,0
  for _,unit in roster do
   local amount=killReward(session,unit,nil,true)
   low,high=math.min(low,amount),math.max(high,amount)
  end
  entry.killRewardMin,entry.killRewardMax=if low==math.huge then 0 else low,high
  if entry.owned then entry.killRewardMin,entry.killRewardMax=0,0 end
 end
 local kingLocked,kingReason=self:HillKingLock(now)
 if kingLocked then for _,entry in targets do
  if entry.kind=="King" and not entry.current then entry.available=false;entry.reason=kingReason end
 end end
 local income=self:IncomeSummary(session,now)
 if income then
  local entry=table.clone(income);entry.id=income.targetId;entry.kind="Income"
  entry.owned=income.ownerId==session.userId;entry.killRewardMin,entry.killRewardMax=0,0
  table.insert(targets,entry)
 end
 return targets
end

-- With the Hill enabled the shared site exists only while a Hill round is open.
local function incomeEnabled(self)
 return Config.IncomeOutpost and Config.IncomeOutpost.Enabled==true
  and (not (Config.Hill and Config.Hill.Enabled) or self.hillOpen==true)
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
 if not incomeEnabled(self) then return nil end
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
   count+=1;power+=Rules.PetPower(unit.species,unit.stars,unit.level,unit.giantSize)
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
  configuredRate=config.Rate,effectiveRate=if readySession(ownerSession) and not active then math.floor(self:HillRate(ownerSession,now) or config.Rate) else 0,
  boost=if owner and self.hill then self.hill:Boost(owner.userId,now) else 0,
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
 if not incomeEnabled(self) then return end
 local state,config=self.income,Config.IncomeOutpost
 local owner=self.campOwners["income:1"]
 local session=owner and self.sessions[owner.userId]
 local contest=self.battles[state.contestId]
 local active=contest and contest.incomeActiveAt and not contest.paid
 -- Settle the elapsed simulation slice before this tick can activate, resolve
 -- or transfer a contest. Neither a wall-clock stall nor a client pays catchup.
 if readySession(session) and not active then
  local amount=self.territoryIncome:Step(session,dt,self:HillRate(session,now))
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
  session.banner="Raiders are marching on the Hill. Send your army to defend it.";session:Touch()
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
 defender.banner="Your Hill is under attack!";defender:Touch()
 self:ReserveIncome(battle)
end

function BattleService:AttackIncome(session,now)
 if not incomeEnabled(self) then return false,"The Hill is closed. Wait for the next round." end
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
 return true,if joining then "Army returning to defend the Hill." elseif owned then "Army marching to your Hill." else "Army sent to the Hill."
end

function BattleService:Attack(session,targetId,now,keepRoute)
	if type(targetId)~="string" or #targetId>60 then return false,"Invalid target." end
	if targetId:sub(1,5)=="base:" then return false,"Player bases are safe. Attack a camp instead." end
	if targetId=="income:1" then return self:AttackIncome(session,now) end
	targetId=self:OrderId(session,targetId)
	local requestedTarget=targetId
 local requestedCamp,requestedLane=self:CampTarget(session,targetId)
 if requestedCamp and requestedLane~=session.plotIndex and not self:LaneOwner(requestedLane) then
  return false,"That lane has no commander right now."
 end
 local routeCamps,routeOutposts=self:RouteProgress(session)
 local route=self:PlanOrder(session,targetId,routeCamps,routeOutposts)
	if not route then return false,"Target does not exist." end
	local heldGoal=self.campOwners[self:TerritoryKey(session,requestedTarget)]
	if heldGoal and heldGoal.userId==session.userId then
		return false,"You already hold "..self:TargetName(session,requestedTarget)..". Unclaim it to fight there again."
	end
	if not self:Started(session) and requestedTarget~="camp:1" then return false,"Take your Cluck Camp first." end
	local nextHolder=self.campOwners[self:TerritoryKey(session,route[1])]
	if not (nextHolder and nextHolder.userId==session.userId) and self:HoldCount(session)>=self:HoldLimit(session) then
		return false,"You hold "..self:HoldCount(session).." of "..self:HoldLimit(session).." territories. Unclaim one to take another."
	end
	targetId=route[1]
	local previous=self.battles[session.outgoing]
	local moving=self:CanRedirect(session,previous)
	if not moving and (session:IsArmyLocked() or session.outgoing) then return false,"Your army is recovering or defending. Wait until it is ready." end
	local turning=moving and previous.phase=="Returning"
	if previous and not turning and previous.target==requestedTarget then return false,"Your army is already attacking or stationed at this camp." end
	if previous and not turning and previous.target==targetId then
		-- Already fighting the first required camp: keep that fight, then march on.
		if keepRoute or previous.phase=="Holding" then return false,"Your army is already attacking or stationed at this camp." end
		if self:TerritoryBlocked(self:TerritoryKey(session,requestedTarget),previous) then
			return false,self:TargetName(session,requestedTarget).." is occupied."
		end
		previous.routeGoal=requestedTarget
		previous.routeGoalName=self:TargetName(session,requestedTarget)
		return true,"Taking "..previous.name..", then onward to "..previous.routeGoalName.."."
	end
	local roster=session:Lineup()
	if #roster==0 then return false,"Add at least one chicken to your army first." end
	local kind,id=string.match(targetId,"^(%a+):([%-]?%d+)$")
	local index=tonumber(id)
	local defender,defenders,destination,name,campIndex,routeGoal,targetPower
	local defenderScale=1
 local isKing=targetId==KingEncounter.Target
 local outpostIndex=if kind=="outpost" and index and Progression.Outposts()[index] then index else nil
 local camps=Progression.Camps(session.promotion)
 local campTarget,lanePlot=self:CampTarget(session,targetId)
 local laneOwner=if campTarget then (if lanePlot==session.plotIndex then session else self:LaneOwner(lanePlot)) else nil
 local lanePromotion=if laneOwner then laneOwner.promotion or 1 else session.promotion or 1
	if isKing then
  if not (self:KingOpen(session) or Progression.KingUnlocked(routeCamps,routeOutposts,false)) then
   return false,"Beat all "..#camps.." camps on any lane before challenging the Chicken King."
  end
  if self:TerritoryBlocked(KingEncounter.Target,previous) then return false,"The center is occupied. Wait for that army to leave." end
  local kingLocked,kingReason=self:HillKingLock(now)
  if kingLocked then return false,kingReason end
  local king=KingEncounter.Definition(session.promotion or 1,enemyScale(session))
  defenders,destination,name,targetPower=king.roster,Vector3.new(0,1.05,0),king.name,king.power
 elseif outpostIndex then
  local camp=Progression.Outposts()[outpostIndex]
  if self:TerritoryBlocked(targetId,previous) then return false,"This camp is occupied. Wait for that army to leave." end
  defenders=Progression.OutpostRoster(outpostIndex)
  destination=self.world:OutpostFrame(outpostIndex).Position
  name=camp.name
 elseif campTarget and laneOwner and Progression.Camps(lanePromotion)[campTarget] then
		name=self:TargetName(session,targetId)
		if self:TerritoryBlocked(campKey(lanePlot,campTarget),previous) then return false,name.." is occupied." end
		campIndex=campTarget
		defenderScale=enemyScale(session) -- October 20 (Rebirth v2): the attacker's rank.
		defenders=scaledRoster(Progression.Roster(lanePromotion,campTarget),defenderScale)
		destination=self:CampPosition(campTarget,lanePlot)
	else return false,"Target does not exist." end
	-- Only the owner's own ground lacks a hostile garrison (and owners are refused
	-- above). A rival at a held King fights a full fresh court; the shared arena
	-- has no idle rigs while owned, so LiveBattleActors spawns them.
	local territoryOwner=self.campOwners[self:TerritoryKey(session,targetId)]
	if territoryOwner and territoryOwner.userId==session.userId then defenders={} end
	targetPower=targetPower or scaledPower(defenders,defenderScale)
	local battleId=HttpService:GenerateGUID(false)
	-- A squad still marching leaves from where it is, not from its old target.
	local midMarch=moving and previous.phase=="Travel"
	local origin=if turning or midMarch then armyCenter(previous) elseif moving then previous.destination else self.world:Position(session.plotIndex)
	local battle=Battle.new(battleId,session.userId,targetId,origin,destination,now)
	battle.name,battle.campIndex=name,campIndex
 -- routeCamps tracks this push on the lane being attacked.
 battle.routeCamps=if campIndex and lanePlot~=session.plotIndex then self:LaneCleared(session,lanePlot) or {} else table.clone(routeCamps)
 battle.routeOutposts=table.clone(routeOutposts)
 battle.plotIndex=if campIndex then lanePlot else session.plotIndex
 battle.laneOwner=laneOwner and laneOwner.userId
 battle.lanePromotion=lanePromotion
 battle.isKing=isKing
 battle.outpostIndex=outpostIndex
 battle.promotion=session.promotion or 1
 battle.campCount=#camps
 battle.attackPower,battle.targetPower=Rules.Power(roster),targetPower
 battle.campKey=if isKing then KingEncounter.Target elseif outpostIndex then targetId elseif campIndex then campKey(lanePlot,campIndex) else nil
 battle.friendlyTerritory=territoryOwner~=nil and territoryOwner.userId==session.userId
 if campIndex and not battle.friendlyTerritory then battle.routeCamps[campIndex]=nil end
 if battle.friendlyTerritory then battle.captureElapsed=battle:CaptureDuration() end
 if isKing then
  local outward=Vector3.new(origin.X,0,origin.Z)
  if outward.Magnitude<1 then outward=self.world:Position(session.plotIndex) end
  local angle=math.atan2(outward.Z,outward.X)
  local spoke=-math.pi/2+math.round((angle+math.pi/2)/(math.pi/3))*math.pi/3
  battle.frame=CFrame.lookAt(destination,destination-Vector3.new(math.cos(spoke),0,math.sin(spoke)))
 elseif outpostIndex then battle.frame=self.world:OutpostFrame(outpostIndex)
 elseif campIndex and self.world.CampFrame then battle.frame=self.world:CampFrame(campIndex,lanePlot)
 elseif defender and self.world.PlotFrame then battle.frame=self.world:PlotFrame(defender.plotIndex)*CFrame.new(0,0,-16) end
	battle.target=targetId
	battle.routeGoal=if #route>1 then requestedTarget else nil
 battle.routeGoalName=if battle.routeGoal then self:TargetName(session,battle.routeGoal) else nil
	battle.defender=if defender then defender.userId else nil
	if moving then
		-- October 15: the old fight's progress stays at its camp and drains slowly
		-- (LeaveProgress); leaving a Mission forfeits it.
		if previous.operationId and not previous.paid then
			self.operations:Resolve(previous,"Abandoned",now)
			session.lastResult=previous.name.." left behind · no completion reward."
		elseif previous.operationId then self.operations:Release(previous,now)
		else self:LeaveProgress(previous,now) end
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
	self:ResumeProgress(session,battle,now)
	if self.world.root then
		local folder=self.world.root:FindFirstChild("Battles")
		if not folder then folder=Instance.new("Folder");folder.Name="Battles";folder.Parent=self.world.root end
		battle.actors=LiveBattleActors.new(folder,battle)
		local guards=if #defenders>0 and self.world.TakeTerritoryDefenders then
			self.world:TakeTerritoryDefenders({king=isKing,outpost=outpostIndex,index=campIndex,plot=lanePlot}) else {}
		local guardIndex=0
		for _,u in battle.units do
			local actor=nil
			if u.side=="A" then
				if moving and previous.actors then actor=previous.actors:TakePet(u.petId,"A")
				elseif self.world.TakeActor then actor=self.world:TakeActor(session.plotIndex,u.petId) end
			elseif defender and self.world.TakeActor then actor=self.world:TakeActor(defender.plotIndex,u.petId)
			else
				guardIndex+=1
				actor=guards[guardIndex]
			end
			if actor then battle.actors:Adopt(u,actor) end
		end
	end
	-- All adopted rigs receive the same departure time and source gate.
	-- A turned-around squad is already outside the old camp; it leaves from where it stands.
	local departure=if moving and not turning and not midMarch then previous:DepartureSite() else nil
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
  self.campBusy[battle.campKey]=battleId;self.campLocations[battle.campKey]={index=campIndex,plot=lanePlot,position=destination,frame=battle.frame,halfSize=Config.CampHalfSize}
  self.world:SetCampBusy(campIndex,true,lanePlot)
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
  if kill.boss and kill.side=="B" and battle.defender==nil then earner.kingBountyPaid=true end
  if amount<=0 then continue end
  amount=earner:Credit(amount,"battle")
  table.insert(battle.coinDrops,{serial=kill.serial,userId=earner.userId,amount=amount,x=kill.x,z=kill.z,at=now})
  if #battle.coinDrops>40 then table.remove(battle.coinDrops,1) end
 end
end

local function oddsBucket(battle)
 local ratio=(battle.attackPower or 0)/math.max(1,battle.targetPower or 0)
 return if ratio<1 then "Under1" elseif ratio<1.3 then "1To1.3" elseif ratio<2 then "1.3To2" else "2Plus"
end

-- Main-route/King funnel: first wins and failed attempts before a first win.
-- Observation only; detail pairs the result with the army's power-ratio band.
function BattleService:RecordFunnel(attacker,battle,outcome,bossDown,now)
 local step=if battle.isKing then "King" elseif battle.campIndex then "Camp"..battle.campIndex else nil
 if not step then return end
 local wonBefore=if battle.isKing then attacker.kingCleared==true else attacker.firstWins[battle.campIndex]==true
 if wonBefore then return end
 local seconds=math.max(0,now-(battle.startedAt or now))
 if outcome=="A" then
  if battle.friendlyTerritory or (battle.isKing and not bossDown) then return end
  TutorialService.LogProgress(attacker.userId,if battle.isKing then "KingFirstClear" else "ConquestFirstWin",seconds,step,"FirstWin/"..oddsBucket(battle))
 elseif outcome=="B" or outcome=="Draw" or outcome=="Blocked" or outcome=="Retreat" then
  self.funnelFailures=self.funnelFailures or {}
  local count=(self.funnelFailures[attacker.userId] or 0)+1
  if count>FUNNEL_FAILURE_LIMIT then return end
  self.funnelFailures[attacker.userId]=count
  TutorialService.LogProgress(attacker.userId,"ConquestFailed",seconds,step,(if outcome=="B" then "Defeated" else outcome).."/"..oddsBucket(battle))
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
 -- The King counts only when this encounter's own boss fell (B units are
 -- still present here; Hold removes them below).
 local bossDown=false
 if battle.isKing then for _,u in battle.units do if u.side=="B" and u.boss and not u.petId and u.hp<=0 then bossDown=true end end end
 -- First-win funnel and rewards belong to the commander's own lane.
 local ownLane=attacker~=nil and (battle.campIndex==nil or battle.plotIndex==attacker.plotIndex)
 if attacker and battle.defender==nil and ownLane then self:RecordFunnel(attacker,battle,outcome,bossDown,now) end
 if outcome=="A" and attacker and not battle.friendlyTerritory then
  if battle.isKing then
   if bossDown then attacker.kingCleared=true end
  elseif battle.outpostIndex then
   battle.routeOutposts[battle.outpostIndex]=true
   attacker.frontierWins[battle.outpostIndex]=true
   attacker:UnlockProgress()
  elseif battle.campIndex and not ownLane then
   battle.routeCamps[battle.campIndex]=true
   if battle.laneOwner then self:RecordLaneWin(attacker,battle.laneOwner,battle.campIndex) end
  elseif battle.campIndex then
   battle.routeCamps[battle.campIndex]=true
   attacker.firstWins[battle.campIndex]=true
   attacker.tutorial.wonCamp=true
   attacker.campUnlocked=math.max(attacker.campUnlocked,math.min(battle.campCount,battle.campIndex+1))
   attacker:UnlockProgress()
  end
 end
 local planted=false
 if outcome=="A" and attacker and battle.campKey and (bossDown or not battle.isKing) then
  local holder=self.campOwners[battle.campKey]
  -- The limit is checked when the order is given; a route leg can still meet it.
  if (holder and holder.userId==attacker.userId) or self:HoldCount(attacker)<self:HoldLimit(attacker) then
   self:SetTerritoryOwner(battle.campKey,attacker,self.campLocations[battle.campKey])
   planted=true
  end
 end
 local bonus=if planted and not battle.friendlyTerritory then self:HoldBonus(battle.campKey) else 0
 local bonusText=if bonus>0 then " +"..math.floor(bonus*100+0.5).."% egg value while you hold it." else ""
 local limitText=if outcome=="A" and attacker and battle.campKey and not planted and (bossDown or not battle.isKing)
  then " You're at your "..self:HoldLimit(attacker).."-territory limit, so no flag. Unclaim one first." else nil
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
	-- Conquest armies march home after the victory moment; route legs advance
	-- instead and the Supply Outpost keeps its defended station.
	battle.autoReturnAt=if hold and not battle.incomeSite and not battle.routeGoal then now+VICTORY_LINGER_SECONDS else nil
	if not hold then
		battle.routeGoal=nil
		if battle.campKey then self.departingCamps[battle.campKey]=battle.id end
	end
	if attacker and attacker.outgoing==battle.id then
		attacker.armyState,attacker.returnAt=if hold then "Deployed" else "Returning",if hold then 0 else now+Config.ReturnSeconds
		attacker.stationedAt=if hold then battle.name else nil
		attacker.lastResult=if hold and battle.friendlyTerritory then "Army stationed at "..battle.name.."."
			elseif hold and limitText then "You beat "..battle.name.."!"..limitText
			elseif hold and battle.routeGoal then "You've conquered "..battle.name.."!"..bonusText.." Marching toward "..battle.routeGoalName.."."
			elseif hold and battle.autoReturnAt then "You've conquered "..battle.name.."!"..bonusText.." Your army is heading home to lay eggs."
			elseif hold then "You've conquered "..battle.name.."!"..bonusText
			elseif outcome=="A" then "Victory at "..battle.name.."!"
			elseif outcome=="B" then "Army defeated. Your chickens respawn at home; send them again whenever you're ready."
			elseif outcome=="Draw" then "Draw — your chickens are returning home."
			else outcome.." — returning home. You keep the coins you earned."
		attacker:Touch()
	end
	if defender then
		defender.banner=if outcome=="A" then "Base defeated. Your chickens and coins are safe."
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
   session.lastResult="Hill defended. Your army keeps holding it.";session:Touch()
  else
   battle.paid=true;battle.incomeDeparture=true;battle:Finish("Too late",now)
   if session then
    session.armyState,session.returnAt="Returning",now+Config.ReturnSeconds
    session.lastResult="The Hill changed hands. Your army is returning home.";session:Touch()
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
  session.lastResult="Your army arrived to defend the Hill.";session:Touch()
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
  session.lastResult=if holding then "You hold the Hill! Your farm earns more the longer you stay."
   elseif outcome=="A" then "Hill lost. Your chickens recover at home."
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
 self.releasedTerritories[key]=nil
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
  if awaitingArrival and not self.releasedTerritories[key] then self.campClearedAt[key]=nil;continue end
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
   if not battle:Returned(now) then session.banner="The route was blocked. Your army recovered at your base." end
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
	local advance,homeward={},{}
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
		elseif battle.phase=="Holding" and battle.autoReturnAt and now>=battle.autoReturnAt then
			table.insert(homeward,battle)
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
			if not ok then
				battle.autoReturnAt=now -- Never strand a squad (and its egg income) at a stopped route leg.
				session.lastResult="Route stopped. "..why.." Your army is heading home.";session:Touch()
			end
		end
	end
	-- The flag stays; the squad leaves through the normal Returning march, which
	-- also frees a shared arena for the next challenger after the vacancy grace.
	for _,battle in homeward do
		local session=self.sessions[battle.attacker]
		if self.battles[battle.id]==battle and battle.phase=="Holding" and session and session.outgoing==battle.id then
			battle.autoReturnAt=nil
			self:ReturnHome(session,now)
		end
	end
 self:StepIntercepts(now)
 if incomeEnabled(self) and self.world.SetIncomeStatus then self.world:SetIncomeStatus(self:IncomeSummary(nil,now)) end
 self:RefreshTerritoryBonus()
end

function BattleService:ReturnHome(session,now)
	local battle=self.battles[session.outgoing]
	if not battle or battle.phase=="Returning" then return false,"Your army is already home or returning." end
	-- October 15: a stationed mission army lowers its flag and walks home; a holder
	-- under attack must finish the fight first.
	if battle.operationId and battle.paid and battle.phase=="Holding" then return self.operations:Recall(battle,session,now) end
	if battle.operationId and battle.defender==session.userId then return false,"Your army is defending a territory. Win the fight first." end
	if battle.operationId then self.operations:Resolve(battle,"Abandoned",now);return true,"Mission abandoned. Your army is marching home." end
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
  session.lastResult="Army returning home. The challenger can still capture the Hill.";session:Touch()
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
	else self:LeaveProgress(battle,now);self:Finish(battle,"Retreat",now) end
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
			-- A mission contest can hand its encounter to the other commander; keep it.
			if battle.attacker==userId or battle.defender==userId then table.insert(remove,battle) end
		end
	end
	for _,battle in remove do
  self:Remove(battle)
  local attacker=self.sessions[battle.attacker]
  if attacker and attacker.outgoing==battle.id then attacker.outgoing=nil;attacker.awayPets={};attacker.returnAt=now+Config.ReturnSeconds;attacker.armyState="Recovering";attacker:Touch() end
 end
 -- Their lane empties with their plot: armies attacking it march home and
 -- every flag on it clears (beaten-once records stay saved).
 local leaving=self.sessions[userId]
 local lanePlot=leaving and leaving.plotIndex
 if lanePlot then
  local visitors={}
  for _,battle in self.battles do
   if battle.campIndex and battle.plotIndex==lanePlot and battle.attacker~=userId and battle.phase~="Returning" then table.insert(visitors,battle) end
  end
  for _,battle in visitors do
   local visitor=self.sessions[battle.attacker]
   if self.battles[battle.id]~=battle or not visitor or visitor.outgoing~=battle.id then continue end
   self:ReturnHome(visitor,now)
   visitor.lastResult=leaving.name.." left, so their lane closed. Your army is heading home."
   visitor:Touch()
  end
  for _,battle in self.battles do
   local goal=battle.routeGoal and select(2,CampaignRoute.Camp(battle.routeGoal))
   if goal==lanePlot then battle.routeGoal,battle.routeGoalName=nil,nil end
  end
 end
 -- Departure/reset also clears this player's remaining server-session ownership.
 local released={}
 for key,owner in self.campOwners do
  if owner.userId==userId or (lanePlot and key:match("^(%d+):%d+$")==tostring(lanePlot)) then table.insert(released,key) end
 end
 for _,key in released do self:SetTerritoryOwner(key,nil) end
 for key,ownerId in self.releasedTerritories do if ownerId==userId then self.releasedTerritories[key]=nil end end
 if self.income.clockOwner==userId or (self.campOwners["income:1"]==nil and self.income.raidId) then self:CancelIncomeApproach(now);self.income.clockOwner=nil end
 self.income.retry[userId]=nil
 if self.funnelFailures then self.funnelFailures[userId]=nil end
 if self.income.lostOwners then self.income.lostOwners[userId]=nil end
 if self.income.receipts then self.income.receipts[userId]=nil end
 self.territoryIncome:Release(userId)
end

-- King of the Hill (HillService owns the clock). The Hill reuses the shared
-- territory contest above at the King's arena: for the whole round Hill Guards
-- replace the King's court and the arena prompt targets the Hill, so King fights
-- wait for the break. There is no pre-round lock (Config.Hill.KingLockSeconds=0);
-- a King fight still running at the bell only delays the round's start.
function BattleService:HillRate(session,now)
 if self.hill then return self.hill:Rate(session,now) end
 return nil
end

local function hillClock(seconds)
 seconds=math.max(0,math.ceil(seconds))
 return string.format("%d:%02d",seconds//60,seconds%60)
end

function BattleService:HillKingLock(now)
 local hill=self.hill
 if not hill then return false,nil end
 if hill:KingLock(now) then
  -- Open: the rest of this round. Opening (or the bell): a full round ahead.
  local wait=if hill.phase=="Open" then hill.endsAt-now else Config.Hill.RoundSeconds
  return true,"The Hill fight is using the arena — the King opens in "..hillClock(wait)
 end
 if self.campBusy["income:1"] then return true,"Hill armies are leaving the arena — the King opens in a moment" end
 return false,nil
end

-- Opens only on an empty arena. A held King flag gives way to the Hill.
function BattleService:OpenHill(now)
 if self.campBusy[KingEncounter.Target] or self.campBusy["income:1"] then return false end
 if self.campOwners[KingEncounter.Target] then self:SetTerritoryOwner(KingEncounter.Target,nil) end
 local state,config=self.income,Config.IncomeOutpost
 state.graceUntil,state.retry,state.contestId,state.raidId,state.warningUntil=0,{},nil,nil,nil
 state.eligibleTime,state.clockOwner,state.warnedOnce,state.warningAfter=0,nil,false,config.WarningAfter
 self.hillOpen=true
 if self.world.SetHillMode then self.world:SetHillMode(true) end
 return true
end

-- Ends a round: live contests resolve as cancelled, every Hill army marches home
-- and the flag clears. The King returns once those armies leave the arena.
function BattleService:CloseHill(now)
 local contests={}
 for _,battle in self.battles do
  if battle.incomeSite and battle.incomeContest and not battle.paid and not battle.incomeJoin then table.insert(contests,battle) end
 end
 for _,battle in contests do
  if self.battles[battle.id]==battle and not battle.paid then self:FinishIncome(battle,"Cancelled",now) end
 end
 for _,session in self.sessions do
  local battle=self.battles[session.outgoing]
  if battle and battle.incomeSite and battle.phase~="Returning" then self:ReturnHome(session,now) end
 end
 if self.campOwners["income:1"] then self:SetTerritoryOwner("income:1",nil) end
 self:CancelIncomeApproach(now)
 self.income.clockOwner=nil
 self.hillOpen=false
 if self.world.SetHillMode then self.world:SetHillMode(false) end
end

-- Every camp and frontier outpost this commander could fight, by order id.
function BattleService:CampSpots(session)
 local spots={}
 for _,owner in self.sessions do
  if not owner.plotIndex or owner.closing then continue end
  for i in Progression.Camps(owner.promotion or 1) do
   spots[CampaignRoute.CampId(i,owner.plotIndex,session.plotIndex)]=self:CampPosition(i,owner.plotIndex)
  end
 end
 if self.world.OutpostFrame then
  for i in Progression.Outposts() do spots["outpost:"..i]=self.world:OutpostFrame(i).Position end
 end
 return spots
end

-- October 15 (owner): an army marching to a target fights any open camp it walks
-- into on the way, then marches on to its target (routeGoal). Nothing is ordered
-- or announced; only a camp it physically passes counts, never the ground it set
-- out from (camps in range on its first check), held ground, busy camps or the King.
function BattleService:StepIntercepts(now)
 if now<(self.nextInterceptAt or 0) then return end
 self.nextInterceptAt=now+0.25
 local orders={}
 for _,battle in self.battles do
  if battle.phase~="Travel" or battle.operationId or battle.incomeSite or battle.incomeContest or battle.incomeJoin or battle.defender then continue end
  local session=self.sessions[battle.attacker]
  if not session or session.outgoing~=battle.id or session.closing then continue end
  local center=armyCenter(battle)
  local first=battle.interceptSeen==nil
  battle.interceptSeen=battle.interceptSeen or {}
  for id,at in self:CampSpots(session) do
   if id==battle.target or id==battle.routeGoal or battle.interceptSeen[id] then continue end
   if (Vector3.new(at.X,0,at.Z)-Vector3.new(center.X,0,center.Z)).Magnitude>Config.InterceptRadius then continue end
   battle.interceptSeen[id]=true
   if not first then table.insert(orders,{battle=battle,session=session,id=id});break end
  end
 end
 for _,order in orders do
  local battle,session=order.battle,order.session
  if self.battles[battle.id]~=battle or session.outgoing~=battle.id then continue end
  local entry
  for _,target in self:Targets(session,now) do if target.id==order.id then entry=target;break end end
  if not entry or not entry.available or entry.owned or entry.via or entry.kind=="King" then continue end
  local goal=battle.routeGoal or battle.target
  local lastResult=session.lastResult
  local ok=self:Attack(session,order.id,now)
  local fight=self.battles[session.outgoing]
  if ok and fight and fight~=battle then
   fight.routeGoal,fight.routeGoalName=goal,self:TargetName(session,goal)
   session.lastResult=lastResult
  end
 end
end

local function leftState(record,now)
 local elapsed=now-record.at
 local progress=math.max(0,record.progress-elapsed/Config.LeftProgressDrainSeconds)
 local stood=math.floor(elapsed/Config.LeftDefenderRespawnSeconds)
 return progress,math.max(0,#record.dead-stood),stood
end

-- October 15 (owner request): an army that leaves a fight, for another target or
-- home, leaves its progress at that camp. The bar drains over
-- LeftProgressDrainSeconds and fallen guards stand back up one every
-- LeftDefenderRespawnSeconds. The same commander resumes what is left.
function BattleService:LeaveProgress(battle,now)
 if not battle.campKey or not battle:IsConquest() or battle.friendlyTerritory or battle.outcome~=nil then return end
 if battle.phase~="Fight" and battle.phase~="Capture" then return end
 local dead,index={},0
 for _,u in battle.units do if u.side=="B" and not u.petId then
  index+=1
  -- A fallen boss (noRespawn) is back at full strength on return.
  if u.hp<=0 and not u.noRespawn then table.insert(dead,index) end
 end end
 local progress=math.clamp(battle.captureElapsed/battle:CaptureDuration(),0,1)
 if progress<=0 and #dead==0 then return end
 self.leftProgress[battle.campKey]={attacker=battle.attacker,progress=progress,dead=dead,at=now,
  x=battle.destination.X,y=battle.destination.Y,z=battle.destination.Z,name=battle.name}
end

-- A new fight at a camp consumes its left progress; only the same commander keeps it.
function BattleService:ResumeProgress(session,battle,now)
 local record=battle.campKey and self.leftProgress[battle.campKey]
 if not record then return end
 self.leftProgress[battle.campKey]=nil
 if record.attacker~=session.userId or battle.friendlyTerritory then return end
 local progress,down,stood=leftState(record,now)
 battle.captureElapsed=progress*battle:CaptureDuration()
 battle.captureStarted=progress>0
 -- The earliest fallen stand up first; the rest keep their place in that queue.
 local guards={}
 for _,u in battle.units do if u.side=="B" and not u.petId then table.insert(guards,u) end end
 for k=1,down do
  local u=guards[record.dead[stood+k]]
  if u then u.hp=0;u.respawnAt=record.at+(stood+k)*Config.LeftDefenderRespawnSeconds end
 end
end

function BattleService:Snapshots(now)
	local result={}
	for _,battle in self.battles do
  table.insert(result,battle:Snapshot(now))
 end
 -- Left progress shows as a draining meter at its camp (BattleController reclaim view).
 for key,record in self.leftProgress do
  local progress,down=leftState(record,now)
  if progress<=0 and down==0 then self.leftProgress[key]=nil
  elseif progress>0 then
   table.insert(result,{id="left:"..key,territoryReclaim=true,abandoned=true,conquest=true,phase="Returning",
    attacker=record.attacker,captureProgress=progress,enemyReclaiming=true,defendersDown=down,
    x=record.x,y=record.y,z=record.z,name=record.name,units={}})
  end
 end
	return result
end

function BattleService:Destroy()
 for _,battle in self.battles do battle:Destroy() end
	self.battles,self.campBusy,self.campOwners,self.departingCamps,self.departingSides,self.campClearedAt={},{},{},{},{},{}
 self.territoryIncome:Destroy()
 self.releasedTerritories={}
end

return BattleService
