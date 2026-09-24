-- Disposable Edit checks. No real DataStore, player, purchase or Play session.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local loaded={}
local function fresh(module)
	if loaded[module] then return loaded[module] end
	local fn,err=loadstring(module.Source,"="..module.Name);assert(fn,err)
	setfenv(fn,setmetatable({script=module,require=function(dependency)
		if typeof(dependency)=="Instance" and dependency:IsA("ModuleScript") then return fresh(dependency) end
		return require(dependency)
	end},{__index=getfenv()}))
	local result=fn();loaded[module]=result;return result
end
local root=game.ServerStorage.PetRoll
local Session,Data,Offline=fresh(root.PlayerSession),fresh(root.DataService),fresh(root.OfflineCash)
local Http=game:GetService("HttpService")
local function copy(v) return if v==nil then nil else Http:JSONDecode(Http:JSONEncode(v)) end
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a).." ~= "..tostring(b)) end
local passed={}
local function check(name,fn) fn();table.insert(passed,name) end
local function session() return Session.new(123456,"Offline fixture",1) end
local function setup(at,rate)
	local s=session();local payload=s:ToData();payload.offlineCash={at=at or 1000,rate=rate or 0.32}
	payload.eggCarry={count=3,value=99}
	payload.eggProcessor.batches={{count=10,value=101}}
	payload.eggProcessor.readyValue=55
	local store={value={schemaVersion=1,data=payload,updatedAt=1000},calls=0}
	function store:UpdateAsync(_,callback)
		self.calls+=1
		local nextValue=callback(copy(self.value))
		if self.doubleCallback then nextValue=callback(copy(self.value)) end
		if self.calls>=2 and self.calls<=4 and self.failSave then
			if self.commitThenFail and nextValue~=nil then self.value=copy(nextValue) end
			error("simulated unavailable response")
		end
		if nextValue~=nil then self.value=copy(nextValue) end
		return copy(nextValue)
	end
	local clock={now=1000+28800}
	local data=Data.new(store,function() return clock.now end,{wait=function() end})
	return s,store,clock,data
end
check("starter rate and eight-hour cap",function()
	near(Offline.Rate(session()),0.32)
	assert(Offline.Reward({at=1000,rate=0.32},1000+28800,2400).amount==9216)
	assert(Offline.Reward({at=1000,rate=0.32},1000+86400,2400).amount==9216)
end)
check("minimum, future clock, no-history and fractional rounding",function()
	assert(Offline.Reward({at=1000,rate=0.32},1059,0).amount==0)
	assert(Offline.Reward({at=1000,rate=0.32},1060,0).amount==19)
	assert(Offline.Reward({at=2000,rate=10},1000,0).amount==0)
	assert(Offline.Reward({at=0,rate=10},30000,0).amount==0)
end)
check("verified bonuses apply once and seller limits dense flocks",function()
	local s=session();s.entitlements.DoubleCash=true;near(Offline.Rate(s),0.64)
	s.entitlements.DoubleEggSpawn=true;near(Offline.Rate(s),1.28)
	s=session();s.pets={};for _=1,10 do s:AddPet("Bucket",1) end
	near(Offline.Rate(s),2.688)
	s.eggProcessor.level=1;near(Offline.Rate(s),5.376)
	s.eggProcessor.level=2;near(Offline.Rate(s),5.6)
	s.armyState="Fight";for id in s.pets do s.awayPets[id]=true end
	near(Offline.Rate(s),5.6)
end)
check("old saves migrate without a retroactive windfall",function()
	local s,store,_,data=setup();store.value.data.dataRevision=9;store.value.data.offlineCash=nil
	assert(data:Load(s));assert(s.coins==2400 and s.offlineCashReceipt==nil)
	assert(store.value.data.dataRevision==10 and store.value.data.offlineCash.at>0)
end)
check("malformed offline data fails before any wallet replacement",function()
	local s=session();local p=s:ToData()
	for _,bad in {{at=0/0,rate=1},{at=100,rate=math.huge},{at=-1,rate=1},{at=100.5,rate=1},{at=1,rate=-1}} do
		p.offlineCash=bad;assert(not s:LoadData(p));assert(s.coins==2400)
	end
end)
check("reward is durable before loaded and leaves egg balances untouched",function()
	local s,store,clock,data=setup()
	local update=store.UpdateAsync
	function store:UpdateAsync(key,callback) assert(not s.loaded);return update(self,key,callback) end
	assert(data:Load(s));assert(s.loaded and s.coins==11616)
	assert(store.value.data.coins==s.coins and s.offlineCashReceipt.amount==9216)
	assert(store.value.data.offlineCash.at==clock.now+180)
	assert(s.eggCarry.value==99 and s.eggProcessor.readyValue==55 and s.eggProcessor.batches[1].value==101)
	local state=s:Snapshot(0);assert(state.offlineCash.amount==9216)
	state.offlineCash.amount=1;assert(s.offlineCashReceipt.amount==9216)
end)
check("live lease excludes a second server",function()
	local s,store,clock,data=setup();assert(data:Load(s))
	local second=Data.new(store,function() return clock.now end,{wait=function() end})
	local other=session();assert(not second:Load(other));assert(not other.loaded)
	assert(store.value.data.coins==11616)
end)
check("clean release starts exactly at departure; quick rejoin cannot replay",function()
	local s,store,clock,data=setup();assert(data:Load(s));clock.now+=5
	data:Release(s);assert(store.value.lease==nil and store.value.data.offlineCash.at==clock.now)
	local nextData=Data.new(store,function() return clock.now end,{wait=function() end})
	local other=session();assert(nextData:Load(other));assert(other.coins==11616 and other.offlineCashReceipt==nil)
end)
check("UpdateAsync callback replay pays once",function()
	local s,store,_,data=setup();store.doubleCallback=true
	assert(data:Load(s));assert(store.value.data.coins==11616)
end)
check("failed reward save blocks session and can recover on next join",function()
	local s,store,clock,data=setup();store.failSave=true
	assert(not data:Load(s));assert(not s.loaded and not s.offlineCashReceipt and s.coins==2400)
	assert(store.value.data.coins==2400 and store.value.data.offlineCash.at==1000)
	store.failSave=false
	local other=session();local nextData=Data.new(store,function() return clock.now end,{wait=function() end})
	assert(nextData:Load(other));assert(other.coins==11616)
end)
check("committed write with lost response cannot pay twice on recovery",function()
	local s,store,clock,data=setup();store.failSave=true;store.commitThenFail=true
	assert(not data:Load(s));assert(not s.loaded and store.value.data.coins==11616)
	store.failSave=false
	local other=session();local nextData=Data.new(store,function() return clock.now end,{wait=function() end})
	assert(nextData:Load(other));assert(other.coins==11616 and other.offlineCashReceipt==nil)
end)
check("crash recovery excludes the possibly-active lease window",function()
	local s,store,clock,data=setup();assert(data:Load(s))
	clock.now+=180+3600
	local other=session();local nextData=Data.new(store,function() return clock.now end,{wait=function() end})
	assert(nextData:Load(other));assert(other.coins==11616+1152)
	assert(other.offlineCashReceipt.awaySeconds==3600)
end)
check("wallet ceiling is preserved",function()
	local s,store,_,data=setup();store.value.data.coins=1e12-5
	assert(data:Load(s));assert(s.coins==1e12 and s.offlineCashReceipt.amount==5)
end)
check("previous-session bonus is not retroactively changed on login",function()
	local s,store,_,data=setup(1000,1.28)
	assert(next(s.entitlements)==nil);assert(data:Load(s))
	assert(s.offlineCashReceipt.amount==36864 and s.coins==39264)
end)
local balance={}
for _,row in {
	{name="Starter",species={"Duck","Duck","Mallard"},seller=0,value=0,speed=0},
	{name="Ten Robo-Clucks, base seller",species="Bucket",count=10,seller=0,value=0,speed=0},
	{name="Ten Robo-Clucks, 8 eggs/s seller",species="Bucket",count=10,seller=2,value=0,speed=0},
	{name="Twenty Magma, value 2, speed 2",species="Knight",count=20,seller=3,value=2,speed=2},
	{name="Forty Shadow, max coin upgrades",species="Wizard",count=40,seller=4,value=4,speed=4},
	{name="Forty Shadow, both existing 2x passes",species="Wizard",count=40,seller=4,value=4,speed=4,passes=true},
} do
	local s=session();s.pets={}
	if type(row.species)=="table" then for _,sp in row.species do s:AddPet(sp,1) end
	else for _=1,row.count do s:AddPet(row.species,1) end end
	s.eggProcessor.level=row.seller;s.incomeLevel=row.value;s.eggSpeedLevel=row.speed
	if row.passes then s.entitlements.DoubleCash=true;s.entitlements.DoubleEggSpawn=true end
	local rate=Offline.Rate(s);local payouts={}
	for _,seconds in {60,600,3600,28800,86400} do
		payouts[tostring(seconds)]=Offline.Reward({at=1000,rate=rate},1000+seconds,0).amount
	end
	table.insert(balance,{name=row.name,rate=rate,payouts=payouts})
end
return {passed=passed,count=#passed,balance=balance,realDataStoreCalls=0}
