-- Focused Edit-context checks. Uses unparented clones/images only; no Play or player data.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local client = game.StarterPlayer.StarterPlayerScripts.PetRoll
local source = client.GalaxyTextureAnimator.Source
local Galaxy, shared = assert(loadstring((source:gsub("return Galaxy%s*$", "return Galaxy, shared"))))()
local View = assert(loadstring(ReplicatedStorage.PetRoll.Shared.BlenderPetView.Source))
setfenv(View, setmetatable({script = ReplicatedStorage.PetRoll.Shared.BlenderPetView}, {__index = getfenv(View)}))
local factory = View()
local specialChunk = assert(loadstring(client.SpecialChickenVFX.Source))
setfenv(specialChunk, setmetatable({script = client.SpecialChickenVFX}, {__index = getfenv(specialChunk)}))
local Special = specialChunk()
local folder, camera = Instance.new("Folder"), Instance.new("Camera")
local first, second
local passed, report = 0, {}
local function check(condition, message)
	assert(condition, message)
	passed += 1
end
local ok, problem = xpcall(function()
	local model = factory.Create(folder, "GalaxyCheck", "StormDuck", 1, Vector3.zero, false)
	check(model and model.Body.Transparency == 0, "Factory must create an opaque Galaxy")
	camera.CFrame = CFrame.new(model.PrimaryPart.Position + Vector3.new(0, 0, 10))
	local scheduler = Special.new(model)
	scheduler.body, scheduler.root, scheduler.appearance = model.Body, model.PrimaryPart, "Galaxy"
	local textureSteps, particleSteps = 0, 0
	scheduler.galaxy = {Step = function() textureSteps += 1 end, Destroy = function() end}
	scheduler._place = function() particleSteps += 1 end
	for frame = 0, 59 do scheduler:Step(frame / 60, false, camera) end
	check(textureSteps == 60, "SpecialChickenVFX must forward all 60 texture steps")
	check(particleSteps >= 15 and particleSteps <= 20, "Keep particles throttled")
	scheduler:Destroy()
	local baseline = model.Body:FindFirstChildOfClass("SurfaceAppearance")
	local other = model:Clone()
	other.Parent = folder
	first, second = Galaxy.new(model), Galaxy.new(other)
	camera.CFrame = CFrame.new(model.PrimaryPart.Position + Vector3.new(0, 0, 10))
	local deadline = os.clock() + 30
	repeat
		first:Step(0, false, camera)
		if first.animatedSurface or first.error then break end
		task.wait(0.05)
	until os.clock() > deadline
	check(first.animatedSurface ~= nil, "Animated PBR failed to load: " .. tostring(first.error))
	check(#shared.frames == 24, "Keep all 24 authored frames")
	second:Step(0, false, camera)
	check(first.animatedSurface.ColorMapContent == second.animatedSurface.ColorMapContent, "Share the displayed texture")
	local image = shared.image
	local changes, previous = 0, buffer.tostring(shared.frames[1])
	local started = os.clock()
	for frame = 1, 60 do
		local now = frame / 60
		first:Step(now, false, camera)
		check(shared.lastUpdate == now, "Update on every render step")
		local pixels = image:ReadPixelsBuffer(Vector2.zero, shared.size)
		local encoded = buffer.tostring(pixels)
		if encoded ~= previous then changes += 1 end
		previous = encoded
		second:Step(now, false, camera)
		check(shared.lastUpdate == now and shared.image == image, "Second chicken must reuse the same composite")
	end
	report.sampleLoopMs = (os.clock() - started) * 1000
	check(changes == 60, "Texture must actually change on all 60 samples, not just on authored keys")
	first:Step(0, false, camera)
	check(buffer.tostring(image:ReadPixelsBuffer(Vector2.zero, shared.size)) == buffer.tostring(shared.frames[1]), "Exact first key")
	first:Step(4, false, camera)
	check(buffer.tostring(image:ReadPixelsBuffer(Vector2.zero, shared.size)) == buffer.tostring(shared.frames[1]), "Preserve four-second loop")
	first:Step(23.5 / 6, false, camera)
	check(first.frame == 24, "Last key blends toward the first")
	local last, nextFrame = shared.frames[24], shared.frames[1]
	local blended = image:ReadPixelsBuffer(Vector2.zero, shared.size)
	for offset = 0, buffer.len(blended) - 4, 4 do
		assert(buffer.readu8(blended, offset + 3) == 255, "Blending must not fade the face")
		for channel = 0, 2 do
			local expected = (buffer.readu8(last, offset + channel) + buffer.readu8(nextFrame, offset + channel)) / 2
			assert(math.abs(buffer.readu8(blended, offset + channel) - expected) <= 2, "Incorrect loop-seam blend")
		end
	end
	check(true, "Every loop-seam pixel is blended and opaque")
	local compositeStart = os.clock()
	for frame = 1, 120 do first:Step(10 + frame / 60, false, camera) end
	report.compositeAverageMs = (os.clock() - compositeStart) * 1000 / 120
	first:Step(20, true, camera)
	check(first.state == "reduced" and baseline.Parent == model.Body, "Reduced motion restores authored PBR")
	local lastUpdate = shared.lastUpdate
	second:Step(21, true, camera)
	check(shared.lastUpdate == lastUpdate, "No compositing when all users are reduced")
	first:Step(22, false, camera)
	check(first.animatedSurface ~= nil, "Animation resumes after reduced motion")
	model:SetAttribute("PresentationHidden", true)
	first:Step(23, false, camera)
	check(first.state == "hidden" and baseline.Parent == model.Body, "Hidden models restore authored PBR")
	first:Destroy()
	check(shared.references == 1 and shared.image ~= nil, "One remaining owner keeps the shared images")
	second:Destroy()
	check(shared.references == 0 and shared.image == nil and shared.blendImage == nil, "Last owner releases both images")
	report.renderSamplesChanged = changes
end, debug.traceback)
if first then first:Destroy() end
if second then second:Destroy() end
folder:Destroy()
camera:Destroy()
assert(ok, problem)
report.assertions = passed
return game:GetService("HttpService"):JSONEncode(report)
