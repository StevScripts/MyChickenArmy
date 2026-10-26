-- Disposable sessions, characters and actor stubs; no saved profiles or live world writes.
local Server=game.ServerStorage.PetRoll
local Session=require(Server.PlayerSession)
local Commands=require(Server.ArmyCommandService)
local Battles=require(Server.BattleService)
local Research=require(game.ReplicatedStorage.PetRoll.Shared.ResearchRules)
local Checks={}
local fixtures={}

local function setup(unlocked)
	local s=Session.new(-9286,"Army command fixture",1);s.loaded=true
	-- October 23 empty start: a new profile has no chickens; these checks assume the old three-Duck flock.
	for _=1,3 do s:AddPet("Duck",1).investment=0 end
	if unlocked~=false then s.research.completed.CallArmy=true;s.researchEffects=Research.Effects(s.research) end
	s.pets,s.slots={},{}
	local ids={}
	for _=1,5 do table.insert(ids,s:AddPet("Duck",1).id) end
	s.pets[ids[1]].giantSize=22;s.pets[ids[2]].giantSize=21
	s.armySelection={ids[1],ids[3],ids[4]};s:RefreshArmy()
	local root=Instance.new("Folder");table.insert(fixtures,root)
	local home=Instance.new("Folder");home.Parent=root
	local world={root=root,plots={{actors={},pets=home}},created=0}
	function world:Position() return Vector3.new(10000,1,-100) end
	function world:ReturnPosition(_,id) return Vector3.new(10000+(table.find(ids,id) or 0)*4,1,-100) end
	function world:SpawnFrame() return CFrame.new(10000,5,-90) end
	function world:CampPosition(i) return Vector3.new(10000,1,i*80) end
	function world:CampFrame(i) return CFrame.new(self:CampPosition(i)) end
	function world:OutpostFrame() return CFrame.new(10200,1,80) end
	function world:SetCampBusy() end
	function world:SetOutpostBusy() end
	function world:PetPosition(_,id) local actor=self.plots[1].actors[id];return actor and actor:Position() end
	function world:RestoreActor(_,id,actor)
		assert(not actor.destroyed,"Restoring a destroyed actor")
		local previous=self.plots[1].actors[id]
		assert(not previous or previous==actor,"Duplicate chicken ownership")
		actor:SetParent(home);actor:Stop();self.plots[1].actors[id]=actor
		return true
	end
	function world:TakeActor(_,id)
		local actor=self.plots[1].actors[id];self.plots[1].actors[id]=nil;return actor
	end
	function world:UpdateSession(session)
		for id in session.pets do if session:IsPetHome(id) and not self.plots[1].actors[id] then
			self.created+=1
			local model=Instance.new("Model");model.Name=id;model.Parent=home
			local actor={model=model,position=self:ReturnPosition(session,id),progressAt=0}
			function actor:SetParent(parent) self.model.Parent=parent end
			function actor:Stop() self.target=nil end
			function actor:Position() return self.position end
			function actor:Teleport(foot) self.position=foot;self:Stop();return true end
			function actor:Step() return "ready" end
			function actor:CanStandAt() return true end
			function actor:MoveTo(foot,speed) self.target=foot;self.speed=speed end
			function actor:Follow(foot,velocity,speed)
				self.target=foot;self.velocity=velocity;self.speed=speed;self.followCalls=(self.followCalls or 0)+1
			end
			function actor:Destroy() self.destroyed=true;self.model:Destroy() end
			self.plots[1].actors[id]=actor
		end end
	end
	world:UpdateSession(s)
	local character=Instance.new("Model");character.Parent=root
	local part=Instance.new("Part");part.Name="HumanoidRootPart";part.Anchored=true;part.CFrame=world:SpawnFrame();part.Parent=character
	character.PrimaryPart=part
	local hum=Instance.new("Humanoid");hum.Parent=character
	local player={Character=character}
	local sessions={[s.userId]=s}
	local battleWorld=table.clone(world);battleWorld.root=nil -- Keep encounter actors in this fixture's explicit stubs.
	local battle=Battles.new(sessions,battleWorld)
	local command=Commands.new(world,battle,sessions)
	return s,ids,world,battle,command,player
end

function Checks.Run()
	local results={}
	local function check(name,fn)
		local ok,why=pcall(fn)
		for _,root in fixtures do root:Destroy() end;table.clear(fixtures)
		table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
	end
	-- October 20 overhaul: Call Army is free for everyone (no research).
	check("Call Army is free without research",function()
		local s,_,w,_,c,p=setup(false)
		assert(c:CallArmy(p,s,1) and s.armyState=="Following" and c.following[s.userId] and w.created==5)
	end)
	check("Attacks and My Base recall work without research",function()
		local s,ids,w,b,c,p=setup(false)
		assert(c:Attack(s,"camp:1",1));local encounter=b.battles[s.outgoing]
		assert(encounter)
		assert(b.battles[encounter.id]==encounter and s.outgoing==encounter.id)
		assert(c:GoBase(p,s,3))
		assert(not s.outgoing and not b.battles[encounter.id] and s.armyState=="Home")
		assert(p.Character:GetPivot().Position==w:SpawnFrame().Position and s:Count()==5)
		for _,id in ids do assert(w.plots[1].actors[id] and s:IsPetHome(id)) end
	end)
	check("Call transfers only selected actors; repeats preserve identity and one Colossal",function()
		local s,ids,w,b,c,p=setup();local original=table.clone(w.plots[1].actors)
		assert(c:CallArmy(p,s,1));local record=c.following[s.userId]
		assert(s.armyState=="Following" and #record.ids==3 and not record.actors[ids[2]])
		for _,id in s:BestPetIds() do assert(record.actors[id]==original[id] and not w.plots[1].actors[id] and not s:IsPetHome(id)) end
		assert(not c:CallArmy(p,s,1.1));assert(c:CallArmy(p,s,2))
		assert(c.following[s.userId]==record and w.created==5 and s.pets[ids[1]].giantSize==22)
	end)
	check("Selection swaps return old Colossal and transfer its replacement once",function()
		local s,ids,w,b,c,p=setup();assert(c:CallArmy(p,s,1))
		local old=c.following[s.userId].actors[ids[1]]
		s.armySelection={ids[2],ids[3]};c:Sync(s)
		local r=c.following[s.userId]
		assert(#r.ids==2 and not r.actors[ids[1]] and r.actors[ids[2]])
		assert(w.plots[1].actors[ids[1]]==old and old:Position()==w:ReturnPosition(s,ids[1]) and s:IsPetHome(ids[1]))
		assert(w.created==5)
		s.armySelection={};c:Sync(s)
		assert(not c.following[s.userId] and s.armyState=="Home" and not next(s.awayPets))
	end)
	check("Following retargets on consecutive frames between membership refreshes",function()
		local s,ids,w,b,c,p=setup();assert(c:CallArmy(p,s,1))
		c:Step(10)
		local actor=c.following[s.userId].actors[ids[1]];local before=actor.target
		p.Character:PivotTo(p.Character:GetPivot()+Vector3.new(1,0,0))
		c:Step(10+1/60)
		assert(actor.followCalls==2 and actor.target.X==before.X+1,"Steering retained the 0.2-second throttle")
		assert(w.created==5 and s.armyState=="Following")
	end)
	check("Giant follows behind a partial regular row without changing selected slots",function()
		local s,ids,w,b,c,p=setup();local selected=table.clone(s:BestPetIds())
		assert(c:CallArmy(p,s,1));c:Step(10)
		local r=c.following[s.userId]
		assert(table.concat(s.slots,",")==table.concat(selected,","),"Following changed selected slots")
		assert(r.ids[1]==ids[3] and r.ids[2]==ids[4] and r.ids[3]==ids[1])
		local rear=r.frame:PointToObjectSpace(r.actors[ids[1]].target).Z
		for _,id in {ids[3],ids[4]} do
			local front=r.frame:PointToObjectSpace(r.actors[id].target).Z
			assert(rear>front,"Giant shares or precedes the regular row")
		end
		-- A selection change while already following must rebuild the same rule.
		s.armySelection={ids[1],ids[5]};c:Sync(s);c:Step(10.3)
		assert(r.ids[1]==ids[5] and r.ids[2]==ids[1])
		assert(r.offsets[ids[1]].Z>r.offsets[ids[5]].Z)
	end)
	check("Multiple Giant rows, all-Giant and all-regular squads keep centered stable formations",function()
		local s,ids,w,b,c,p=setup();s.capacity=8
		for _=1,3 do table.insert(ids,s:AddPet("Duck",1).id) end
		s.pets[ids[2]].giantSize=4;s.pets[ids[7]].giantSize=12
		s.armySelection={ids[1],ids[3],ids[2],ids[4],ids[5],ids[6],ids[7],ids[8]}
		assert(c:CallArmy(p,s,1));local r=c.following[s.userId]
		local lastRegular=math.max(r.offsets[ids[3]].Z,r.offsets[ids[8]].Z)
		for _,id in {ids[1],ids[2],ids[7]} do assert(r.offsets[id].Z>lastRegular) end
		assert(r.ids[6]==ids[1] and r.ids[7]==ids[2] and r.ids[8]==ids[7])
		-- Four Giants occupy two rows, with the last row centered.
		s.pets[ids[6]].giantSize=6;s.armySelection={ids[2],ids[7],ids[1],ids[6]};c:Sync(s)
		assert(r.offsets[ids[2]].Z==7 and r.offsets[ids[6]].Z>7 and r.offsets[ids[6]].X==0)
		for _,id in ids do s.pets[id].giantSize=nil end
		s.armySelection=table.clone(ids);c:Sync(s)
		local motion=require(game.ReplicatedStorage.PetRoll.Shared.FollowMotion)
		for ordinal,id in ids do assert(r.ids[ordinal]==id and r.offsets[id]==motion.Offset(ordinal,#ids,5.5)) end
	end)
	check("Base returns player, following squad and reserves without replacing their actors",function()
		local s,ids,w,b,c,p=setup();local original=table.clone(w.plots[1].actors)
		assert(c:CallArmy(p,s,1));p.Character:PivotTo(CFrame.new(11000,5,100))
		assert(c:GoBase(p,s,2));assert(not c:GoBase(p,s,2.1))
		assert(not c.following[s.userId] and s.armyState=="Home" and not next(s.awayPets))
		assert(p.Character:GetPivot().Position==w:SpawnFrame().Position)
		for _,id in ids do assert(w.plots[1].actors[id]==original[id] and original[id]:Position()==w:ReturnPosition(s,id)) end
		assert(w.created==5 and s:Count()==5)
	end)
	check("Invalid attack keeps following; valid attack starts from existing actor positions",function()
		local s,ids,w,b,c,p=setup();assert(c:CallArmy(p,s,1))
		local actor=c.following[s.userId].actors[ids[1]]
		actor.position=Vector3.new(10030,1,40)
		assert(not c:Attack(s,"invalid",2));assert(c.following[s.userId].actors[ids[1]]==actor)
		assert(c:Attack(s,"camp:1",3));assert(not c.following[s.userId] and s.armyState=="Traveling")
		local battle=b.battles[s.outgoing]
		for _,unit in battle.units do if unit.petId==ids[1] then assert(unit.x==10030 and unit.z==40) end end
	end)
	check("Dead character and empty selection reject safely; death returns followers home",function()
		local s,ids,w,b,c,p=setup();local hum=p.Character:FindFirstChildOfClass("Humanoid")
		hum.Health=0;assert(not c:CallArmy(p,s,1) and not c:GoBase(p,s,1))
		hum.Health=100;s.armySelection={};assert(not c:CallArmy(p,s,2))
		s.armySelection={ids[1]};assert(c:CallArmy(p,s,3));p.Character=nil;c:Step(4)
		assert(not c.following[s.userId] and s.armyState=="Home" and w.created==5)
	end)
	check("Recall cancels only the outgoing encounter, transfers its actors and awards no conquest",function()
		local s,ids,w,b,c,p=setup();assert(b:Attack(s,"camp:1",1))
		local battle=b.battles[s.outgoing];local held={};local original={}
		for _,unit in battle.units do if unit.side=="A" and unit.petId then
			local actor=w:TakeActor(1,unit.petId);actor.position=Vector3.new(10020,1,60)
			held[unit.id]=actor;original[unit.petId]=actor
		end end
		battle.actors={TakeUnit=function(_,id) local a=held[id];held[id]=nil;return a end,
			Destroy=function() assert(not next(held),"Destroyed owned actors before transferring") end}
		local coins=s.coins;assert(c:CallArmy(p,s,2))
		assert(not b.battles[battle.id] and not s.outgoing and not s.firstWins[1] and s.coins==coins)
		for id,actor in original do assert(c.following[s.userId].actors[id]==actor and actor:Position()==Vector3.new(10020,1,60)) end
	end)
	check("Territory defender recall leaves the challenger and capture progress intact",function()
		local s,ids,w,b,c,p=setup()
		local Battle=require(Server.Battle)
		local rival=Session.new(-9287,"Rival fixture",2);rival.loaded=true;b.sessions[rival.userId]=rival
		for _=1,3 do rival:AddPet("Duck",1).investment=0 end;rival:RefreshArmy() -- October 23 empty start: the rival needs an Army too
		local contest=Battle.new("RecallContest",rival.userId,"income:1",w:Position(),w:CampPosition(1),0)
		contest.defender=s.userId;contest.incomeSite=true;contest.incomeContest=true
		contest.phase="Fight";contest.captureElapsed=2;contest.name="Income outpost"
		contest:AddArmy("A",rival:Lineup(),w:Position());contest:AddArmy("B",s:Lineup(),w:Position())
		local opponent=contest.units[1];opponent.hp-=2;local hp=opponent.hp
		b.battles[contest.id]=contest;s.outgoing=contest.id;rival.outgoing=contest.id;s.armyState="Fighting"
		assert(b:RecallForCommand(s,3,false))
		assert(b.battles[contest.id]==contest and rival.outgoing==contest.id and contest.defender==nil)
		assert(contest.captureElapsed==2 and not contest.paid and contest.units[1]==opponent and opponent.hp==hp)
		for _,unit in contest.units do assert(unit.side=="A") end
		assert(not s.outgoing and s.armyState=="Home" and not next(s.awayPets))
	end)
	return results
end
return Checks
