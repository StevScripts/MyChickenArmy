--!strict
-- Isolated money and persistence checks: no players or DataStore writes.
return function()
 local Server=game.ServerStorage.PetRoll
 local Session=require(Server.PlayerSession)
 local Eggs=require(Server.EggService)
 local Config=require(game.ReplicatedStorage.PetRoll.Shared.Config)
 local session=Session.new(-817,"Egg fixture",1);session.loaded=true
 local pad=Instance.new("Part");pad.Anchored=true;pad.Size=Vector3.new(7,1,4);pad.CFrame=CFrame.new(0,1,0)*CFrame.Angles(0,0.7,0)
 local owner=session.userId
 local world={EggDeposit=function(_,index) return if index==1 then pad else nil,owner end}
 local eggs=Eggs.new(world)
 local ok,result=pcall(function()
  local initial=session.coins
  local yard=eggs:Yard(session)
  eggs:Pay(session,yard,{id="one",value=123,stack=3},0)
  assert(session.coins==initial and session.eggCarry.count==3 and session.eggCarry.value==123,"Pickup credited cash before deposit")
  assert(not eggs:Deposit(session,Vector3.new(30,4,0),1),"Remote deposit accepted")
  owner=999;assert(not eggs:Deposit(session,pad.Position+Vector3.new(0,3,0),1),"Wrong owner accepted");owner=session.userId
  session.saveLost=true;assert(not eggs:Deposit(session,pad.Position,1),"Lost session accepted");session.saveLost=nil
  local saved=session:ToData();session.enemyKills=4;saved.enemyKills=4
  local restored=Session.new(-818,"Restore",1)
  assert(restored:LoadData(saved),"Carried egg save rejected")
  assert(restored.eggCarry.count==3 and restored.eggCarry.value==123 and restored.enemyKills==4,"Save lost eggs or defeats")
  assert(eggs:Deposit(session,pad.Position+Vector3.new(0,3,0),2),"On-pad deposit rejected")
  assert(session.coins==initial+123 and session.eggCarry.count==0 and session.eggCarry.value==0,"Deposit wrong payout")
  assert(not eggs:Deposit(session,pad.Position,2.1) and session.coins==initial+123,"Repeated overlap paid twice")
  -- Eggs landing right after a sale wait out the 0.5 s debounce, then pay once.
  eggs:Pay(session,yard,{id="late",value=40,stack=1},2.2)
  assert(not eggs:Deposit(session,pad.Position,2.3) and session.eggCarry.value==40,"Debounce paid a second sale early")
  assert(eggs:Deposit(session,pad.Position,2.55) and session.coins==initial+163 and session.eggCarry.value==0,"Debounced eggs never paid")
  local bad=table.clone(saved);bad.eggCarry={count=1,value=0/0}
  assert(not restored:LoadData(bad),"NaN bag accepted")
  bad.eggCarry={count=0,value=10};assert(not restored:LoadData(bad),"Inconsistent bag accepted")
  local old=table.clone(saved);old.eggCarry=nil;old.enemyKills=nil
  assert(restored:LoadData(old) and restored.eggCarry.value==0 and restored.enemyKills==0,"Older save compatibility lost")
  local before=session.coins
  table.insert(yard.drops,{id="flying",claimAt=2,value=55,stack=2})
  eggs:Release(session);eggs:Release(session)
  assert(session.coins==before and session.eggCarry.value==55 and session.eggCarry.count==2,"Disconnect pickup lost or paid twice")
  -- October 20 hand vacuum: a split stack keeps every Coin, vacuum claims settle into
  -- the vacuum's own cargo, and the pad sells the bag and the vacuum as one sale.
  local stack={id="stack",petId="p",species="Duck",x=0,y=0,z=0,value=41,stack=10,born=0,readyAt=0}
  table.insert(yard.drops,stack)
  local part=eggs:Split(yard,stack,3)
  assert(part.stack==3 and stack.stack==7 and part.value+stack.value==41 and part.id~=stack.id,"Split lost or made value")
  eggs:Claim(yard,part,4,"vacuum",Vector3.zero)
  yard.vacuumPending,yard.vacuumPendingValue=3,part.value
  eggs:SettleClaims(session,yard,10,false)
  assert(session.vacuumCargo.count==3 and session.vacuumCargo.value==part.value and yard.vacuumPending==0,"Vacuum claim missed its cargo")
  local bagCount,bagValue,coinsBefore=session.eggCarry.count,session.eggCarry.value,session.coins
  assert(eggs:Deposit(session,pad.Position,11),"Bag and vacuum sale rejected")
  assert(session.coins==coinsBefore+bagValue+part.value and session.eggCarry.count==0 and session.vacuumCargo.count==0,"Pad sale missed the vacuum")
  -- Release above dropped the old yard; the sale is recorded in the fresh one.
  local sale=eggs:Yard(session).deposit
  assert(sale and sale.collector=="vacuum" and sale.count==bagCount+3,"Vacuum sale receipt")
  local legacy=Session.new(-819,"Old plot",2);legacy.loaded=true;legacy.eggCarry={count=2,value=55}
  local legacyCoins=legacy.coins;eggs:Pay(legacy,eggs:Yard(legacy),{id="legacy",value=10,stack=1},3)
  assert(legacy.coins==legacyCoins+65 and legacy.eggCarry.value==0,"Old plot strands carried eggs")
  return "18 deposit, vacuum, ownership, persistence, debounce and recovery checks passed"
 end)
 pad:Destroy();eggs:Destroy()
 assert(ok,result)
 return result
end
