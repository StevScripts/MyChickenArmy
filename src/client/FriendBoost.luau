--!strict
-- October 20 Friend Boost line (docs/team/GOLD_RUSH_FRIEND_BOOST.md): "Friend Boost:
-- +N%" with a green + under the Coins number, as in the Drop a Fruit reference. It
-- mounts into HudController's FriendBoostSlot. The + opens Roblox's own friends
-- invite list straight away (owner request: no popup of our own). The server owns
-- the boost (FriendBoostService) and replicates it as the Player attribute
-- FriendBoost; this module only presents.
-- October 27 (WS7, docs/team/SOCIAL_MOMENTS.md "Invite"): Invite carries a reason and
-- LaunchData "inv:<userId>" (AnalyticsPlayer tags the join "invite"); Prompted opens the
-- one automatic prompt per visit after a high moment the server picked, clear of
-- purchase prompts and other popups. FriendBoost.lastInviteAt (os.clock of the last
-- prompt, nil until one) and friendBoost.invitePromptOpen are read by the Coins-pack
-- checkout (WS3) and the popup queue (WS5).
local Players=game:GetService("Players")
local SocialService=game:GetService("SocialService")
local Config=require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local Theme=require(script.Parent.UITheme)
local AnalyticsClient=require(script.Parent.AnalyticsClient)
local FriendBoost={}
FriendBoost.__index=FriendBoost
FriendBoost.lastInviteAt=nil::number?
-- A closed signal that never comes back still frees the popup queue after this long.
local PROMPT_OPEN_LIMIT=60
-- The automatic prompt waits this long at most for a busy popup to close.
local BUSY_WAIT_LIMIT=30
local GREEN=Theme.ReferenceColors.Army
local WHITE=Color3.new(1,1,1)

local function percent(value: number): number
	return math.floor(value*100+0.5)
end

function FriendBoost.new(app)
	local self=setmetatable({app=app,connections={},boost=0,
		inviteReason="button",invitePromptOpen=false,autoInvited=false,destroyed=false},FriendBoost)
	local slot=app.hud and app.hud.friendBoostSlot
	if slot and Config.FriendBoost.Enabled then self:Mount(slot) end
	local player=Players.LocalPlayer
	if player then
		table.insert(self.connections,player:GetAttributeChangedSignal("FriendBoost"):Connect(function() self:Refresh(true) end))
	end
	-- October 27 (WS7): invites actually sent (invite.sent, value = recipients).
	table.insert(self.connections,SocialService.GameInvitePromptClosed:Connect(function(closer,recipientIds)
		if closer~=Players.LocalPlayer then return end
		self.invitePromptOpen=false
		local count=if type(recipientIds)=="table" then #recipientIds else 0
		if count>0 then AnalyticsClient.Track("invite.sent",self.inviteReason or "button",count) end
	end))
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
		self:Invite("button")
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
		Theme.Motion:Punch(self.label,1.2,0.3)
		self.app:Notify("A friend is here! Friend Boost: +"..percent(self.boost).."% Coins",true)
	end
	-- October 21 game feel: the row glows green while friends boost; nothing loops at +0%.
	local active=self.boost>0
	if active~=(self.glowing==true) then
		self.glowing=active
		if active then Theme.Motion:Glow(self.row,GREEN,2) else Theme.Motion:StopGlow(self.row) end
	end
end

-- Roblox's own friends invite list; the player picks whom to invite. reason: "button"
-- (the +) or the server's trigger (Rebirth0, EpicFind, FortRoost); an automatic prompt
-- that can't be sent stays silent.
function FriendBoost:Invite(reason: string?)
	local player=Players.LocalPlayer
	if self.inviting or not player then return end
	self.inviting=true
	local automatic=reason~=nil and reason~="button"
	task.spawn(function()
		local ok,allowed=pcall(SocialService.CanSendGameInviteAsync,SocialService,player)
		if ok and allowed then
			local options=Instance.new("ExperienceInviteOptions")
			-- October 27 (WS7): the copy names the boost; LaunchData tags the friend's join.
			options.PromptMessage=string.format("Play with a friend: +%d%% Coins for each friend in your server!",percent(Config.FriendBoost.PerFriend))
			pcall(function() options.LaunchData="inv:"..player.UserId end)
			self.inviteReason=reason or "button"
			self.invitePromptOpen=true
			FriendBoost.lastInviteAt=os.clock()
			local opened=os.clock()
			task.delay(PROMPT_OPEN_LIMIT,function()
				if self.invitePromptOpen and FriendBoost.lastInviteAt==opened then self.invitePromptOpen=false end
			end)
			if not pcall(SocialService.PromptGameInvite,SocialService,player,options) then self.invitePromptOpen=false end
		elseif not automatic then
			self.app:Notify("Invites aren't available right now.",false)
		end
		self.inviting=false
	end)
end

-- October 27 (WS7): the server picked this visit's high moment (state.invitePrompt). Wait
-- for the celebration (Social.Invite.DelaySeconds), then for any busy popup (WS5's
-- app:ModalBusy) and the quiet window after a Roblox purchase prompt (WS3's
-- commerce:LastPromptAt). Never with a friend already here; one try per visit.
function FriendBoost:Prompted(trigger: string)
	if self.autoInvited or type(trigger)~="string" then return end
	self.autoInvited=true
	local rule=(Config :: any).Social and (Config :: any).Social.Invite or {}
	local quiet=rule.QuietAfterPurchasePromptSeconds or 60
	task.delay(rule.DelaySeconds or 3,function()
		local app=self.app
		local deadline=os.clock()+BUSY_WAIT_LIMIT+quiet
		while os.clock()<deadline do
			if self.destroyed or self.boost>0 then return end
			local commerce=app and app.commerce
			local lastPrompt=if commerce and commerce.LastPromptAt then commerce:LastPromptAt() else nil
			local wait=if type(lastPrompt)=="number" then lastPrompt+quiet-os.clock() else 0
			local busy=app and app.ModalBusy and app:ModalBusy()
			if wait<=0 and not busy then self:Invite(trigger);return end
			task.wait(math.clamp(wait,1,5))
		end
	end)
end

function FriendBoost:Destroy()
	self.destroyed=true
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.row then self.row:Destroy();self.row=nil;self.label=nil end
end

return FriendBoost
