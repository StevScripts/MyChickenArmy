-- Fresh Edit-only fake sessions; no profiles or authored-world writes.
local loaded={}
local function fresh(module)
	if loaded[module] then return loaded[module] end
	local run=assert(loadstring(module.Source,module.Name))
	setfenv(run,setmetatable({script=module,require=fresh},{__index=getfenv()}))
	local value=run();loaded[module]=value;return value
end
local Eggs=fresh(game.ServerStorage.PetRoll.EggService)
local Rover=fresh(game.ServerStorage.PetRoll.EggRover)
local Config=fresh(game.ReplicatedStorage.PetRoll.Shared.VacuumConfig)
local checks={}
local pad=Instance.new("Part")
pad.Size=Vector3.new(8,1,8);pad.CFrame=CFrame.new(-23,0,-9)
local session={userId=-997,plotIndex=1,pets={},eggCarry={count=0,value=0},tutorial={},
	coins=0,entitlements={},automatic=true}
function session:AutomaticEnabled() return self.automatic end
function session:EarnedAmount(value) return value end
function session:Credit(value) self.coins+=value;return value end
function session:Touch() end
local world={}
function world:EggDeposit() return pad,session.userId end
function world:PlotFrame() return CFrame.identity end
local eggs=Eggs.new(world)
local yard=eggs:Yard(session)
local rover=Rover.new("fixture",CFrame.identity,1,pad,0)
yard.rover=rover
local function expect(name,condition) assert(condition,name);table.insert(checks,name) end
local function drop(id,distance,now)
	local at=rover:Nozzle()+Vector3.new(distance,0,0)
	local d={id=id,value=10,stack=1,x=at.X,y=at.Y-0.8,z=at.Z,readyAt=now,born=now}
	table.insert(yard.drops,d);return d
end
local ok,err=xpcall(function()
	expect("minimum radius is nine studs",Config.SuctionRadius==9 and rover.suctionRadius>=9)
	expect("parked rover is not running a pickup cycle",not rover:CanCollect(0))
	rover:BeginSweep()
	expect("suction starts on outbound approach",rover.waypoint==1 and rover:CanCollect(0))
	local first=drop("outbound",8,0)
	local far=drop("outside",rover.suctionRadius+1,0)
	eggs:Collect(session,nil,0)
	expect("outbound egg beyond old radius is claimed",first.collector=="rover")
	expect("eggs beyond radius remain unclaimed",far.claimAt==nil)
	eggs:Collect(session,nil,0.1)
	expect("repeated pickup does not duplicate pending cargo",rover.pendingCount==1)
	table.remove(yard.drops,2)
	eggs:SettleClaims(session,yard,2,false)
	expect("outbound pickup settles to cargo only",rover.cargoValue==10 and session.coins==0)
	rover:BeginReturn()
	local returning=drop("return",8,2)
	eggs:Collect(session,nil,2)
	expect("return route still collects",returning.collector=="rover")
	rover.position=rover.dock;rover.state="Unloading";rover.unloadAt=3
	local dock=drop("dock",8,2)
	eggs:Collect(session,nil,2.2)
	expect("dock settling window still collects",dock.collector=="rover")
	expect("pending flights delay unloading",not rover:ReadyToUnload(3))
	expect("dock intake closes so unload cannot starve",not rover:CanCollect(3))
	eggs:SettleClaims(session,yard,4,false)
	expect("all travel pickups settle exactly once",rover.pendingCount==0 and rover.cargoValue==30)
	eggs:UpdateRover(session,yard,0.1,4)
	expect("dock deposits full travel cargo once",session.coins==30 and rover.cargoCount==0 and rover.state=="Idle")
	eggs:UpdateRover(session,yard,0.1,4.1)
	expect("repeated dock update cannot pay twice",session.coins==30)
	rover:BeginSweep();rover.enabled=false
	expect("disabled rover cannot collect",not rover:CanCollect(5))
end,debug.traceback)
pad:Destroy()
assert(ok,err)
return checks
