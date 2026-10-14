--!strict
-- Owns the selected squad while following; World and Battle retain their actor owners otherwise.
local MapLayout=require(game:GetService("ReplicatedStorage").PetRoll.Shared.MapLayout)
local FollowMotion=require(game:GetService("ReplicatedStorage").PetRoll.Shared.FollowMotion)
local Giant=require(game:GetService("ReplicatedStorage").PetRoll.Shared.GiantChicken)
local Commands={}
Commands.__index=Commands

local function characterRoot(player)
	local character=player and player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health<=0 or not root then return nil end
	return root,humanoid,character
end

function Commands.new(world,battles,sessions)
	return setmetatable({world=world,battles=battles,sessions=sessions,following={},nextSync=0,lastStep=nil},Commands)
end

function Commands:Restore(session,id,actor,teleport)
	actor.model:SetAttribute("Following",nil)
	if teleport then actor:Teleport(self.world:ReturnPosition(session,id)) end
	self.world:RestoreActor(session,id,actor)
end

function Commands:Release(session,teleport)
	local record=self.following[session.userId]
	if not record then return end
	self.following[session.userId]=nil
	session.armyState,session.awayPets="Home",{}
	session:RefreshArmy()
	for id,actor in record.actors do self:Restore(session,id,actor,teleport) end
	record.folder:Destroy()
	session:Touch()
end

function Commands:Sync(session)
	local record=self.following[session.userId]
	if not record then return end
	local ids=session:BestPetIds()
	local desired={}
	for _,id in ids do desired[id]=true end
	for id,actor in record.actors do if not desired[id] then
		record.actors[id]=nil
		record.heights[id]=nil
		self:Restore(session,id,actor,true)
	end end
	if #ids==0 then self:Release(session,true);return end
	for _,id in ids do if not record.actors[id] then
		local actor=self.world:TakeActor(session.plotIndex,id)
		if actor then
			actor:SetParent(record.folder)
			actor.model:SetAttribute("Following",true)
			actor.model:SetAttribute("InArmy",true)
			record.actors[id]=actor
		end
	end end
	-- New selected birds are still home before Sync; World has already made their rigs.
	session.slots=table.clone(ids)
	session.awayPets=desired
	session.armyState="Following"
	record.spacing=5.5
	for _,id in ids do record.spacing=math.max(record.spacing,(session.pets[id].giantSize or 0)*0.7) end
	-- Following has its own formation order; keep the saved/selected slots intact.
	local regular,giants={},{}
	for _,id in ids do
		table.insert(if Giant.IsValidSize(session.pets[id].giantSize) then giants else regular,id)
	end
	record.ids,record.offsets={},{}
	local rear=Vector3.new(0,0,math.ceil(#regular/3)*record.spacing)
	for ordinal,id in regular do
		table.insert(record.ids,id)
		record.offsets[id]=FollowMotion.Offset(ordinal,#regular,record.spacing)
	end
	for ordinal,id in giants do
		table.insert(record.ids,id)
		record.offsets[id]=FollowMotion.Offset(ordinal,#giants,record.spacing)+rear
	end
end

function Commands:StartFollowing(session,player)
	self.world:UpdateSession(session)
	local folder=Instance.new("Folder")
	folder.Name="FollowingArmy_"..session.userId
	folder.Parent=self.world.root
	self.following[session.userId]={folder=folder,actors={},ids={},player=player,heights={},nextGround=0}
	self:Sync(session)
	session:Touch()
end

function Commands:CallArmy(player,session,now)
	if (session.researchEffects.callArmy or 0)<1 then return false,"Unlock Call Army in Upgrades first." end
	if not characterRoot(player) then return false,"Your character will be ready in a moment." end
	if #session:BestPetIds()==0 then return false,"Select chickens in My Army first." end
	-- A quick repeat is not a failure: the first call already worked.
	if now-(session.lastArmyCall or -math.huge)<0.75 then return true,"Your army heard you!" end
	session.lastArmyCall=now
	if self.following[session.userId] then self:Sync(session);return true,"Your army is following you." end
	local ok,why=self.battles:RecallForCommand(session,now,true)
	if not ok then return false,why end
	self:StartFollowing(session,player)
	return true,"Army called! Your chickens will follow you."
end

function Commands:GoBase(player,session,now)
	local root,_,character=characterRoot(player)
	if not root then return false,"Your character will be ready in a moment." end
	local goBaseWait=(session.lastGoBase or -math.huge)+2-now
	if goBaseWait>0 then return false,"Base teleport ready in "..math.max(1,math.ceil(goBaseWait)).."s." end
	local ok,why=self.battles:RecallForCommand(session,now,false)
	if not ok then return false,why end
	session.lastGoBase=now
	self:Release(session,true)
	self.world:UpdateSession(session)
	local plot=self.world.plots[session.plotIndex]
	for id,actor in plot.actors do
		actor:Teleport(self.world:ReturnPosition(session,id))
		self.world:RestoreActor(session,id,actor)
	end
	character:PivotTo(self.world:SpawnFrame(session.plotIndex))
	root.AssemblyLinearVelocity,root.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
	return true,"You and your chickens are back at your base."
end

function Commands:Attack(session,targetId,now)
	local record=self.following[session.userId]
	local player=record and record.player
	if record then self:Release(session,false) end
	local ok,why=self.battles:Attack(session,targetId,now)
	if not ok and player then self:StartFollowing(session,player) end
	return ok,why
end

function Commands:Step(now)
	local dt=math.clamp(if self.lastStep then now-self.lastStep else 1/60,0,0.1)
	self.lastStep=now
	local sync=now>=self.nextSync
	if sync then self.nextSync=now+0.2 end
	for userId,record in self.following do
		local session=self.sessions[userId]
		local root,humanoid=characterRoot(record.player)
		if not session or session.closing or session.saveLost then
			self:Remove(userId);continue
		end
		if not root then self:Release(session,true);self.world:UpdateSession(session);continue end
		if sync then self:Sync(session) end
		if not self.following[userId] then continue end
		local maximum=math.min(FollowMotion.MaxSpeed,humanoid.WalkSpeed+8)
		local velocity=FollowMotion.Limit(FollowMotion.Flat(root.AssemblyLinearVelocity),maximum)
		record.frame=FollowMotion.Frame(record.frame,root.CFrame,velocity,dt)
		local ground=now>=record.nextGround
		if ground then record.nextGround=now+0.1 end
		for _,id in record.ids do
			local actor=record.actors[id]
			if not actor then continue end
			local target=record.frame:PointToWorldSpace(record.offsets[id])
			if ground or not record.heights[id] then record.heights[id]=MapLayout.FootPosition(target.X,target.Z).Y end
			local foot=Vector3.new(target.X,record.heights[id],target.Z)
			local distance=FollowMotion.Flat(actor:Position()-foot).Magnitude
			if distance>120 and actor:CanStandAt(foot) then actor:Teleport(foot)
			else
				actor:Follow(foot,velocity,maximum)
				local state=actor:Step(now)
				if state=="blocked" and now-actor.progressAt>4 then actor:Recover(foot,"Following route blocked",now) end
			end
		end
	end
end

function Commands:Remove(userId)
	local record=self.following[userId]
	if not record then return end
	for _,actor in record.actors do actor:Destroy() end
	record.folder:Destroy();self.following[userId]=nil
end

return Commands
