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
	-- Hide the source during Play. Studio restores Workspace on Stop; no doubled art.
	source.Parent = ServerStorage
	return root
end

return AuthoredMap
