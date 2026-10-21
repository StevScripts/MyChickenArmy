--!strict
-- October 16 free gift popup: like the game + join the group, then Verify for one
-- free chicken. The server checks the group and grants; this only presents.
local GroupService=game:GetService("GroupService")
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local Catalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.PetCatalog)
local Config=require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local Theme=require(script.Parent.UITheme)
local Controller={}
Controller.__index=Controller
local GREEN=Theme.ReferenceColors.Army
local GOLD=Theme.ReferenceColors.Base
local BLUE=Theme.ReferenceColors.Upgrades
local Portraits=require(script.Parent.ChickenPortraits)
Controller.Assets={
	-- The gift chicken's own portrait fronts the HUD button and header.
	Gift=Portraits[Config.FreeGift.Species] or "rbxassetid://85740083144452",
	Like="rbxassetid://123763953639040",
	Group="rbxassetid://109146933804070",
}
-- Width/height of the whole window, header included.
local PANEL_SIZE,PANEL_ASPECT=UDim2.fromScale(0.42,0.6),1.5
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): an authored cue, or its
-- fallback until the sound session adds it (UI Lab previews stub audio without Has).
-- Presentation only; one client audio.
local Audio=nil
local function cue(name,fallback,pitch,options)
	if not Audio then return end
	if type(Audio.Has)=="function" and Audio:Has(name) then Audio:Play(name,pitch,options)
	elseif fallback then Audio:Play(fallback,pitch,options) end
end

function Controller.new(app)
	Audio=app.audio
	return setmetatable({app=app,connections={},gift=nil,checking=false},Controller)
end

-- state.freeGift is optional (older servers send none).
function Controller:Available(): boolean
	local gift=self.gift
	return type(gift)=="table" and gift.enabled==true and type(gift.species)=="string" and Catalog[gift.species]~=nil
end

function Controller:Render(state,result)
	self.gift=state.freeGift
	if result and result.action=="ClaimFreeGift" then
		self.checking=false
		if self.gui then
			if result.ok then self:ShowClaimed(true)
			else
				self:RefreshVerify()
				Theme.Motion:Shake(self.verify.Visual,6)
			end
		end
		-- Not in the group yet: offer Roblox's own join prompt, then claim if they join.
		if not result.ok and type(result.freeGift)=="table" and result.freeGift.notInGroup then
			self:PromptJoin(true)
		end
	elseif self.gui and type(self.gift)=="table" and self.gift.claimed and not self.claimedShown then
		self:ShowClaimed(false)
	end
end

-- Roblox's native "Join group" prompt. With `claimAfter`, a successful join
-- verifies again automatically (after the server's 3 s lookup cooldown).
function Controller:PromptJoin(claimAfter)
	local groupId=type(self.gift)=="table" and self.gift.groupId
	if type(groupId)~="number" or self.joinPrompting then return end
	self.joinPrompting=true
	task.spawn(function()
		local ok,status=pcall(GroupService.PromptJoinAsync,GroupService,groupId)
		self.joinPrompting=false
		if not ok then return end
		if status==Enum.GroupMembershipStatus.Joined or status==Enum.GroupMembershipStatus.AlreadyMember then
			if not claimAfter or (type(self.gift)=="table" and self.gift.claimed) then return end
			self.app:Notify("Welcome to the group! Claiming your free chicken…",true)
			self.checking=true
			self:RefreshVerify()
			task.wait(3.2)
			self.app:Request("ClaimFreeGift")
		elseif status==Enum.GroupMembershipStatus.JoinRequestPending then
			self.app:Notify("Your join request is pending. Press Verify once you're in!",true)
		end
	end)
end

function Controller:RefreshVerify()
	local verify=self.verify
	if not verify then return end
	verify.Text=if self.checking then "Checking…" else "Verify"
	verify.Active=not self.checking
end

function Controller:ShowClaimed(celebrate)
	if not self.gui or self.claimedShown then return end
	self.claimedShown=true
	self.verify.Visible,self.hint.Visible=false,false
	self.claimed.Visible=true
	Theme.Motion:PopScale(self.claimed,0.6,0.3)
	if celebrate then
		-- The chicken pops under a confetti burst over the window, with the Claim cue.
		cue("Claim","UIPurchase",nil,{voiceKey="GiftClaim",cooldown=0.3})
		Theme.Motion:PopScale(self.portrait,1.25,0.35)
		local motion=Theme.Motion
		motion:Confetti(self.main,{count=18,origin=motion:Point(self.main,motion:CenterOf(self.portrait)),spread=0.35,seconds=1.4})
	end
end

function Controller:Dismiss(immediate)
	local gui,panel=self.gui,self.panel
	if not gui or (self.closing and not immediate) then return end
	self.closing=true
	ContextActionService:UnbindAction("PetRollFreeGiftClose")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	self.app:SetMenuBlur("freeGift",false)
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.closing,self.claimedShown=nil,nil,false,false
		self.main=nil
		gui:Destroy()
	end
	if immediate then finish();return end
	cue("MenuClose",nil,nil,{voiceKey="MenuClose",cooldown=0.2})
	Theme.Motion:Tween(panel,"gift-size",{Size=UDim2.fromScale(PANEL_SIZE.X.Scale*0.97,PANEL_SIZE.Y.Scale*0.97)},0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"gift-fade",{GroupTransparency=1},0.16,nil,nil,finish)
end

local function label(parent,name,value,size,color)
	local item=Theme.Label(parent,name,value,size,color)
	item.TextXAlignment,item.TextScaled=Enum.TextXAlignment.Center,true
	return item
end

-- One requirement card: icon above a short caption.
local function step(parent,name,asset,caption,color,x)
	local card=Theme.Card(parent,name,UDim2.fromScale(0.25,0.86),color)
	card.Position=UDim2.fromScale(x,0.04)
	card.ZIndex=2
	local icon=Theme.Image(card,"Icon",asset,UDim2.fromScale(0.84,0.62),UDim2.fromScale(0.08,0.06))
	icon.ZIndex=4
	local text=label(card,"Caption",caption,30,Theme.Colors.ink)
	text.Position,text.Size,text.ZIndex=UDim2.fromScale(0.05,0.72),UDim2.fromScale(0.9,0.2),5
	return card,icon
end

function Controller:Open()
	if not self:Available() then return end
	if self.gui and not self.closing then return end
	self:Dismiss(true)
	local app=self.app
	-- Acquire the blur before closing other menus so their exit cannot clear it.
	app:SetMenuBlur("freeGift",true)
	app:CloseOtherMenus("freeGift")
	self.previousSelection=GuiService.SelectedObject
	local gui=Theme.InsetContainer(app.other,"FreeGift",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing,self.claimedShown=gui,false,false
	local frames=Theme.Container(gui,"FRAMES")
	local backdrop=Theme.Frame(Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None),"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active=1,true
	local panel=Instance.new("CanvasGroup")
	panel.Name="FreeGift"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.AnchorPoint,panel.Position,panel.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),PANEL_SIZE
	panel.Parent,self.panel=frames,panel
	Theme.Aspect(panel,PANEL_ASPECT)
	local header=Theme.Header(panel,"Header","Free Chicken!",GREEN)
	header.PageIcon.Image,header.PageIcon.Visible=Controller.Assets.Gift,true
	Theme.LayoutHeader(header)
	local main=Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Theme.PageSurfaces.Army)
	main.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	self.main=main
	-- Like (+) Join (=) chicken, then Verify.
	local row=Theme.Container(main,"Steps")
	row.Position,row.Size=UDim2.fromScale(0.03,0.05),UDim2.fromScale(0.94,0.62)
	step(row,"Like",Controller.Assets.Like,"Like the game!",GOLD,0)
	local join=step(row,"Join",Controller.Assets.Group,"Join the group!",BLUE,0.33)
	local plus=label(row,"Plus","+",60,Color3.new(1,1,1))
	plus.Position,plus.Size=UDim2.fromScale(0.25,0.37),UDim2.fromScale(0.08,0.2)
	local equals=label(row,"Equals","=",60,Color3.new(1,1,1))
	equals.Position,equals.Size=UDim2.fromScale(0.58,0.37),UDim2.fromScale(0.08,0.2)
	-- Joining is one tap: Roblox's own join prompt, when the client supports it.
	local groupId=self.gift.groupId
	local joinButton=Instance.new("TextButton")
	joinButton.Name,joinButton.Text,joinButton.BackgroundTransparency="JoinPrompt","",1
	joinButton.Size,joinButton.ZIndex,joinButton.Parent=UDim2.fromScale(1,1),8,join
	Theme.Motion:BindButton(joinButton,join)
	joinButton.Activated:Connect(function()
		app.audio:Play("Click")
		if type(groupId)=="number" then self:PromptJoin(true) end
	end)
	local species=self.gift.species
	local definition=Catalog[species]
	local reward=Theme.Container(row,"Reward")
	reward.Position,reward.Size=UDim2.fromScale(0.66,0),UDim2.fromScale(0.34,1)
	self.reward=reward
	local rays=Theme.Image(reward,"Rays",Theme.Assets.Rays,UDim2.fromScale(1.3,1.1),UDim2.fromScale(-0.15,-0.12))
	rays.ImageColor3,rays.ImageTransparency,rays.ZIndex=GREEN,0.35,2
	-- Slow endless spin (repeat forever, no reverse); reduced motion keeps it still.
	if not app.reducedMotion then
		Theme.Motion:Tween(rays,"spin",{Rotation=360},12,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	end
	local portrait=app:Preview(reward,{species=species,stars=1,level=1},UDim2.fromScale(0.9,0.62),UDim2.fromScale(0.05,0))
	portrait.ZIndex=4
	self.portrait=portrait
	local name=label(reward,"ChickenName",definition.name,30,Color3.new(1,1,1))
	name.Position,name.Size,name.ZIndex=UDim2.fromScale(-0.05,0.62),UDim2.fromScale(1.1,0.2),5
	local oneIn=Catalog.OneInText(species)
	local rarity=label(reward,"Rarity",definition.rarity..(if oneIn then " · "..oneIn else ""),22,Theme.Rarities[definition.rarity] or Color3.new(1,1,1))
	rarity.Position,rarity.Size,rarity.ZIndex=UDim2.fromScale(0,0.82),UDim2.fromScale(1,0.14),5
	local hint=label(main,"Hint","Like the game and join the group, then press Verify!",22,Color3.new(1,1,1))
	hint.Position,hint.Size=UDim2.fromScale(0.05,0.69),UDim2.fromScale(0.9,0.07)
	self.hint=hint
	local actions=Theme.Container(main,"Actions")
	actions.AnchorPoint,actions.Position,actions.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.955),UDim2.fromScale(0.38,0.17)
	Theme.Aspect(actions,4.3)
	local function close()
		if not self.gui or self.closing then return end
		app.audio:Play("Click")
		self:Dismiss()
	end
	Theme.HeaderClose(header,close)
	local verify=Theme.ActionButton(actions,"Verify","Verify",function()
		if self.checking or self.claimedShown then return end
		app.audio:Play("Click")
		self.checking=true
		self:RefreshVerify()
		app:Request("ClaimFreeGift")
	end,GREEN)
	verify.Position,verify.Size=UDim2.fromScale(0,0),UDim2.fromScale(1,1)
	Theme.Studs(verify.Visual.Face,0.07,28,0)
	verify.Visual.Caption.TextScaled=true
	self.verify=verify
	local claimed=label(actions,"Claimed","Claimed! Check your Army",30,GREEN)
	claimed.Size,claimed.Visible=UDim2.fromScale(1,1),false
	self.claimed=claimed
	self:RefreshVerify()
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	if self.gift.claimed then self:ShowClaimed(false) end
	if not app.reducedMotion then panel.Size=UDim2.fromScale(PANEL_SIZE.X.Scale*0.94,PANEL_SIZE.Y.Scale*0.94) end
	Theme.Motion:Tween(panel,"gift-size",{Size=PANEL_SIZE},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out,function()
		Theme.Motion:PopScale(portrait,1.15,0.3)
	end)
	Theme.Motion:Tween(panel,"gift-fade",{GroupTransparency=0},0.22)
	-- Like, +, Join, = and the chicken grow in one after another.
	Theme.Motion:Reveal(row,{limit=6,window=0.3,from=0.75})
	cue("MenuOpen",nil,nil,{voiceKey="MenuOpen",cooldown=0.2})
	ContextActionService:BindActionAtPriority("PetRollFreeGiftClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then close() end
	end))
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=verify end
end

function Controller:Destroy()
	self:Dismiss(true)
end

return Controller
