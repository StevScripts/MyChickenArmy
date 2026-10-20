--!strict
-- October 14 Missions (docs/team/MISSIONS_PLAN.md §4): builds one waiting mission
-- site from a theme kit and a seed. The same seed always rebuilds the same site;
-- different seeds give different layouts, hero pieces, palettes and props.
-- Kits live in MissionKits/<Theme>; each returns its parts in reveal groups.
-- Nothing collides or blocks queries, so chickens path straight through.
local TweenService = game:GetService("TweenService")
local Airship = require(script.Parent.InvasionAirship)
local Camp = require(script.Parent.InvasionCamp)
local Kits = script.Parent:WaitForChild("MissionKits")
local Site = {}

-- Theme id -> kit module name. "LoyalistLanding" is today's airship camp.
Site.Themes = {"LoyalistLanding", "WatchtowerFort", "SupplyDepot", "CrystalMine", "PirateCove", "DragonRoost"}
Site.UsesAirship = {LoyalistLanding = true}
-- Themes that only spawn near the island's edge (beach side), when a spot is free.
Site.Coastal = {PirateCove = true}

-- October 20 (owner): sites wear the map's stud MaterialVariants (Plastic-based,
-- in MaterialService's "Stud Material" folder) instead of the black 80% Texture
-- overlay, which is stripped from blocks that came with it. A face at least 2x2
-- studs gets studs; smaller trim gets the weld pattern, like the plots' Fuse
-- machine frames. Bits under 0.8 studs, Neon, glass, balls and cylinders stay plain.
local OVERLAY = "rbxassetid://6372755229"
local STUDS, WELD = "Studs 2x2 Plastic", "Weld 2x2 Plastic"
function Site.Studify(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("Texture") and item.Texture == OVERLAY then item:Destroy(); continue end
		if not item:IsA("BasePart") or item.Transparency >= 1 or item.Material ~= Enum.Material.Plastic then continue end
		if item:IsA("Part") and item.Shape ~= Enum.PartType.Block then continue end
		-- The middle dimension is the short side of the part's largest face.
		local size = item.Size
		local side = size.X + size.Y + size.Z - math.max(size.X, size.Y, size.Z) - math.min(size.X, size.Y, size.Z)
		if side >= 2 then item.MaterialVariant = STUDS elseif side >= 0.8 then item.MaterialVariant = WELD end
	end
end

-- A puff of chunky dust blocks (same look as the crate landings).
local function dust(parent: Instance, at: Vector3, scale: number)
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2 + math.random() * 0.5
		local size = (0.8 + math.random() * 0.8) * scale
		local puff = Airship.Block(parent, "Dust", Vector3.new(size, size, size), CFrame.new(at + Vector3.new(0, 0.5, 0)), Color3.fromRGB(214, 190, 150), nil, false)
		puff.CastShadow = false
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (3 + math.random() * 2) * scale + Vector3.new(0, 1.5 + math.random(), 0)
		TweenService:Create(puff, info, {CFrame = CFrame.new(at + out) * CFrame.Angles(math.random(), math.random(), 0), Transparency = 1, Size = puff.Size * 1.5}):Play()
		task.delay(0.85, function() puff:Destroy() end)
	end
end

-- Build `theme` centred on `frame` (-Z faces away from the owner's base; the open
-- front faces the arriving army). Returns the site model (already parented).
function Site.Build(parent: Instance, theme: string, frame: CFrame, userId: number, seed: number): Model
	local model: Model
	if theme == "LoyalistLanding" then
		model = Camp.Build(parent, frame, userId)
		Site.Studify(model)
	else
		model = Instance.new("Model")
		model.Name = "MissionSite"
		model:SetAttribute("OwnerUserId", userId)
		local center = Airship.Block(model, "Center", Vector3.new(1, 0.2, 1), frame, Color3.new(1, 1, 1), nil, false)
		center.Transparency = 1
		model.PrimaryPart = center
		-- The commander's guide arrow and objective marker point here.
		local marker = Instance.new("Attachment")
		marker.Name, marker.Parent = "Marker", center
		marker.WorldPosition = frame.Position + Vector3.new(0, 0.3, 0)
		-- The command anchor exists before the site is parented, so clients never see a
		-- site without it (CampCommand.Anchor would otherwise fall back to a child
		-- named "Ground").
		local anchor = Instance.new("Part")
		anchor.Name, anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = "CommandCenter", true, false, false, false
		anchor.Transparency, anchor.Size, anchor.CFrame = 1, Vector3.new(1, 1, 1), frame
		anchor.Parent = model
		local kit = require(Kits:WaitForChild(theme)) :: any
		-- Scramble the seed: nearby seeds otherwise start with similar first draws.
		local rng = Random.new((seed * 2654435761) % 2147483647)
		for _ = 1, 4 do rng:NextNumber() end
		local groups = kit.Build(frame, rng)
		model.Parent = parent
		-- Staged reveal: ground, then walls, hero piece and props, each with dust.
		for index, group in groups do
			Site.Studify(group.model)
			-- Kit group names ("Ground", "Walls"…) are prefixed so no child named "Ground"
			-- can stand in for the command anchor.
			group.model.Name = "Site" .. group.model.Name
			task.delay((index - 1) * 0.3, function()
				if not model.Parent then group.model:Destroy(); return end
				group.model.Parent = model
				for _, at in group.dust or {} do dust(model, at, group.dustScale or 1) end
			end)
		end
	end
	model:SetAttribute("Theme", theme)
	model:SetAttribute("Seed", seed)
	-- The walk-up "Send Army" prompt anchors here (CampCommand.Anchor). Kit sites
	-- created theirs above; the Loyalist Landing camp gets one now.
	if not model:FindFirstChild("CommandCenter") then
		local anchor = Instance.new("Part")
		anchor.Name, anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = "CommandCenter", true, false, false, false
		anchor.Transparency, anchor.Size, anchor.CFrame = 1, Vector3.new(1, 1, 1), frame
		anchor.Parent = model
	end
	if not model.Parent then model.Parent = parent end
	return model
end

return Site
