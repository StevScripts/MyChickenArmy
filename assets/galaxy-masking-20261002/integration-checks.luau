-- Focused Edit-mode material lifetime checks; temporary unparented models only.
local client = game.StarterPlayer.StarterPlayerScripts.PetRoll
local chunk = assert(loadstring(client.GalaxyTextureAnimator.Source:gsub("return Galaxy%s*$", "return Galaxy, shared")))
local Galaxy, shared = chunk()
local specialChunk = assert(loadstring(client.SpecialChickenVFX.Source))
setfenv(specialChunk, setmetatable({script = client.SpecialChickenVFX, require = function(module)
	return if module == client.GalaxyTextureAnimator then Galaxy else require(module)
end}, {__index = getfenv(specialChunk)}))
local Special = specialChunk()
local factory = require(game.ReplicatedStorage.PetRoll.Shared.BlenderPetView)
local folder, camera = Instance.new("Folder"), Instance.new("Camera")
local controllers, passed = {}, 0
local function check(value, message)
	assert(value, message)
	passed += 1
end
local ok, problem = xpcall(function()
	local model = factory.Create(folder, "GalaxyQualityCheck", "StormDuck", 1, Vector3.zero, false)
	local baseline = model.Body:FindFirstChildOfClass("SurfaceAppearance")
	camera.CFrame = CFrame.new(model.PrimaryPart.Position + Vector3.new(0, 0, 10))
	local first, second = Special.new(model), Special.new(model:Clone())
	second.model.Parent = folder
	controllers = {first, second}
	first:Step(0, false, camera, "static")
	check(first.galaxy == nil and shared.references == 0 and shared.state == "idle", "Low quality must not allocate Galaxy animation")
	first:Step(1, false, camera, "animated")
	second:Step(1, false, camera, "animated")
	check(shared.references == 2, "Two animated Galaxies share their cache")
	first:Step(2, false, camera, "static")
	check(shared.references == 1 and first.galaxy == nil, "Downshifting one leaves the other owner intact")
	second:Step(2, false, camera, "static")
	check(shared.references == 0 and shared.image == nil and shared.blendImage == nil, "Last downshift releases cache and invalidates in-flight loads")
	task.wait(0.2)
	check(shared.state == "idle" and shared.image == nil, "Cancelled async loads cannot reattach resources")
	first:Step(3, false, camera, "animated")
	local deadline = os.clock() + 20
	repeat
		task.wait(0.05)
		first:Step(os.clock(), false, camera, "animated")
	until first.galaxy.animatedSurface or first.galaxy.error or os.clock() > deadline
	check(first.galaxy.animatedSurface ~= nil, "Current animated PBR still loads: " .. tostring(first.galaxy.error))
	first:Step(os.clock(), false, camera, "static")
	check(baseline.Parent == model.Body and model.Body.Transparency == 0, "Downshift restores original opaque PBR")
	check(shared.image == nil and #shared.frames == 0 and #shared.surfaceImages == 0, "Downshift releases all retained animated images and pixels")
	first:Step(os.clock(), true, camera, "animated")
	check(first.galaxy == nil, "Reduced motion cannot acquire animation")
	model:SetAttribute("PresentationHidden", true)
	first:Step(os.clock(), false, camera, "animated")
	check(first.galaxy == nil, "Hidden chickens cannot acquire animation")
	model:SetAttribute("PresentationHidden", nil)
	camera.CFrame = CFrame.new(0, 0, 1000)
	first:Step(os.clock(), false, camera, "animated")
	check(first.galaxy == nil, "Distant chickens cannot acquire animation")
end, debug.traceback)
for _, controller in controllers do controller:Destroy() end
folder:Destroy()
camera:Destroy()
assert(ok, problem)
return {passed = passed, remainingReferences = shared.references, imagesReleased = shared.image == nil}
