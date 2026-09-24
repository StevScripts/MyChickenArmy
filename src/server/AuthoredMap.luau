--!strict
-- The editable Workspace map is the scenery source. Runtime clones only: gameplay
-- controllers may spawn guards and prompts without changing the builder's models.
local ServerStorage = game:GetService("ServerStorage")
local AuthoredMap = {}
local SOURCE_NAME = "MyChickenArmyMap"

function AuthoredMap.Instantiate()
	local source = workspace:FindFirstChild(SOURCE_NAME) or ServerStorage:FindFirstChild(SOURCE_NAME)
	if not source then return nil end -- Standalone source-only recovery uses the legacy generator.
	assert(source:GetAttribute("MapAuthoringVersion") == 1, "Unknown editable map format")
	local root = Instance.new("Folder")
	root.Name = "PetRollWorld"
	root:SetAttribute("AuthoredMap", true)
	-- Section names organize the editor. Runtime paths retain their established API.
	for _, section in source:GetChildren() do
		if section:GetAttribute("MapSection") then
			for _, original in section:GetChildren() do
				assert(not root:FindFirstChild(original.Name), "Duplicate map root: " .. original.Name)
				local copy = original:Clone()
				copy.Parent = root
			end
		end
	end
	-- Camp art is edited as folders. Only the disposable runtime root needs to
	-- remain a Model for the existing whole-camp attack Highlight.
	for _, camp in root:GetDescendants() do
		if camp:IsA("Folder") and camp:GetAttribute("AuthoredScenery")
			and string.match(tostring(camp:GetAttribute("CommandTarget")), "^camp:%d+$") then
			local model = Instance.new("Model")
			model.Name = camp.Name
			for name, value in camp:GetAttributes() do model:SetAttribute(name, value) end
			for _, tag in camp:GetTags() do model:AddTag(tag) end
			for _, child in camp:GetChildren() do child.Parent = model end
			model.Parent = camp.Parent
			camp:Destroy()
		end
	end
	-- Hide the source during Play. Studio restores Workspace on Stop; no doubled art.
	source.Parent = ServerStorage
	return root
end

return AuthoredMap
