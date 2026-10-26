--!strict
-- October 16 free gift popup: like the game + join the group, then Verify for one
-- free chicken. The server checks the group and grants; this only presents.
-- October 21 (Stevin): no in-game join prompt. Players join the group themselves
-- from the game page (so they seek the game out); the popup only checks membership.
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local Catalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.PetCatalog)
local Theme=require(script.Parent.UITheme)
local Controller={}
Controller.__index=Controller
local GREEN=Theme.ReferenceColors.Army
local GOLD=Theme.ReferenceColors.Base
local BLUE=Theme.ReferenceColors.Upgrades
local GIFT_BOX="rbxassetid://85740083144452" -- assets/free-gift-20261016 gift-box.png
Controller.Assets={
	-- October 23 (Stevin): the HUD button shows the chunky gift box, not the chicken;
	-- the chicken is revealed in the popup's reward card.
	Gift=GIFT_BOX,
	Like="rbxassetid://123763953639040",
	Group="rbxassetid://109146933804070",
}
-- October 21 reference parity (docs/team/REFERENCE_PARITY_20261021.md §1 t51/t158,
-- §2.7): the popup is the reference's "Free Reward!" 1:1: a blue studded header with
-- the gift box and the red X; a "YOUR REWARD:" card with the gift chicken over rays
-- and its name; numbered task rows ("1. Like the game  Like!", "2. Join the group
-- Join!") that turn into a green check when done; a white Claim! that asks the server.
-- The reference window is 455 px wide; ours has more rows, so it is 0.95:1.
local PANEL_SIZE,PANEL_POSITION,PANEL_ASPECT=UDim2.fromScale(0.9,0.62),UDim2.fromScale(0.5,0.55),0.95
local ACTION=GOLD:Lerp(Color3.fromRGB(255,240,90),0.6) -- the reference's yellow "Like!" / "Join!"
local DONE=Color3.fromRGB(112,222,98)
local DARK_TEXT=Color3.fromRGB(26,28,32)
-- Body layout (fractions of the body): the reward card, three rows, then Claim!, whose
-- hit reaches from row 3's hit down to the window's foot (48 px on a phone).
-- October 23: the card gave room for the third row (5 minutes of play).
local CARD_Y,CARD_H=0.03,0.42
local ROW_Y,ROW_STEP,ROW_HEIGHT=0.47,0.112,0.092
local ROWS=3
local CLAIM_Y,CLAIM_H,CLAIM_W=0.82,0.14,0.55
-- The reference's refusal banner when the group check fails.
local GROUP_COPY="Join our group from the game page to claim this reward!"
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

local function clock(seconds: number): string
	seconds=math.max(0,math.floor(seconds))
	return string.format("%d:%02d",seconds//60,seconds%60)
end

-- October 23 (Stevin): the free chicken also needs 5 minutes of total playtime. The
-- server sends the total at its time `playedAt`; this counts on from it between packets.
function Controller:Played(): (number, number)
	local gift=self.gift
	if type(gift)~="table" then return 0,0 end
	local minimum=tonumber(gift.minPlaySeconds) or 0
	local base,at=tonumber(gift.playSeconds),tonumber(gift.playedAt)
	if not base or not at then return minimum,minimum end -- Older servers: no time requirement.
	return base+math.max(0,workspace:GetServerTimeNow()-at),minimum
end

function Controller:PlayRemaining(): number
	local played,minimum=self:Played()
	return math.max(0,math.ceil(minimum-played))
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
		local notInGroup=not result.ok and type(result.freeGift)=="table" and result.freeGift.notInGroup==true
		if notInGroup then self.joined=false end
		if self.gui then
			if result.ok then self:ShowClaimed(true)
			else
				self:RefreshClaim()
				self:RefreshRows(false)
				if self.claim then Theme.Motion:Shake(self.claim.Visual,6) end
			end
		end
		if notInGroup then
			-- The reference's red banner. The server's own refusal was shown a moment ago
			-- in the same packet; this replaces it unless the server already says this.
			if result.message~=GROUP_COPY then self.app:Notify(GROUP_COPY,false) end
		end
	elseif self.gui and type(self.gift)=="table" and self.gift.claimed and not self.claimedShown then
		self:ShowClaimed(false)
	end
end

function Controller:RefreshClaim()
	local claim=self.claim
	if not claim then return end
	claim.Text=if self.checking then "Checking…" else "Claim!"
	claim.Active=not self.checking
end

-- A done task swaps its yellow action for a green check (popping when it just changed).
function Controller:RefreshRows(celebrate: boolean)
	for key,row in self.rows or {} do
		local done=self.claimedShown==true or (if key=="Like" then self.liked==true
			elseif key=="Play" then self:PlayRemaining()<=0 else self.joined==true)
		if row.done~=done then
			row.done=done
			row.action.Visible,row.check.Visible=not done,done
			row.button.Active=not done
			if done and celebrate then Theme.Motion:Punch(row.check,1.4,0.3) end
		end
	end
	-- The play row tracks the time so far ("2:13/5:00") until it turns into a check.
	local play=self.rows and self.rows.Play
	if play and not play.done then
		local played,minimum=self:Played()
		play.action.Text=clock(math.min(played,minimum)).."/"..clock(minimum)
	end
end

function Controller:ShowClaimed(celebrate)
	if not self.gui or self.claimedShown then return end
	self.claimedShown=true
	self.claim.Visible=false
	self.claimed.Visible=true
	self:RefreshRows(celebrate)
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
	if self.claim then Theme.Motion:StopBreathe(self.claim.Visual) end
	self.app:SetMenuBlur("freeGift",false)
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.closing,self.claimedShown=nil,nil,false,false
		self.main,self.claim,self.claimed,self.rows=nil,nil,nil,nil
		self.ticking=nil
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

-- One numbered task row: a dark row card, the task on the left and its yellow action
-- (or the green check once done) on the right. The whole row is the button.
function Controller:Row(parent,key,text,action,y,callback)
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.AutoButtonColor,button.Selectable=key,"",false,true
	button.BackgroundTransparency,button.BorderSizePixel=1,0
	button.Position,button.Size=UDim2.fromScale(0.031,y),UDim2.fromScale(0.938,ROW_HEIGHT)
	button:SetAttribute("RejectShake",false) -- A done row simply rests.
	button.Parent=parent
	local visual=Theme.Frame(button,"Visual",UDim2.fromScale(1,1),Color3.fromRGB(14,16,18))
	visual.AnchorPoint,visual.Position,visual.BackgroundTransparency=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),0.3
	local stroke=Theme.Stroke(visual,Color3.new(0,0,0),2)
	stroke.Transparency=0.25
	local caption=Theme.Label(visual,"Task",text,26,Color3.new(1,1,1))
	caption.Position,caption.Size,caption.TextScaled,caption.ZIndex=UDim2.fromScale(0.035,0.14),UDim2.fromScale(0.64,0.72),true,5
	local word=Theme.Label(visual,"Action",action,26,ACTION)
	word.Position,word.Size,word.TextScaled,word.ZIndex=UDim2.fromScale(0.69,0.14),UDim2.fromScale(0.28,0.72),true,5
	word.TextXAlignment=Enum.TextXAlignment.Right
	local check=label(visual,"Check","✓",40,DONE)
	check.AnchorPoint,check.Position,check.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.92,0.5),UDim2.fromScale(0.12,1)
	check.ZIndex,check.Visible=6,false
	check.TextOutline.Thickness=0.09
	-- The hit fills the row's whole step (no gap left between the two rows).
	Theme.PadHit(button,1,ROW_STEP/ROW_HEIGHT)
	Theme.Motion:BindButton(button,visual)
	button.Activated:Connect(function() if button.Active then callback() end end)
	return {button=button,action=word,check=check,done=false}
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
	panel.AnchorPoint,panel.Position,panel.Size=Vector2.new(0.5,0.5),PANEL_POSITION,PANEL_SIZE
	panel.Parent,self.panel=frames,panel
	Theme.Aspect(panel,PANEL_ASPECT)
	local header=Theme.Header(panel,"Header","Free Reward!",BLUE)
	header.PageIcon.Image,header.PageIcon.Visible=GIFT_BOX,true
	Theme.LayoutHeader(header)
	local main=Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Theme.OverlayColors.Top)
	main.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	self.main=main
	-- "YOUR REWARD:": the gift chicken (portrait with its black stroke) over rays, and its name.
	local species=self.gift.species
	local definition=Catalog[species]
	local card=Theme.Frame(main,"Reward",UDim2.fromScale(0.938,CARD_H),Color3.fromRGB(34,38,42))
	card.Position,card.BackgroundTransparency=UDim2.fromScale(0.031,CARD_Y),0.3
	Theme.Stroke(card,Color3.new(0,0,0),2)
	self.reward=card
	local title=label(card,"Title","YOUR REWARD:",30,Color3.new(1,1,1))
	title.Position,title.Size,title.ZIndex=UDim2.fromScale(0.06,0.04),UDim2.fromScale(0.88,0.15),6
	local art=Theme.Container(card,"Art")
	art.AnchorPoint,art.Position,art.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.52),UDim2.fromScale(0.6,0.56)
	Theme.Aspect(art,1)
	local rays=Theme.Image(art,"Rays",Theme.Assets.Rays,UDim2.fromScale(1.7,1.7),UDim2.fromScale(0.5,0.5))
	rays.AnchorPoint,rays.ImageColor3,rays.ImageTransparency,rays.ZIndex=Vector2.new(0.5,0.5),Color3.new(1,1,1),0.55,3
	-- Slow endless spin (repeat forever, no reverse); reduced motion keeps it still.
	if not app.reducedMotion then
		Theme.Motion:Tween(rays,"spin",{Rotation=360},16,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	end
	local portrait=app:Preview(art,{species=species,stars=1,level=1},UDim2.fromScale(1,1),UDim2.fromScale(0,0))
	portrait.ZIndex=4
	self.portrait=portrait
	local name=label(card,"ChickenName",definition.name,40,Theme.Rarities[definition.rarity] or Color3.new(1,1,1))
	name.AnchorPoint,name.Position,name.Size,name.ZIndex=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.86),UDim2.fromScale(0.92,0.17),6
	-- The task rows: Like is honor-system copy (Roblox has no like API); Join only
	-- explains where to join (no in-game prompt) and turns into a check once the
	-- player is a member.
	local _,minimum=self:Played()
	self.rows={
		Like=self:Row(main,"Like","1. Like the game","Like!",ROW_Y,function()
			self.liked=true
			self:RefreshRows(true)
		end),
		Join=self:Row(main,"Join","2. Join the group","Join!",ROW_Y+ROW_STEP,function()
			self.app:Notify(GROUP_COPY,true)
		end),
		Play=self:Row(main,"Play","3. Play for "..math.max(1,math.round(minimum/60)).." minutes","",ROW_Y+ROW_STEP*2,function()
			self.app:Notify("Keep playing! Your free chicken unlocks in "..clock(self:PlayRemaining())..".",true)
		end),
	}
	-- Tick the play row once a second while the popup is open; it checks itself at 5:00.
	self.ticking=gui
	task.spawn(function()
		while self.ticking==gui do
			task.wait(1)
			if self.ticking~=gui or self.gui~=gui then break end
			self:RefreshRows(true)
		end
	end)
	local groupId=self.gift.groupId
	local player=game:GetService("Players").LocalPlayer
	if player and type(groupId)=="number" and not self.joined then
		-- Display only: a member's row starts checked (the server verifies the claim).
		task.spawn(function()
			local ok,member=pcall(player.IsInGroup,player,groupId)
			if ok and member and self.gui==gui then self.joined=true;self:RefreshRows(false) end
		end)
	end
	-- A white Claim! (the reference's), centred under the rows.
	local actions=Theme.Container(main,"Actions")
	actions.AnchorPoint,actions.Position,actions.Size=Vector2.new(0.5,0),UDim2.fromScale(0.5,CLAIM_Y),UDim2.fromScale(CLAIM_W,CLAIM_H)
	local function close()
		if not self.gui or self.closing then return end
		self:Dismiss()
	end
	-- Phone hit area: 48 px; the X's pad reaches down over the (untappable) reward card.
	Theme.HeaderClose(header,close,3.6):SetAttribute("ClickSound",false)
	local claim=Theme.ActionButton(actions,"Claim","Claim!",function()
		if self.checking or self.claimedShown then return end
		-- Not 5 minutes yet: say how long is left (no server lookup).
		local remaining=self:PlayRemaining()
		if remaining>0 then
			Theme.Motion:Shake(self.claim.Visual,6)
			if self.rows and self.rows.Play then Theme.Motion:Punch(self.rows.Play.action,1.2,0.3) end
			app:Notify("Keep playing! Your free chicken unlocks in "..clock(remaining)..".",false)
			return
		end
		self.checking=true
		self:RefreshClaim()
		app:Request("ClaimFreeGift")
	end,Color3.new(1,1,1))
	claim.Position,claim.Size=UDim2.fromScale(0,0),UDim2.fromScale(1,1)
	claim.TextColor3=DARK_TEXT
	Theme.Studs(claim.Visual.Face,0.07,28,0)
	claim.Visual.Caption.TextScaled=true
	claim.Visual.Caption.TextShadow.Visible=false
	claim.Visual.Caption.TextFace.TextOutline.Color=Color3.new(1,1,1)
	-- The hit grows up to the last row's hit and down to the window's foot, never past them.
	local above=CLAIM_Y-(ROW_Y+ROW_STEP*(ROWS-0.5)+ROW_HEIGHT/2)
	local below=1-CLAIM_Y-CLAIM_H
	Theme.PadHit(claim,1.05,(above+CLAIM_H+below)/CLAIM_H,0.5,above/(above+below))
	self.claim=claim
	local claimed=label(actions,"Claimed","Claimed!",30,GREEN)
	claimed.Size,claimed.Visible=UDim2.fromScale(1,1),false
	self.claimed=claimed
	self:RefreshClaim()
	self:RefreshRows(false)
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	if self.gift.claimed then self:ShowClaimed(false) end
	if not app.reducedMotion then panel.Size=UDim2.fromScale(PANEL_SIZE.X.Scale*0.94,PANEL_SIZE.Y.Scale*0.94) end
	Theme.Motion:Tween(panel,"gift-size",{Size=PANEL_SIZE},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out,function()
		Theme.Motion:PopScale(portrait,1.15,0.3)
	end)
	Theme.Motion:Tween(panel,"gift-fade",{GroupTransparency=0},0.22)
	-- The reward card and the rows grow in one after another; Claim! breathes.
	Theme.Motion:Reveal(main,{limit=4,window=0.3,from=0.8})
	if not self.claimedShown then Theme.Motion:Breathe(claim.Visual,1.04,0.7) end
	cue("MenuOpen",nil,nil,{voiceKey="MenuOpen",cooldown=0.2})
	ContextActionService:BindActionAtPriority("PetRollFreeGiftClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then close() end
	end))
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=claim end
end

function Controller:Destroy()
	self:Dismiss(true)
end

return Controller
