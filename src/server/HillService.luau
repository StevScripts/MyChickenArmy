--!strict
-- King of the Hill (docs/team/KING_OF_THE_HILL.md). The King's arena alternates
-- a Hill round with a King break. BattleService's shared territory contest runs
-- the fights (Hill Guards, rival armies, NPC raids); this module owns the clock,
-- the holder's farm boost, the round winner and the Hill Roll / Champion rewards.
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Catalog=require(Shared.PetCatalog)
local HillService={}
HillService.__index=HillService

local function clock(seconds)
 seconds=math.max(0,math.ceil(seconds))
 return string.format("%d:%02d",seconds//60,seconds%60)
end

local function ready(session)
 return session~=nil and session.loaded==true and not session.closing and not session.saveLost
end

function HillService.new(battles,world,sessions,now)
 local self=setmetatable({battles=battles,world=world,sessions=sessions,random=Random.new(),
  phase="Break",endsAt=(now or os.clock())+Config.Hill.FirstBreakSeconds,round=0,
  seconds={},holderId=nil,heldSince=0,deliverAt=0,lastWinner=nil,entered={},intro={},analytics=nil::any},HillService)
 battles.hill=self
 return self
end

-- First-time film (client HillIntro): once per player ever, on the first round
-- that opens after the Hill HUD's rule (all camps won or the King cleared).
-- Players who already won a Hill round know it. TutorialService saves hillIntroSeen.
function HillService.IntroDue(session)
 local tutorial=session.tutorial
 return Config.Hill.Enabled and tutorial~=nil and not tutorial.hillIntroSeen
  and (session.kingCleared==true or session:Completed())
  and (session.hillWins or 0)==0 and not session.hillChampion
end

-- Coins/sec of the whole flock as if every chicken laid at home (before Double
-- Cash, which Credit's "territory" source applies). Also used for the away share.
function HillService.PetRate(session,pet)
 return Rules.EggRate(pet.species,pet.stars,pet.level)*session:EggProductionMultiplier()
  *Rules.EggUnitValue(session.incomeLevel)*(1+(session.researchEffects and session.researchEffects.eggValue or 0))
end

-- Observation only (Analytics ServerEvent, set by GameServer); never changes the Hill.
function HillService:Report(userId,name,value)
 local analytics,session=self.analytics,userId and self.sessions[userId]
 if analytics and session then pcall(function() analytics:ServerEvent(session,name,nil,value) end) end
end

-- hill.enter once per round per player, when their army engages the Hill or holds it.
function HillService:NoteEntry(session)
 if self.entered[session.userId]==self.round then return end
 local own=self.battles.battles[session.outgoing]
 if self.holderId==session.userId or (own~=nil and own.incomeSite==true and own.phase~="Returning") then
  self.entered[session.userId]=self.round
  self:Report(session.userId,"hill.enter")
 end
end

function HillService:Boost(userId,now)
 if self.phase~="Open" or userId==nil or userId~=self.holderId then return 0 end
 local hill=Config.Hill
 return math.min(hill.BoostMax,hill.BoostPerMinute*math.max(0,now-self.heldSince)/60)
end

-- Holder pay: chickens out on the Hill keep "laying" (no egg loss for holding)
-- plus the hold boost on the whole farm.
function HillService:Rate(session,now)
 if not ready(session) or session.userId~=self.holderId or self.phase~="Open" then return 0 end
 local farm,away=0,0
 for id,pet in session.pets do
  local rate=HillService.PetRate(session,pet)
  farm+=rate
  if session.awayPets and session.awayPets[id] then away+=rate end
 end
 return away+farm*self:Boost(session.userId,now)
end

function HillService:KingLock(now)
 if self.phase=="Open" or self.phase=="Opening" then
  return true,"The Hill is open · the King returns after the round"
 end
 local remaining=self.endsAt-now
 if remaining<=Config.Hill.KingLockSeconds then return true,"The Hill opens in "..clock(remaining) end
 return false,nil
end

function HillService:Leader()
 local bestId,best=nil,0
 for userId,seconds in self.seconds do
  if seconds>best and ready(self.sessions[userId]) then bestId,best=userId,seconds end
 end
 return bestId,best
end

function HillService:Open(now)
 if not self.battles:OpenHill(now) then return false end
 self.phase,self.endsAt,self.round=("Open"),now+Config.Hill.RoundSeconds,self.round+1
 table.clear(self.seconds);self.holderId,self.heldSince=nil,now
 table.clear(self.intro)
 for _,session in self.sessions do
  -- The first-time film announces the round itself, so its players skip the toast.
  if ready(session) and HillService.IntroDue(session) then self.intro[session.userId]=true;session:Touch()
  elseif ready(session) and session.kingCleared then session.banner="The Hill is open! Hold the King's arena to win a Hill Roll.";session:Touch() end
 end
 return true
end

function HillService:Close(now)
 local winnerId,seconds=self:Leader()
 if seconds<Config.Hill.MinWinSeconds then winnerId=nil end
 self.battles:CloseHill(now)
 self.phase,self.endsAt=("Break"),now+Config.Hill.BreakSeconds
 table.clear(self.intro) -- An unseen film waits for the next round.
 if self.holderId then self:Report(self.holderId,"hill.hold",now-self.heldSince) end
 self.holderId,self.lastWinner=nil,nil
 local winner=winnerId and self.sessions[winnerId]
 if ready(winner) then
  winner.hillWins=(winner.hillWins or 0)+1
  winner.hillRollCredits=(winner.hillRollCredits or 0)+1
  self.lastWinner=winner.name
  local granted=self:Deliver(winner)
  winner.banner=if granted[1] then "You won the Hill! Hill Roll: "..Catalog[granted[1]].name.." joined your flock."
   else "You won the Hill! You have the most chickens you can keep ("..Config.StorageLimit.."): sell some to receive your Hill Roll."
  winner:Touch()
  self:Report(winner.userId,"hill.win")
  if self.battles.telemetry then
   self.battles.telemetry:Record("HillRoundWon",{userId=winner.userId,seconds=math.floor(seconds),wins=winner.hillWins,round=self.round},"hill:"..self.round)
  end
 end
 for _,session in self.sessions do
  if ready(session) and session~=winner and ((self.seconds[session.userId] or 0)>0 or self.entered[session.userId]==self.round) then
   self:Report(session.userId,"hill.lost")
  end
  if ready(session) and session~=winner and (self.seconds[session.userId] or 0)>0 then
   session.banner=if winner then winner.name.." won the Hill round." else "The Hill round ended."
   session:Touch()
  end
 end
 table.clear(self.seconds)
end

-- Grants owed rewards while the flock has room. Hill Rolls draw a normal roll
-- with extra Luck strength; the Champion arrives once at ChampionWins wins.
function HillService:Deliver(session)
 local granted={}
 if not ready(session) then return granted end
 local hill=Config.Hill
 while (session.hillRollCredits or 0)>0 and session:Count()<session:CollectionLimit() do
  local research=(session.researchEffects and session.researchEffects.rollingLuck or 0)+hill.RollLuckBonus
  local species=Rules.Draw(session.luck,self.random:NextNumber(),session.promotion,session:PaidLuckMultiplier(),research)
  local pet=session:AddPet(species,1)
  pet.investment=0 -- A reward never fabricates a refundable cash purchase.
  session.hillRollCredits-=1
  table.insert(granted,species)
 end
 if (session.hillWins or 0)>=hill.ChampionWins and not session.hillChampion and Catalog[hill.ChampionSpecies]
  and session:Count()<session:CollectionLimit() then
  local pet=session:AddPet(hill.ChampionSpecies,1)
  pet.investment=0
  session.hillChampion=true
  table.insert(granted,hill.ChampionSpecies)
  session.banner="Hill Champion! "..Catalog[hill.ChampionSpecies].name.." joined your flock."
 end
 if #granted>0 then session:RefreshArmy();session:Touch() end
 return granted
end

function HillService:Step(dt,now)
 if not Config.Hill.Enabled then return end
 if self.phase=="Break" and now>=self.endsAt then self.phase="Opening" end
 if self.phase=="Opening" then self:Open(now) end
 if self.phase=="Open" then
  local owner=self.battles.campOwners["income:1"]
  local ownerId=owner and ready(self.sessions[owner.userId]) and owner.userId or nil
  if ownerId~=self.holderId then
   if self.holderId then self:Report(self.holderId,"hill.hold",now-self.heldSince) end
   self.holderId,self.heldSince=ownerId,now
  end
  if ownerId then self.seconds[ownerId]=(self.seconds[ownerId] or 0)+dt end
  if now>=self.endsAt then self:Close(now) end
 end
 if now>=self.deliverAt then
  self.deliverAt=now+2
  for _,session in self.sessions do
   if self.phase=="Open" and ready(session) then self:NoteEntry(session) end
   if ready(session) and ((session.hillRollCredits or 0)>0 or ((session.hillWins or 0)>=Config.Hill.ChampionWins and not session.hillChampion)) then
    self:Deliver(session)
   end
  end
 end
end

function HillService:Status(now)
 local leaderId,leaderSeconds=self:Leader()
 local holder=self.holderId and self.sessions[self.holderId]
 local leader=leaderId and self.sessions[leaderId]
 return {phase=self.phase,remaining=math.max(0,self.endsAt-now),
  endsAt=workspace:GetServerTimeNow()+math.max(0,self.endsAt-now),
  holderId=self.holderId,holderName=holder and holder.name,
  leaderId=leaderId,leaderName=leader and leader.name,leaderSeconds=math.floor(leaderSeconds),
  lastWinner=self.lastWinner}
end

-- Per-player snapshot for the HUD (HillHud): the top banner during a round and
-- the bottom "Next Hill" line during a break. No world sign; the HUD owns it.
function HillService:Snapshot(session,now)
 local status=self:Status(now)
 local battles=self.battles
 local own=battles.battles[session.outgoing]
 local contest=battles.battles[battles.income.contestId]
 status.engaged=own~=nil and own.incomeSite==true and own.phase~="Returning"
 status.contested=contest~=nil and contest.incomeActiveAt~=nil and not contest.paid
 status.holding=self.holderId==session.userId
 status.mySeconds=math.floor(self.seconds[session.userId] or 0)
 status.myBoost=self:Boost(session.userId,now)
 status.wins=session.hillWins or 0
 status.championWins=Config.Hill.ChampionWins
 status.roundSeconds=Config.Hill.RoundSeconds
 status.champion=session.hillChampion==true
 status.enabled=Config.Hill.Enabled
 status.intro=self.phase=="Open" and self.intro[session.userId]==true and not session.tutorial.hillIntroSeen
 return status
end

function HillService:Release(userId)
 self.seconds[userId],self.entered[userId],self.intro[userId]=nil,nil,nil
 if self.holderId==userId then self.holderId=nil end
end

return HillService
