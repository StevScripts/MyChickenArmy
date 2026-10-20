--!strict
-- October 20: the Auto Collect pass is off sale and the robot vacuum is retired
-- (docs/team/COLLECTION_TOOLS.md; the old stand code is in archive/robot-vacuum-20261020).
-- Until the authored stands leave the six plots in Studio, this only hides each stand's
-- price billboard and glow so nobody is offered the pass. It never opens a purchase.
local Stand = {}
Stand.__index = Stand

function Stand.new(app)
	return setmetatable({app = app, connections = {}, alive = true}, Stand)
end

local function quiet(source: Instance)
	if source:GetAttribute("AutoCollectStand") ~= true then return end
	local anchor = source:FindFirstChild("OfferAnchor")
	local offer = anchor and anchor:FindFirstChild("AutoCollectOffer")
	if offer and offer:IsA("BillboardGui") then offer.Enabled = false end
	for _, item in source:GetDescendants() do
		if item:IsA("ParticleEmitter") and item:GetAttribute("AutoCollectGlow") then item.Enabled = false end
	end
end

function Stand:Start(world: Instance)
	for _, item in world:GetDescendants() do quiet(item) end
	table.insert(self.connections, world.DescendantAdded:Connect(function(item)
		local source = if item:GetAttribute("AutoCollectStand") then item else item:FindFirstAncestor("Gamepass")
		if source then task.defer(function()
			if self.alive and source.Parent then quiet(source) end
		end) end
	end))
end

-- BaseController still steps every controller it starts.
function Stand:Step() end

function Stand:Destroy()
	self.alive = false
	for _, connection in self.connections do connection:Disconnect() end
end

return Stand
