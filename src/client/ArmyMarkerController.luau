--!strict
-- One portrait follows each attacking squad using the replicated actors' positions.
local Players=game:GetService("Players")
local Theme=require(script.Parent.UITheme)
local Marker={}
Marker.__index=Marker

function Marker.new(battles,folder)
	return setmetatable({battles=battles,folder=folder,views={},thumbnails={},alive=true},Marker)
end

function Marker:Thumbnail(userId)
	if self.thumbnails[userId]~=nil then return end
	self.thumbnails[userId]=""
	if userId<=0 then return end
	task.spawn(function()
		for attempt=1,2 do
			local ok,url,ready=pcall(function() return Players:GetUserThumbnailAsync(userId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150) end)
			if not self.alive then return end
			if ok and ready then self.thumbnails[userId]=url;return end
			if attempt<2 then task.wait(2) end
		end
	end)
end

function Marker:Release(id)
	local view=self.views[id]
	if not view then return end
	if view.bannerConnection then view.bannerConnection:Disconnect() end
	view.gui:Destroy();view.anchor:Destroy();self.views[id]=nil
end

function Marker:UpdateBanner(view)
	local enabled=view.player~=nil and view.player:GetAttribute("PetRollCommanderBanner")==true
	if view.commander==enabled then return end
	view.commander=enabled
	-- Retain the original friendly/hostile circle color; the pass changes its rim only.
	Theme.Stroke(view.circle,if enabled then Theme.Arcade.gold else Theme.Arcade.border,if enabled then 4 else 3)
	view.crown.Visible=enabled
end

function Marker:BindPlayer(view)
	local player=Players:GetPlayerByUserId(view.userId)
	if view.player~=player then
		if view.bannerConnection then view.bannerConnection:Disconnect();view.bannerConnection=nil end
		view.player=player
		if player then
			view.bannerConnection=player:GetAttributeChangedSignal("PetRollCommanderBanner"):Connect(function()
				self:UpdateBanner(view)
			end)
		end
	end
	self:UpdateBanner(view)
end

local function commanderCrown(circle)
	local badge=Theme.Frame(circle,"CommanderBanner",UDim2.fromOffset(29,23),Theme.Arcade.border)
	badge.Position,badge.ZIndex,badge.Visible=UDim2.new(1,-22,0,-5),6,false
	Theme.Round(badge,6)
	-- Small native crown silhouette keeps the badge clear even at portrait size.
	local base=Theme.Frame(badge,"Band",UDim2.fromOffset(19,7),Theme.Arcade.gold)
	base.Position,base.ZIndex=UDim2.fromOffset(5,12),7
	Theme.Round(base,2)
	for i=1,3 do
		local tooth=Theme.Frame(badge,"Point"..i,UDim2.fromOffset(5,if i==2 then 12 else 9),Theme.Arcade.gold)
		tooth.Position,tooth.ZIndex=UDim2.fromOffset(5+(i-1)*7,if i==2 then 3 else 6),7
		tooth.Rotation=if i==1 then -12 elseif i==3 then 12 else 0
		Theme.Round(tooth,1)
	end
	return badge
end

function Marker:Receive(snapshots)
	local seen={}
	for _,battle in snapshots do
		seen[battle.id]=true
		local view=self.views[battle.id]
		if not view then
			self:Thumbnail(battle.attacker)
			local anchor=Instance.new("Part")
			anchor.Name,anchor.Size="ArmyPortrait_"..battle.id,Vector3.one
			anchor.Anchored,anchor.CanCollide,anchor.CanTouch,anchor.CanQuery,anchor.Transparency=true,false,false,false,1
			anchor.Parent=self.folder
			local gui=Instance.new("BillboardGui")
			gui.Name,gui.Adornee,gui.Size="ArmyPortrait",anchor,UDim2.fromOffset(112,105)
			gui.AlwaysOnTop,gui.MaxDistance,gui.LightInfluence,gui.Parent=true,220,0,Players.LocalPlayer.PlayerGui
			local own=battle.attacker==Players.LocalPlayer.UserId
			local circle=Theme.Frame(gui,"PortraitCircle",UDim2.fromOffset(65,65),if own then Theme.Arcade.gold else Theme.Arcade.red)
			circle.Position,circle.UICorner.CornerRadius=UDim2.new(0.5,-32,0,5),UDim.new(1,0)
			Theme.Stroke(circle,Theme.Arcade.border,3)
			local fallback=Theme.Display(circle,"Fallback",if own then "You" else "?",20)
			fallback.Size,fallback.TextXAlignment=UDim2.fromScale(1,1),Enum.TextXAlignment.Center
			local portrait=Instance.new("ImageLabel")
			portrait.Name,portrait.BackgroundTransparency,portrait.Size,portrait.Position="Headshot",1,UDim2.new(1,-6,1,-6),UDim2.fromOffset(3,3)
			portrait.Parent=circle
			Theme.Round(portrait,50)
			local label=Theme.Display(gui,"Owner","",15)
			label.Position,label.Size,label.TextXAlignment=UDim2.fromOffset(0,73),UDim2.new(1,0,0,26),Enum.TextXAlignment.Center
			local player=Players:GetPlayerByUserId(battle.attacker)
			label.Text=if own then "My army" else (if player then player.DisplayName else "Test army")
			view={anchor=anchor,gui=gui,portrait=portrait,fallback=fallback,userId=battle.attacker,
				circle=circle,crown=commanderCrown(circle)}
			self.views[battle.id]=view
		end
		view.battle=battle
		self:BindPlayer(view)
	end
	for id in self.views do if not seen[id] then self:Release(id) end end
end

function Marker:Step()
	for _,view in self.views do
		-- Also handles a player replicating after their first battle snapshot.
		self:BindPlayer(view)
		local sum,count=Vector3.zero,0
		for _,unit in view.battle.units do
			if unit.side~="A" or unit.hp<=0 or unit.retiring or (unit.reinforcing and view.battle.phase~="Returning") then continue end
			local model=self.battles:FindActor(view.battle.id,unit.id)
			if model and model.PrimaryPart then sum+=model.PrimaryPart.Position;count+=1 end
		end
		view.gui.Enabled=count>0 and not self.battles.app.panel.Visible
		if count>0 then view.anchor.Position=sum/count+Vector3.new(0,6,0) end
		local url=self.thumbnails[view.userId] or ""
		view.portrait.Image=url
		view.fallback.Visible=url==""
	end
end

function Marker:Destroy()
	self.alive=false
	for id in self.views do self:Release(id) end
end

return Marker
