-- Run through Studio Flow in canonical Pet Roll Test Edit mode only.
-- Scene art only: mapped ModuleScript sources remain owned by Rojo.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning(), "Expected Pet Roll Test Edit mode")
local storage = game:GetService("ServerStorage")
local Theme = require(game.StarterPlayer.StarterPlayerScripts.PetRoll.UITheme)
local vacuum = game.ReplicatedStorage.PetRoll.Assets.EggVacuum
local targets = {}
local plots = workspace.MyChickenArmyMap["03_HomePlots"]
for index=1,6 do
	local plot = plots:FindFirstChild("Plot"..index)
	assert(plot and plot.Props:FindFirstChild("Gamepass"), "Missing stand for Plot"..index)
	table.insert(targets, {stand=plot.Props.Gamepass, key="Plot"..index})
end
table.insert(targets, {stand=storage.PetRollPlotAssets.AuthoredHomePlot.Props.Gamepass, key="Template"})
for _,target in targets do
	local pad = target.stand:FindFirstChild("AutoCollectPad")
	if not pad then
		for _,part in target.stand:GetChildren() do
			if part:IsA("BasePart") and part.Transparency < 1 and part.CanCollide
				and (not pad or part.Position.Y > pad.Position.Y) then pad=part end
		end
	end
	assert(pad and pad:IsA("BasePart"), "Missing purchase pad: "..target.key)
	target.pad = pad
end
local recovery = storage:FindFirstChild("AutoCollectStandRecovery20260925")
if not recovery then recovery=Instance.new("Folder"); recovery.Name="AutoCollectStandRecovery20260925"; recovery.Parent=storage end
local results = {}
for _,target in targets do
	local stand, pad = target.stand, target.pad
	if not recovery:FindFirstChild(target.key) then
		local backup=stand:Clone(); backup.Name=target.key; backup.Parent=recovery
	end
	-- Suppress reference advertising/rays but keep all original editable objects.
	for _,item in stand:GetDescendants() do
		if item:IsA("BillboardGui") or item:IsA("SurfaceGui") then item.Enabled=false end
		if item:IsA("ParticleEmitter") then item.Enabled=false end
		if item:IsA("JointInstance") and (item.Part0==pad or item.Part1==pad) then item.Enabled=false end
	end
	for _,name in {"AutoCollectPreview", "OfferAnchor"} do
		local previous=stand:FindFirstChild(name)
		if previous then previous:Destroy() end
	end
	pad.Name="AutoCollectPad"
	stand:SetAttribute("AutoCollectStand", true)
	stand:SetAttribute("AutoCollectPassKey", "AutoCollectEggs")
	local preview=vacuum:Clone()
	preview.Name="AutoCollectPreview"
	local _,originalSize=preview:GetBoundingBox()
	local scale=math.min(0.8, math.min(pad.Size.X,pad.Size.Z)*0.85/math.max(originalSize.X,originalSize.Z))
	preview:ScaleTo(scale)
	for _,part in preview:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored,part.CanCollide,part.CanTouch,part.CanQuery=true,false,false,false
			part.CastShadow=false
		end
	end
	local origin=pad.CFrame*CFrame.new(0,pad.Size.Y/2+1.05,0)*CFrame.Angles(0,math.rad(30),0)
	preview:PivotTo(origin)
	preview.Parent=stand
	local bounds,size=preview:GetBoundingBox()
	local anchor=Instance.new("Part")
	anchor.Name,anchor.Size="OfferAnchor",Vector3.new(0.2,0.2,0.2)
	anchor.Anchored,anchor.CanCollide,anchor.CanTouch,anchor.CanQuery=true,false,false,false
	anchor.Transparency=1
	anchor.CFrame=CFrame.new(pad.Position.X,bounds.Position.Y+size.Y/2+1.3,pad.Position.Z)
	anchor.Parent=stand
	local gui=Instance.new("BillboardGui")
	gui.Name,gui.Adornee="AutoCollectOffer",anchor
	gui.Size,gui.MaxDistance=UDim2.fromScale(6.2,1.85),70
	gui.AlwaysOnTop,gui.LightInfluence,gui.ResetOnSpawn=false,0,false
	gui.Parent=anchor
	local function label(name,text,y,height,size,color)
		local result=Theme.Label(gui,name,text,size,color)
		result.Position,result.Size=UDim2.fromScale(0,y),UDim2.fromScale(1,height)
		result.TextXAlignment,result.TextScaled,result.TextWrapped=Enum.TextXAlignment.Center,true,false
		local limit=Instance.new("UITextSizeConstraint")
		limit.MinTextSize,limit.MaxTextSize=10,size
		limit.Parent=result
		return result
	end
	label("Title","Auto Collect Eggs",0,0.4,38,Theme.Colors.white)
	label("Price","Checking price…",0.4,0.36,34,Theme.Colors.green)
	label("Hint","Step on pad to buy",0.78,0.22,20,Theme.Colors.white)
	for _,item in stand:GetDescendants() do
		if item:IsA("ParticleEmitter") and item.Name=="Glow" then
			local attachment=item.Parent
			local part=attachment and attachment.Parent
			if attachment:IsA("Attachment") and part:IsA("BasePart") then
				part.CFrame=pad.CFrame*CFrame.new(0,pad.Size.Y/2+0.55,0)
				attachment.CFrame=CFrame.identity
			end
			item:SetAttribute("AutoCollectGlow",true)
			item.Rate,item.Lifetime,item.Speed=2,NumberRange.new(1.5),NumberRange.new(0)
			item.Size=NumberSequence.new(math.min(pad.Size.X,pad.Size.Z)*0.7)
			item.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.78),NumberSequenceKeypoint.new(1,1)})
			item.Enabled=true
		end
	end
	table.insert(results,{stand=stand:GetFullName(),pad=pad:GetFullName(),previewScale=scale,parts=#preview:GetChildren()})
end
return {stands=results,recovery=recovery:GetFullName()}
