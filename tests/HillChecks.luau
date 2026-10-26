-- King of the Hill: isolated fixtures (no profiles, live sessions or world edits).
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(Server.PlayerSession)
local Battles=require(Server.BattleService)
local Hill=require(Server.HillService)
local Config=require(Shared.Config)
local Catalog=require(Shared.PetCatalog)
local Layout=require(Shared.FlockLayout)
local Checks={}

local function setup()
 local a,b=Session.new(2001,"Holder",1),Session.new(2002,"Rival",2)
 -- October 23 empty start: a new profile has no chickens; these checks assume the old three-Duck flock.
 for _,fixture in {a,b} do for _=1,3 do fixture:AddPet("Duck",1).investment=0 end end
 a.loaded,b.loaded=true,true
 local world={mode=false}
 function world:Position(plot) local p=Config.PlotPositions[plot];return Vector3.new(p[1],1.05,p[2]) end
 function world:IncomeFrame() return CFrame.new(0,1.05,0) end
 function world:ReturnPosition(session,_,slot) local x,z=Layout.Home(slot);return self:Position(session.plotIndex)+Vector3.new(x,0,z) end
 function world:PetPosition() return nil end
 function world:SetIncomeBusy() end
 function world:SetIncomeStatus() end
 function world:SetTerritoryOwner() end
 function world:SetCampBusy() end
 function world:SetOutpostBusy() end
 function world:SetHillMode(open) self.mode=open end
 function world:CampPosition(index,plot) return self:Position(plot).Unit*Config.CampRadii[index] end
 function world:CampFrame(index,plot) return CFrame.new(self:CampPosition(index,plot)) end
 local sessions={[a.userId]=a,[b.userId]=b}
 local battles=Battles.new(sessions,world)
 battles.isRealPlayer=function() return true end
 local hill=Hill.new(battles,world,sessions,0)
 return hill,battles,a,b,world
end

local function own(battles,session)
 battles.campOwners["income:1"]={userId=session.userId,name=session.name,location={income=true}}
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,detail=pcall(fn);table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
 end
 local H=Config.Hill
 test("Break locks the King only in the last seconds, then the Hill opens",function()
  local hill,battles,a=setup()
  assert(hill.phase=="Break" and not battles:IncomeSummary(a,0),"Hill site visible during break")
  assert(not hill:KingLock(1),"King locked too early")
  assert(hill:KingLock(H.FirstBreakSeconds-H.KingLockSeconds+1),"King not locked before the round")
  hill:Step(.1,H.FirstBreakSeconds+.1)
  assert(hill.phase=="Open" and battles.hillOpen and battles:IncomeSummary(a,H.FirstBreakSeconds+.1),"Hill did not open")
  return "Break, King lock window and opening work"
 end)
 test("A King fight in progress delays the opening",function()
  local hill,battles=setup()
  battles.campBusy["king:1"]="fight"
  hill:Step(.1,H.FirstBreakSeconds+1)
  assert(hill.phase=="Opening" and not battles.hillOpen,"Opened over a King fight")
  battles.campBusy["king:1"]=nil
  hill:Step(.1,H.FirstBreakSeconds+2)
  assert(hill.phase=="Open","Did not open after the arena cleared")
  return "Opening waits for an empty arena"
 end)
 test("Boost ramps 10% a minute to 50% and pays the Flock's shortfall plus the laying boost",function()
  local hill,battles,a,b=setup()
  hill:Step(.1,H.FirstBreakSeconds+.1)
  local t=H.FirstBreakSeconds+1
  own(battles,a);hill:Step(.1,t)
  assert(hill:Boost(a.userId,t)==0)
  assert(math.abs(hill:Boost(a.userId,t+60)-0.10)<1e-6,"1 minute boost")
  assert(hill:Boost(a.userId,t+600)==H.BoostMax,"Boost cap")
  -- October 20 Flock: only Flock layers earn; a Flock chicken out on the Hill is
  -- covered by a fill-in, and any shortfall is paid to the holder.
  local function sum(ids) local total=0;for _,id in ids do total+=Hill.PetRate(a,a.pets[id]) end;return total end
  local id=a:FlockIds()[1];a.awayPets={[id]=true}
  local laying=sum(a:LayingIds())
  local expected=math.max(0,sum(a:FlockIds())-laying)+laying*0.10
  assert(math.abs(hill:Rate(a,t+60)-expected)<1e-6,"Rate mismatch")
  assert(hill:Rate(a,t+60)>0 and hill:Rate(b,t+60)==0,"Only the holder is paid")
  return string.format("Rate at +10%% = %.2f/s on %.2f/s laying",expected,laying)
 end)
 test("Longest hold wins a Hill Roll; the round closes and the King returns",function()
  local hill,battles,a,b=setup()
  local t0=H.FirstBreakSeconds+.1
  hill:Step(.1,t0)
  own(battles,b);for i=1,100 do hill:Step(.1,t0+i*.1) end -- rival holds 10s
  own(battles,a);for i=1,300 do hill:Step(.1,t0+10+i*.1) end -- holder 30s
  local before=a:Count()
  hill:Step(.1,t0+H.RoundSeconds+1)
  assert(hill.phase=="Break" and not battles.hillOpen and not battles.campOwners["income:1"],"Round did not close")
  assert(a.hillWins==1 and b.hillWins==0 and a:Count()==before+1 and a.hillRollCredits==0,"Winner reward")
  local granted
  for _,pet in a.pets do if pet.investment==0 and Catalog[pet.species].weight>0 then granted=pet end end
  assert(granted,"Hill Roll chicken missing or refundable")
  return "Winner received "..Catalog[granted.species].name
 end)
 test("Holds under the minimum win nothing",function()
  local hill,battles,a=setup()
  local t0=H.FirstBreakSeconds+.1
  hill:Step(.1,t0);own(battles,a);hill:Step(.1,t0+1)
  hill:Step(.1,t0+H.RoundSeconds+1)
  assert(a.hillWins==0,"Short hold won")
  return "Minimum hold enforced"
 end)
 test("Full flocks keep the reward; Champion arrives once at the win threshold",function()
  local hill,_,a=setup()
  a.hillWins=H.ChampionWins-1;a.hillRollCredits=1
  local limit=a:CollectionLimit()
  while a:Count()<limit do a:AddPet("Duck",1) end
  assert(#hill:Deliver(a)==0 and a.hillRollCredits==1,"Delivered into a full flock")
  local id=next(a.pets);a.pets[id]=nil
  a.hillWins=H.ChampionWins
  local granted=hill:Deliver(a)
  assert(#granted==1 and a.hillRollCredits==0,"Credit not delivered first")
  local id2=next(a.pets);a.pets[id2]=nil
  granted=hill:Deliver(a)
  assert(granted[1]==H.ChampionSpecies and a.hillChampion,"Champion missing")
  local id3=next(a.pets);a.pets[id3]=nil
  assert(#hill:Deliver(a)==0,"Champion granted twice")
  return "Deferred rewards and a single Champion"
 end)
 test("Hill progress saves and old saves load as zero",function()
  local a=Session.new(2003,"Saver",1)
  a.hillWins,a.hillRollCredits,a.hillChampion=7,2,true
  local data=a:ToData()
  local b=Session.new(2003,"Saver",1)
  assert(b:LoadData(data))
  assert(b.hillWins==7 and b.hillRollCredits==2 and b.hillChampion==true,"Round trip")
  data.hillWins,data.hillRollCredits,data.hillChampion=nil,nil,nil
  local c=Session.new(2003,"Saver",1)
  assert(c:LoadData(data) and c.hillWins==0 and c.hillRollCredits==0 and c.hillChampion==false,"Old save")
  data.hillChampion="yes"
  assert(not Session.new(2003,"Saver",1):LoadData(data),"Malformed accepted")
  return "Additive save fields"
 end)
 test("First-time film: due once when a round opens, saved, never for Hill winners",function()
  local hill,_,a,b=setup()
  a.kingCleared=true
  b.kingCleared,b.hillWins=true,1
  local t0=H.FirstBreakSeconds+.1
  hill:Step(.1,t0)
  assert(hill.phase=="Open","Hill did not open")
  assert(hill:Snapshot(a,t0).intro==true and a.banner=="","Eligible player not due, or also toasted")
  assert(hill:Snapshot(b,t0).intro==false and b.banner~="","Hill winner due, or not toasted")
  a.tutorial.hillIntroSeen=true
  assert(hill:Snapshot(a,t0).intro==false,"Seen film still due")
  local data=a:ToData()
  local saved=Session.new(a.userId,a.name,1)
  assert(saved:LoadData(data) and saved.tutorial.hillIntroSeen==true,"Flag not saved")
  data.tutorial.hillIntroSeen=nil
  local old=Session.new(a.userId,a.name,1)
  assert(old:LoadData(data) and old.tutorial.hillIntroSeen==false,"Old save")
  a.tutorial.hillIntroSeen=false
  hill:Step(.1,t0+H.RoundSeconds+1)
  assert(hill.phase=="Break" and hill:Snapshot(a,t0+H.RoundSeconds+1).intro==false,"Due during a break")
  return "Due on open without the toast, saved, additive, cleared at the break"
 end)
 test("Hill Champion is never rolled or sold in crates",function()
  local d=Catalog[H.ChampionSpecies]
  assert(d and d.weight==0 and d.hillExclusive and d.rarity=="Mythic" and table.find(Catalog.Order,H.ChampionSpecies))
  return "Mythic, weight 0, Index-listed"
 end)
 return results
end
return Checks
