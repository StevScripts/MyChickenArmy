-- Admin commands (AdminService). Fake actors and sessions only: no real
-- players, DataStores, bans or live-world changes.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Battles=require(Server.BattleService)
local AdminService=require(Server.AdminService)
local AdminConfig=require(Server.AdminConfig)
local Catalog=require(Shared.PetCatalog)
local ResearchCatalog=require(Shared.ResearchCatalog)
local Config=require(Shared.Config)
local Checks={}

local OWNER=AdminConfig.Owners[1]
local function actor(userId,name)
	return {UserId=userId,Name=name,DisplayName=name,Character=nil}
end
local function setup()
	local owner=Session.new(OWNER,"Owner",1);owner.loaded=true
	local friend=Session.new(-951,"Friend",2);friend.loaded=true
	local sessions={[OWNER]=owner,[-951]=friend}
	local world={}
	function world:SetTerritoryOwner() end
	local server={sessions=sessions,world=world,battles=Battles.new(sessions,world),pushed={}}
	function server:PushState(player) table.insert(self.pushed,player.UserId) end
	local admin=AdminService.new(server)
	return admin,owner,friend,server
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,why=pcall(fn)
		table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
	end

	test("Only owners and admins can run commands",function()
		local admin=setup()
		assert(admin:Rank(actor(OWNER,"Owner"))=="Owner")
		local ok,why=admin:Run(actor(-951,"Friend"),"cash me 1m")
		assert(not ok and why:find("admins only",1,true))
		assert(admin:Rank(actor(-951,"Friend"))==nil)
	end)

	test("Cash accepts k/m/b amounts, can take cash and never goes negative",function()
		local admin,owner=setup()
		local me=actor(OWNER,"Owner")
		local start=owner.coins
		assert(admin:Run(me,"cash me 1.5m"));assert(owner.coins==start+1500000)
		admin.lastCommand={}
		assert(admin:Run(me,"cash me -250k"));assert(owner.coins==start+1250000)
		admin.lastCommand={}
		assert(admin:Run(me,"setcash me 10"));admin.lastCommand={}
		assert(admin:Run(me,"cash me -1m"));assert(owner.coins==0)
		admin.lastCommand={}
		local ok=admin:Run(me,"cash me lots");assert(not ok)
	end)

	test("Chickens respect species names, levels and the flock limit; assisted is flagged",function()
		local admin,owner=setup()
		local me=actor(OWNER,"Owner")
		local species=Catalog.Order[2]
		local before=owner:Count()
		assert(admin:Run(me,"chicken me "..Catalog[species].name:gsub(" ","").." 4 2"))
		assert(owner:Count()==before+2 and owner.adminAssisted)
		local found=0
		for _,pet in owner.pets do if pet.species==species and pet.level==4 then found+=1 end end
		assert(found==2)
		admin.lastCommand={}
		assert(admin:Run(me,"chicken me "..species.." 1 25"))
		assert(owner:Count()==owner:CollectionLimit(),"Flock limit exceeded")
		admin.lastCommand={}
		assert(not admin:Run(me,"chicken me notachicken"))
		admin.lastCommand={}
		assert(not admin:Run(me,"chicken me "..species.." 99"))
	end)

	test("Research, camps, King, army size and rolls apply to the saved session",function()
		local admin,owner=setup()
		local me=actor(OWNER,"Owner")
		assert(admin:Run(me,"research me all"))
		for _,id in ResearchCatalog.Order do assert(owner.research.completed[id],id) end
		assert(owner.researchEffects.holdCap==10 and owner.fusionUnlocked)
		admin.lastCommand={};assert(admin:Run(me,"king me"))
		assert(owner.kingCleared and owner.firstWins[1] and owner.firstWins[3] and owner.tutorial.wonCamp)
		admin.lastCommand={};assert(admin:Run(me,"army me 7") and owner.capacity==7)
		admin.lastCommand={};assert(not admin:Run(me,"army me 99"))
		owner.rollReadyAt=1e9
		admin.lastCommand={};assert(admin:Run(me,"roll me "..Catalog.Order[1]))
		assert(owner.rollReadyAt==0 and owner.debugNext==Catalog.Order[1])
		local data=owner:ToData()
		local loaded=Session.new(OWNER,"Owner",1)
		assert(loaded:LoadData(data))
		assert(loaded.kingCleared and loaded.capacity==7 and loaded.adminAssisted and loaded.research.completed.H2)
	end)

	test("Targets reach other players' sessions; unknown names fail cleanly",function()
		local admin,_,friend=setup()
		local me=actor(OWNER,"Owner")
		local ok,why=admin:Run(me,"cash nobody 5")
		assert(not ok and why:find("No player",1,true))
		-- Players:GetPlayers() is empty in this fixture, so "all" changes nobody.
		admin.lastCommand={}
		ok=admin:Run(me,"cash all 5");assert(not ok and friend.coins==Config.StartingCoins)
	end)

	test("Owner-only commands stay owner-only; admins can be added and removed",function()
		local admin,_,_,server=setup()
		local me=actor(OWNER,"Owner")
		assert(admin:Run(me,"admin add 900000001"))
		local friend=actor(900000001,"Friend")
		assert(admin:Rank(friend)=="Admin")
		admin.lastCommand={}
		local ok,why=admin:Run(friend,"admin add 900000002");assert(not ok and why:find("Only owners",1,true))
		admin.lastCommand={}
		ok,why=admin:Run(friend,"ban 900000003 perm");assert(not ok and why:find("Only owners",1,true))
		admin.lastCommand={}
		-- Admin rank passes; this fake admin simply has no loaded save.
		ok,why=admin:Run(friend,"cash me 5");assert(not ok and why:find("not loaded",1,true))
		admin.lastCommand={}
		assert(admin:Run(me,"admin remove 900000001") and admin:Rank(friend)==nil)
		admin.lastCommand={}
		ok,why=admin:Run(me,"ban "..OWNER.." perm");assert(not ok and why:find("can't ban",1,true))
		assert(#server.pushed==0) -- Neither test user is in the server.
	end)

	test("Help, logs and errors",function()
		local admin=setup()
		local me=actor(OWNER,"Owner")
		local ok,text=admin:Run(me,"help");assert(ok and text:find("coins <target> <amount>",1,true) and text:find("ban",1,true))
		admin.lastCommand={}
		ok,text=admin:Run(me,"help cash");assert(ok and text:find("Give coins",1,true))
		admin.lastCommand={}
		assert(not admin:Run(me,"flyaway"))
		admin.lastCommand={}
		assert(admin:Run(me,"cash me 1"))
		admin.lastCommand={}
		ok,text=admin:Run(me,"logs");assert(ok and text:find("cash me 1",1,true))
		ok,text=admin:Run(me,"cash me 1");assert(not ok and text:find("Slow down",1,true))
	end)
	return results
end
return Checks
