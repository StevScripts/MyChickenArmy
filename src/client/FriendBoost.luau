--!strict
-- October 20 Friend Boost line (docs/team/GOLD_RUSH_FRIEND_BOOST.md): "Friend Boost:
-- +N%" with a green + under the Coins number, as in the Drop a Fruit reference. It
-- mounts into HudController's FriendBoostSlot. The + opens a small popup with the
-- friends here, the rule and Invite Friends (Roblox's own invite prompt). The server
-- owns the boost (FriendBoostService) and replicates it as the Player attributes
-- FriendBoost and FriendBoostFriends; this module only presents.
local Players=game:GetService("Players")
local SocialService=game:GetService("SocialService")
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local Config=require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local Theme=require(script.Parent.UITheme)
local FriendBoost={}
FriendBoost.__index=FriendBoost
local GREEN=Theme.ReferenceColors.Army
local WHITE=Color3.new(1,1,1)
-- The friend icon from the owner's reference GUI (StarterGui.GUI.HUD.RightDownSide.FriendBoost).
FriendBoost.Icon="rbxassetid://120623411385668"
-- Width/height of the whole popup, header included.
local PANEL_SIZE,PANEL_ASPECT=UDim2.fromScale(0.4,0.56),1.5

local function percent(value: number): number
	return math.floor(value*100+0.5)
end

local function label(parent,name,value,size,color,align)
	local item=Theme.Label(parent,name,value,size,color)
	item.TextXAlignment,item.TextScaled,item.TextWrapped=align or Enum.TextXAlignment.Center,true,false
	return item
end

function FriendBoost.new(app)
	local self=setmetatable({app=app,connections={},popupConnections={},boost=0,friends=0},FriendBoost)
	local slot=app.hud and app.hud.friendBoostSlot
	if slot and Config.FriendBoost.Enabled then self:Mount(slot) end
	local player=Players.LocalPlayer
	if player then
		for _,name in {"FriendBoost","FriendBoostFriends"} do
			table.insert(self.connections,player:GetAttributeChangedSignal(name):Connect(function() self:Refresh(true) end))
		end
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
		self:Open()
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
	self.friends=if player then tonumber(player:GetAttribute("FriendBoostFriends")) or 0 else 0
	if self.label then
		self.label.Text="Friend Boost: +"..percent(self.boost).."%"
		self.label.TextColor3=if self.boost>0 then GREEN else WHITE
		if announce and self.boost>previous then
			Theme.Motion:PopScale(self.label,1.15)
			self.app:Notify("A friend is here! Friend Boost: +"..percent(self.boost).."% Coins",true)
		end
	end
	self:RenderPopup()
end

function FriendBoost:RenderPopup()
	if not self.gui or not self.bonus or not self.friendsLabel then return end
	self.bonus.Text="+"..percent(self.boost).."% Coins"
	self.bonus.TextColor3=if self.boost>0 then GREEN else WHITE
	local count=self.friends
	self.friendsLabel.Text=(if count<=0 then "No friends in this server yet"
		elseif count==1 then "1 friend in this server" else count.." friends in this server")
		..(if self.boost>=Config.FriendBoost.Max then " · Max boost!" else "")
end

-- Roblox's own invite prompt; the player picks whom to invite.
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

function FriendBoost:Dismiss(immediate: boolean?)
	local gui,panel=self.gui,self.panel
	if not gui or (self.closing and not immediate) then return end
	self.closing=true
	ContextActionService:UnbindAction("PetRollFriendBoostClose")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	for _,connection in self.popupConnections do connection:Disconnect() end
	table.clear(self.popupConnections)
	self.app:SetMenuBlur("friendBoost",false)
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.bonus,self.friendsLabel,self.closing=nil,nil,nil,nil,false
		gui:Destroy()
	end
	if immediate or not panel then finish();return end
	Theme.Motion:Tween(panel,"friend-size",{Size=UDim2.fromScale(PANEL_SIZE.X.Scale*0.97,PANEL_SIZE.Y.Scale*0.97)},0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"friend-fade",{GroupTransparency=1},0.16,nil,nil,finish)
end

function FriendBoost:Open()
	if self.gui and not self.closing then return end
	self:Dismiss(true)
	local app=self.app
	-- Acquire the blur before closing other menus so their exit cannot clear it.
	app:SetMenuBlur("friendBoost",true)
	app:CloseOtherMenus("friendBoost")
	self.previousSelection=GuiService.SelectedObject
	local gui=Theme.InsetContainer(app.other,"FriendBoost",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing=gui,false
	local frames=Theme.Container(gui,"FRAMES")
	local backdrop=Theme.Frame(Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None),"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active=1,true
	local panel=Instance.new("CanvasGroup")
	panel.Name="FriendBoost"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.AnchorPoint,panel.Position,panel.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),PANEL_SIZE
	panel.Parent,self.panel=frames,panel
	Theme.Aspect(panel,PANEL_ASPECT)
	local header=Theme.Header(panel,"Header","Friend Boost",GREEN)
	header.PageIcon.Image,header.PageIcon.Visible=FriendBoost.Icon,true
	Theme.LayoutHeader(header)
	local main=Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Theme.PageSurfaces.Army)
	main.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	-- The friend icon on slow green rays, the bonus and friend count beside it.
	local art=Theme.Container(main,"Art")
	art.Position,art.Size=UDim2.fromScale(0.04,0.05),UDim2.fromScale(0.3,0.5)
	Theme.Aspect(art,1)
	local rays=Theme.Image(art,"Rays",Theme.Assets.Rays,UDim2.fromScale(1.3,1.3),UDim2.fromScale(0.5,0.5))
	rays.AnchorPoint,rays.ImageColor3,rays.ImageTransparency,rays.ZIndex=Vector2.new(0.5,0.5),GREEN,0.45,2
	if not app.reducedMotion then
		Theme.Motion:Tween(rays,"spin",{Rotation=360},12,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	end
	local icon=Theme.Image(art,"Icon",FriendBoost.Icon,UDim2.fromScale(0.9,0.9),UDim2.fromScale(0.05,0.05))
	icon.ZIndex=4
	local bonus=Theme.Display(main,"Bonus","",56,WHITE)
	bonus.Position,bonus.Size,bonus.TextScaled,bonus.TextWrapped=UDim2.fromScale(0.38,0.08),UDim2.fromScale(0.58,0.26),true,false
	local friends=label(main,"Friends","",30,WHITE,Enum.TextXAlignment.Left)
	friends.Position,friends.Size=UDim2.fromScale(0.38,0.36),UDim2.fromScale(0.58,0.13)
	local rule=label(main,"Rule",string.format("Each Roblox friend in your server gives +%d%% Coins, up to +%d%%.",
		percent(Config.FriendBoost.PerFriend),percent(Config.FriendBoost.Max)),24,Color3.fromRGB(224,230,233))
	-- Wraps to two lines on small screens instead of shrinking below the text floor.
	rule.Position,rule.Size,rule.TextWrapped=UDim2.fromScale(0.05,0.57),UDim2.fromScale(0.9,0.17),true
	self.bonus,self.friendsLabel=bonus,friends
	local actions=Theme.Container(main,"Actions")
	actions.AnchorPoint,actions.Position,actions.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.955),UDim2.fromScale(0.5,0.19)
	Theme.Aspect(actions,4.3)
	local function close()
		if not self.gui or self.closing then return end
		app.audio:Play("Click")
		self:Dismiss()
	end
	Theme.HeaderClose(header,close)
	local invite=Theme.ActionButton(actions,"InviteFriends","Invite Friends",function()
		app.audio:Play("Click")
		self:Invite()
	end,GREEN)
	invite.Position,invite.Size=UDim2.fromScale(0,0),UDim2.fromScale(1,1)
	Theme.Studs(invite.Visual.Face,0.07,28,0)
	invite.Visual.Caption.TextScaled=true
	self:RenderPopup()
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	if not app.reducedMotion then panel.Size=UDim2.fromScale(PANEL_SIZE.X.Scale*0.94,PANEL_SIZE.Y.Scale*0.94) end
	Theme.Motion:Tween(panel,"friend-size",{Size=PANEL_SIZE},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
	Theme.Motion:Tween(panel,"friend-fade",{GroupTransparency=0},0.22)
	ContextActionService:BindActionAtPriority("PetRollFriendBoostClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	table.insert(self.popupConnections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then close() end
	end))
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=invite end
end

function FriendBoost:Destroy()
	self:Dismiss(true)
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.row then self.row:Destroy();self.row=nil;self.label=nil end
end

return FriendBoost
