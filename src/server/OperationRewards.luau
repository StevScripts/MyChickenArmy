--!strict
-- Earned scenery reuses the authored throne banner; no new paid/stat benefit.
local Catalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.OperationCatalog)
local Rewards={}

function Rewards.Apply(session,plot,frame)
	local tier=Catalog.BannerTier(session.research.operationWins)
	if plot.operationBannerTier==tier then return tier end
	if plot.operationBanner then plot.operationBanner:Destroy();plot.operationBanner=nil end
	plot.operationBannerTier=tier
	plot.folder:SetAttribute("OperationBannerTier",tier)
	if tier==0 then return tier end
	local source=game.ServerStorage:FindFirstChild("MyChickenArmyMap") or workspace:FindFirstChild("MyChickenArmyMap")
	local section=source and source:FindFirstChild("06_ChickenKing")
	local arena=section and section:FindFirstChild("KingArena")
	local flags=arena and arena:FindFirstChild("Flag")
	local original=flags and flags:FindFirstChild("ThroneFlag")
	local deck=plot.folder:FindFirstChild("Deck")
	if not original or not deck then plot.operationBannerTier=nil;return tier end
	local banner=Instance.new("Model");banner.Name=Catalog.Tiers[tier].."OperationBanner"
	for _,child in original:GetChildren() do child:Clone().Parent=banner end
	for _,part in banner:GetDescendants() do if part:IsA("BasePart") then
		part.Anchored,part.CanCollide,part.CanTouch,part.CanQuery=true,false,false,false
		if part.Color.G<.05 then part.Color=Catalog.Colors[tier] end
	end end
	local bounds,size=banner:GetBoundingBox()
	banner.WorldPivot=bounds
	banner:PivotTo(frame*CFrame.new(deck.Size.X/2-3,size.Y/2+.1,deck.Size.Z/2-3)*CFrame.Angles(0,math.pi/2,0))
	banner.Parent=plot.folder;plot.operationBanner=banner
	return tier
end

function Rewards.Clear(plot)
	if plot.operationBanner then plot.operationBanner:Destroy() end
	plot.operationBanner,plot.operationBannerTier=nil,nil
	plot.folder:SetAttribute("OperationBannerTier",nil)
end

return Rewards
