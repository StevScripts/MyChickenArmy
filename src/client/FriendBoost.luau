--!strict
-- October 20 Friend Boost line (docs/team/GOLD_RUSH_FRIEND_BOOST.md): "Friend Boost:
-- +N%" with a green + under the Coins pill, as in the Drop a Fruit reference. It
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
-- Same dark see-through pill as HudController's Coins pill.
local PILL_COLOR,PILL_TRANSPARENCY=Color3.fromRGB(8,9,10),0.5

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

-- October 21 reference parity: the line is its own dark see-through pill as wide as the
-- Coins pill above it, and the green + sits just right of the pill. The slot is
-- HudController's row in reference units (229 x 27: pill 0-192, + 202-229).
function FriendBoost:Mount(slot)
	local row=Theme.Container(slot,"FriendBoost")
	local pill=Theme.Frame(row,"Pill",UDim2.fromScale(192/229,1),PILL_COLOR)
	pill.BackgroundTransparency=PILL_TRANSPARENCY
	local text=Theme.Display(pill,"Label","Friend Boost: +0%",20,WHITE)
	text.Position,text.Size=UDim2.fromScale(0.05,0.1),UDim2.fromScale(0.9,0.8)
	text.TextScaled,text.TextWrapped=true,false
	text.TextFace.TextOutline.Thickness=0.08
	Theme.Motion:Center(text) -- pops grow from the middle; same place at rest
	local button=Theme.ActionButton(row,"Invite","+",function()
		self.app.audio:Play("Click")
		self:Invite()
	end,GREEN)
	button.AnchorPoint,button.Position,button.Size=Vector2.new(0,0.5),UDim2.fromScale(202/229,0.5),UDim2.fromScale(27/229,1)
	Theme.Aspect(button,1)
	-- Phone: a 16 px square; the hit area grows to 48 px, mostly right and up (the pills
	-- beside and above it are plain labels).
	Theme.PadHit(button,3,3,0.25,0.7)
	self.row,self.pill,self.label=row,pill,text
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
		Theme.Motion:Punch(self.label,1.2,0.3)
		self.app:Notify("A friend is here! Friend Boost: +"..percent(self.boost).."% Coins",true)
	end
	-- October 21 game feel: the row glows green while friends boost; nothing loops at +0%.
	local active=self.boost>0
	if active~=(self.glowing==true) then
		self.glowing=active
		if active then Theme.Motion:Glow(self.pill,GREEN,2) else Theme.Motion:StopGlow(self.pill) end
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
	if self.row then self.row:Destroy();self.row=nil;self.pill=nil;self.label=nil end
end

return FriendBoost
