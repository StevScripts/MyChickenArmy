--!strict
local Theme = require(script.Parent.UITheme)
local Config = require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local C = Theme.Colors
local TutorialController = {}
TutorialController.__index = TutorialController
local STEPS = {
	{key = "collectedEggs", title = "Collect your eggs", text = "Walk near eggs in your yard to collect coins."},
	{key = "rolled", title = "Meet your next chicken", text = "Walk to the rolling machine and press E. Every reveal is free."},
	{key = "bought", title = "Grow your flock", text = "Press F at the podium to buy. Chickens lay eggs at home and fight when deployed."},
	{key = "wonCamp", title = "Take your first camp", text = "Walk to the first camp and press E to send your strongest chickens."},
}
if Config.Features.Merging then
	table.insert(STEPS, {key = "upgraded", title = "Level up with merging", text = "Visit the Merge Stand. Merge two chickens of the same type and level."})
end

function TutorialController.new(parent)
	local self = setmetatable({}, TutorialController)
	local card=Theme.Frame(parent,"Objective",UDim2.fromOffset(500,64))
	card.AnchorPoint,card.Position,card.BackgroundTransparency=Vector2.new(0.5,1),UDim2.new(0.5,0,1,-70),1
	self.card=card
	self.body=Theme.Display(card,"Description","",21,Theme.Arcade.gold)
	self.body.Size,self.body.TextXAlignment=UDim2.fromScale(1,1),Enum.TextXAlignment.Center
	-- Keep the tutorial's progress state; only its current instruction is shown in play.
	self.step=Theme.Label(card,"Step","",10);self.step.Visible=false
	self.title=Theme.Label(card,"Title","",12);self.title.Visible=false
	self.fill=Theme.Frame(card,"Progress",UDim2.fromScale(0,0));self.fill.Visible=false
	return self
end

function TutorialController:Update(state, campCount)
	self.card.Visible=state.armyState=="Home"
	local p=state.progression
	local flags = state.tutorial or {}
	local finished = 0
	for _, step in STEPS do if flags[step.key] then finished += 1 end end
	self.fill.Size = UDim2.fromScale(finished / #STEPS, 1)
	for index, step in STEPS do
		if not flags[step.key] then
			self.step.Text = "FIRST EXPEDITION  ·  " .. index .. " / " .. #STEPS
			self.title.Text, self.body.Text = step.title, step.text
			return
		end
	end
	local nextSlot = state.nextSlot
	if nextSlot and nextSlot.unlocked and state.coins >= nextSlot.price then
		self.step.Text = "SQUAD UPGRADE READY"
		self.title.Text = "Grow your army"
		self.body.Text = "Press U to upgrade from " .. state.capacity .. " to " .. (nextSlot.displayCapacity or nextSlot.capacity) .. " fighters."
 elseif state.kingCleared then
  self.step.Text="CHICKEN KING CONQUERED"
  self.title.Text="Flock champion!"
  self.body.Text="Chicken Crown earned! "..(if p then p.goal else "Explore the island.")

	else
		self.step.Text = "CONQUEST  ·  " .. (state.campsWon or 0) .. " / " .. campCount .. " CAMPS"
		self.title.Text = "Conquer your path to the center"
		self.body.Text = if p then "Next: "..p.goal.." · E at its entrance to send your army" else "Press E near the next camp. Your army fights earlier camps in order."
	end
end

function TutorialController:Destroy()
	self.card:Destroy()
end

return TutorialController
