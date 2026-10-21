--!strict
-- October 20 big chicken label (docs/team/CHICKEN_LABELS.md), copied from the Drop a
-- Fruit reference: the chicken nearest you in your own yard shows "LVL 3", its name
-- in its rarity colour and the Coins it lays per second, sized in the world so it
-- grows as you walk up. One label at a time keeps phones light; that chicken's small
-- nameplate hides meanwhile and every other chicken keeps its own. With Chicken Feed
-- in hand and in reach the top line reads "LVL 3 → LVL 4", and a Feed level pops the
-- label and floats "Level N!" off the chicken in its rarity colour (WorldFeel:Text).
-- October 21 game feel: the label pops in on a new chicken, the Coins/s line punches
-- when it changes and the "→ LVL n+1" line breathes while Feed is in hand.
-- Presentation only: ToolController still owns the Feed prompt and the server owns
-- every number.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TextService=game:GetService("TextService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Config=require(Shared.Config)
local Tools=require(Shared.VacuumConfig)
local UIColors=require(Shared.UIColors)
local Theme=require(script.Parent.UITheme)
local Label={}
Label.__index=Label

local POLL_SECONDS=0.1
-- Your chickens within this many studs (flat) of you can carry the label.
local RANGE=24
-- A roaming neighbour takes the label only once it is clearly nearer, so the label
-- never flickers between two chickens. With Feed in hand the plain nearest wins, the
-- same rule as ToolController's prompt, so the arrow is on the chicken it feeds.
local SWITCH_STUDS=1.5
-- The label in studs, and its three rows as {top, height} shares of that height.
local WIDTH,HEIGHT=7.5,3.4
local LEVEL_ROW,NAME_ROW,VALUE_ROW={0,0.28},{0.25,0.42},{0.67,0.31}
-- Coins row: the coin's share of the row height, and the gap after it.
local COIN,GAP=0.92,0.12

local function holdingFeed(): boolean
	local character=Players.LocalPlayer.Character
	local tool=character and character:FindFirstChildOfClass("Tool")
	return tool~=nil and (tool:GetAttribute("PetRollTool")=="ChickenFeed" or tool.Name=="ChickenFeed")
end

-- Width over height of one line of text, to lay out the Coins row in studs.
local function aspect(text: string): number
	local size=TextService:GetTextSize(text,100,Theme.Font,Vector2.new(10000,1000))
	return size.X/math.max(1,size.Y)
end

local function line(parent: Instance,name: string,row: {number},color: Color3): TextLabel
	local label=Theme.Display(parent,name,"",30,color)
	label.Position,label.Size=UDim2.fromScale(0,row[1]),UDim2.fromScale(1,row[2])
	label.TextScaled,label.TextWrapped=true,false
	label.TextXAlignment=Enum.TextXAlignment.Center
	return label
end

function Label.new(app)
	local self=setmetatable({app=app,connections={},nextPollAt=0,shown={},breathing=false},Label)
	local gui=Instance.new("BillboardGui")
	gui.Name,gui.Size,gui.SizeOffset="ChickenLabel",UDim2.fromScale(WIDTH,HEIGHT),Vector2.new(0,0.5)
	gui.AlwaysOnTop,gui.LightInfluence,gui.MaxDistance=true,0,80
	gui.ResetOnSpawn,gui.Enabled=false,false
	-- Pops grow up from the label's foot, never down into the chicken.
	local holder=Theme.Container(gui,"Pop")
	holder.AnchorPoint,holder.Position=Vector2.new(0.5,1),UDim2.fromScale(0.5,1)
	self.level=line(holder,"Level",LEVEL_ROW,UIColors.Text)
	self.name=line(holder,"Name",NAME_ROW,UIColors.Text)
	local row=Theme.Container(holder,"Coins")
	row.Position,row.Size=UDim2.fromScale(0,VALUE_ROW[1]),UDim2.fromScale(1,VALUE_ROW[2])
	self.coin=Theme.CoinIcon(row,"CoinIcon",UDim2.fromScale(0.1,COIN))
	self.amount=line(row,"Amount",{0,1},UIColors.Coins)
	gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui,self.holder=gui,holder
	table.insert(self.connections,RunService.Heartbeat:Connect(function() self:Step(os.clock()) end))
	return self
end

-- The snapshot's entry for a chicken, indexed once per chicken list.
function Label:Pet(id: any)
	local state=self.app.state
	local pets=state and state.pets
	if type(id)~="string" or type(pets)~="table" then return nil end
	if self.list~=pets then
		self.list,self.byId=pets,{}
		for _,pet in pets do self.byId[pet.id]=pet end
	end
	return self.byId[id]
end

-- Your nearest chicken at home within RANGE, and its flat distance.
function Label:Nearest(feeding: boolean): (Model?,number)
	local state=self.app.state
	local character=Players.LocalPlayer.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local world=workspace:FindFirstChild("PetRollWorld")
	local plot=state and world and world:FindFirstChild("Plot"..tostring(state.plotIndex))
	local pets=plot and plot:FindFirstChild("Pets")
	if not root or not root:IsA("BasePart") or not pets then return nil,math.huge end
	local me,from=Players.LocalPlayer.UserId,root.Position
	local best: Model?,bestDistance,currentDistance=nil,RANGE,math.huge
	for _,model in pets:GetChildren() do
		if not model:IsA("Model") then continue end
		local part=model.PrimaryPart
		if part and model:GetAttribute("AtHome")~=false
			and (model:GetAttribute("OwnerUserId") or model:GetAttribute("OwnerId"))==me then
			local distance=Vector2.new(part.Position.X-from.X,part.Position.Z-from.Z).Magnitude
			if distance<=bestDistance then best,bestDistance=model,distance end
			if model==self.model then currentDistance=distance end
		end
	end
	if not feeding and best~=self.model and currentDistance<=RANGE and currentDistance-bestDistance<SWITCH_STUDS then
		return self.model,currentDistance
	end
	return best,bestDistance
end

function Label:Step(now: number)
	if now<self.nextPollAt then return end
	self.nextPollAt=now+POLL_SECONDS
	local feeding=holdingFeed()
	local model,distance=self:Nearest(feeding)
	local pet=model and self:Pet(model:GetAttribute("PetId"))
	-- Cutscenes and roll reveals own the screen.
	local camera=workspace.CurrentCamera
	if not model or not pet or not camera or camera.CameraType==Enum.CameraType.Scriptable then
		self:SetTarget(nil)
		return
	end
	self:SetTarget(model)
	self:Render(pet,feeding and distance<=Tools.FeedRange)
end

-- Moves the label to another chicken (nil hides it) and gives the last one back its
-- nameplate.
function Label:SetTarget(model: Model?)
	if model==self.model then
		if model then self:Place() end
		return
	end
	self:ShowNameplate()
	self.model,self.shown=model,{}
	if self.breathing then
		self.breathing=false
		Theme.Motion:StopBreathe(self.level)
	end
	local gui=self.gui
	if not model then
		gui.Enabled,gui.Adornee=false,nil
		return
	end
	-- PetView parks the nameplate ("Tag") on the root part.
	local root=model.PrimaryPart
	local tag=root and root:FindFirstChild("Tag") or model:FindFirstChild("Tag",true)
	self.tag=if tag and tag:IsA("BillboardGui") then tag else nil
	local part=self.tag and self.tag.Parent
	gui.Adornee=if part and part:IsA("BasePart") then part else model.PrimaryPart
	self:HideNameplate()
	self:Place()
	gui.Enabled=true
	Theme.Motion:PopScale(self.holder,0.7,0.26) -- Grows in on its new chicken.
end

-- The label stands on the small nameplate's spot, which ChickenGrowth raises as the
-- chicken grows.
function Label:Place()
	local tag=self.tag
	local offset=if tag and tag.Parent then tag.StudsOffset else Vector3.new(0,3,0)
	if self.gui.StudsOffset~=offset then self.gui.StudsOffset=offset end
end

-- Only the text's transparency changes: the server (PetView) and BattleController own
-- the nameplate's Enabled and Visible.
function Label:HideNameplate()
	local text=self.tag and self.tag:FindFirstChild("NameLabel")
	if not text or not text:IsA("TextLabel") then return end
	self.hidden={label=text,text=text.TextTransparency,stroke=text.TextStrokeTransparency}
	text.TextTransparency,text.TextStrokeTransparency=1,1
end

function Label:ShowNameplate()
	local hidden=self.hidden
	self.hidden=nil
	if hidden and hidden.label.Parent then
		hidden.label.TextTransparency,hidden.label.TextStrokeTransparency=hidden.text,hidden.stroke
	end
end

-- arrow: Feed is in hand and this chicken is within its reach.
function Label:Render(pet,arrow: boolean)
	local definition=Catalog[pet.species]
	local level=pet.level or 1
	local nextLevel=arrow and level<(pet.levelCap or Config.MaxPetLevel)
	local levelText=if nextLevel then "LVL "..level.." → LVL "..(level+1) else "LVL "..level
	-- An Army chicken at home outside the Flock lays nothing.
	local laying=pet.laying~=false
	local value=if laying then Theme.Number(pet.income or 0).."/s" else "Not laying"
	local shown=self.shown
	if shown.level~=levelText then
		shown.level=levelText
		self.level.Text=levelText
	end
	-- The "→ LVL n+1" line breathes while Feed is in hand and in reach.
	if nextLevel~=self.breathing then
		self.breathing=nextLevel
		if nextLevel then Theme.Motion:Breathe(self.level,1.05,0.7) else Theme.Motion:StopBreathe(self.level) end
	end
	if shown.species~=pet.species then
		shown.species=pet.species
		self.name.Text=if definition then definition.name else "Chicken"
		self.name.TextColor3=definition and Theme.Rarities[definition.rarity] or UIColors.Text
	end
	if shown.value~=value then
		local changed=shown.value~=nil
		shown.value=value
		self:LayoutCoins(value,laying)
		if changed then Theme.Motion:Punch(self.amount,1.2,0.3) end -- A new Coins/s (a Feed level).
	end
end

-- The coin and the number centred together as one row, in the label's stud scale.
function Label:LayoutCoins(text: string,coin: boolean)
	local share=VALUE_ROW[2]*HEIGHT/WIDTH -- the row's height as a share of its width
	local icon=if coin then share*COIN else 0
	local gap=if coin then share*GAP else 0
	local width=math.min(1-icon-gap,aspect(text)*share*1.08)
	local left=(1-icon-gap-width)/2
	self.coin.Visible=coin
	self.coin.Position,self.coin.Size=UDim2.fromScale(left,(1-COIN)/2),UDim2.fromScale(icon,COIN)
	self.amount.Position,self.amount.Size=UDim2.fromScale(left+icon+gap,0),UDim2.fromScale(width,1)
	self.amount.Text=text
	self.amount.TextColor3=if coin then UIColors.Coins else UIColors.Muted
end

-- A Feed level: the label pops with its new numbers and "Level N!" floats off the
-- chicken in its rarity colour (WorldFeel:Text keeps it, without the rise, under
-- reduced motion). ToolController plays the crunch, crumbs, flash, hop and cluck.
function Label:LevelUp(petId: string)
	self.nextPollAt=0
	self:Step(os.clock())
	local model=self.model
	if model and model:GetAttribute("PetId")==petId then Theme.Motion:PopScale(self.holder,1.3,0.32) end
	local feel=self.app.worldFeel
	local target=self.app.base:HomePet(petId)
	if not feel or not target or not target:IsA("Model") or not target.PrimaryPart then return end
	local pet=self:Pet(petId)
	local definition=pet and Catalog[pet.species]
	local tag=target:FindFirstChild("Tag",true)
	local lift=(if tag and tag:IsA("BillboardGui") then tag.StudsOffset.Y else 3)*0.55
	feel:Text(target.PrimaryPart.Position+Vector3.new(0,lift,0),if pet and pet.level then "Level "..pet.level.."!" else "Level up!",
		{color=(definition and Theme.Rarities[definition.rarity]) or Theme.Arcade.gold,coin=false,size=34,seconds=1.2,rise=2.4})
end

function Label:Receive(_state,result)
	if result and result.ok and result.action=="FeedChicken" and type(result.petId)=="string" then
		self:LevelUp(result.petId)
	end
end

function Label:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	self:ShowNameplate()
	self.gui:Destroy()
end

return Label
