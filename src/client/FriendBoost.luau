--!strict
-- October 20 Friend Boost line (docs/team/GOLD_RUSH_FRIEND_BOOST.md): "Friend Boost:
-- +N%" with a green + under the Coins number, as in the Drop a Fruit reference. It
-- mounts into HudController's FriendBoostSlot. The + opens Roblox's own friends
-- invite list straight away (owner request: no popup of our own). The server owns
-- the boost (FriendBoostService) and replicates it as the Player attribute
-- FriendBoost; this module only presents.
local Players=game:GetService("Players")
local SocialService=game:GetService("SocialService")
local Config=require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local Theme=require(script.Parent.UITheme)
local FriendBoost={}
FriendBoost.__index=FriendBoost
local GREEN=Theme.ReferenceColors.Army
local WHITE=Color3.new(1,1,1)

local function percent(value: number): number
	return math.floor(value*100+0.5)
end

function FriendBoost.new(app)
	local self=setmetatable({app=app,connections={},boost=0},FriendBoost)
	local slot=app.hud and app.hud.friendBoostSlot
	if slot and Config.FriendBoost.Enabled then self:Mount(slot) end
	local player=Players.LocalPlayer
	if player then
		table.insert(self.connections,player:GetAttributeChangedSignal("FriendBoost"):Connect(function() self:Refresh(true) end))
	end
	self:Refresh(false)
	return self
end

function FriendBoost:Mount(slot)
	local row=Theme.Container(slot,"FriendBoost")
	local text=Theme.Display(row,"Label","Friend Boost: +0%",20,WHITE)
	text.Size,text.TextScaled,text.TextWrapped=UDim2.fromScale(0.86,1),true,false
	Theme.Motion:Center(text) -- pops grow from the middle; same place at rest
	local button=Theme.ActionButton(row,"Invite","+",function()
		self.app.audio:Play("Click")
		self:Invite()
	end,GREEN)
	button.AnchorPoint,button.Size=Vector2.new(0,0.5),UDim2.fromScale(0.14,1)
	Theme.Aspect(button,1)
	self.row,self.label=row,text
	-- The + sits right after the text, like the reference.
	local function place()
		local width=math.max(1,row.AbsoluteSize.X)
		button.Position=UDim2.fromScale(math.min(0.86,text.TextBounds.X/width+0.025),0.5)
	end
	table.insert(self.connections,text:GetPropertyChangedSignal("TextBounds"):Connect(place))
	table.insert(self.connections,row:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
	place()
	Theme.ScaleText(row)
end

-- announce: a live increase (a friend arrived), not the first read.
function FriendBoost:Refresh(announce: boolean)
	local player=Players.LocalPlayer
	local previous=self.boost
	self.boost=if player then tonumber(player:GetAttribute("FriendBoost")) or 0 else 0
	if not self.label then return end
	self.label.Text="Friend Boost: +"..percent(self.boost).."%"
	self.label.TextColor3=if self.boost>0 then GREEN else WHITE
	if announce and self.boost>previous then
		Theme.Motion:PopScale(self.label,1.15)
		self.app:Notify("A friend is here! Friend Boost: +"..percent(self.boost).."% Coins",true)
	end
end

-- Roblox's own friends invite list; the player picks whom to invite.
function FriendBoost:Invite()
	local player=Players.LocalPlayer
	if self.inviting or not player then return end
	self.inviting=true
	task.spawn(function()
		local ok,allowed=pcall(SocialService.CanSendGameInviteAsync,SocialService,player)
		if ok and allowed then
			local options=Instance.new("ExperienceInviteOptions")
			options.PromptMessage=string.format("Invite friends! Each friend in your server gives you +%d%% Coins.",percent(Config.FriendBoost.PerFriend))
			pcall(SocialService.PromptGameInvite,SocialService,player,options)
		else
			self.app:Notify("Invites aren't available right now.",false)
		end
		self.inviting=false
	end)
end

function FriendBoost:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.row then self.row:Destroy();self.row=nil;self.label=nil end
end

return FriendBoost
