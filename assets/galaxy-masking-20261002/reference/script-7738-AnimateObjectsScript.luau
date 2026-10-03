local RunService = game:GetService("RunService")

local rng = Random.new()

local viewport: ViewportFrame = script.Parent
local wavyTextMesh: MeshPart = viewport.WavyTextMask.WavyTextMesh
local bubbleClonable: Part = viewport.BubbleClonable

local horizontalWaveSpeed = 3 -- How fast horizontal waves move
local horizontalWaveFreq = 15 -- Frequency of horizontal waves
local horizontalWaveAmp = 0.01 -- Amplitude of vertical waves
local verticalWaveSpeed = 2 -- How fast vertical waves move
local verticalWaveFreq = 2 -- Frequency of vertical waves
local verticalWaveAmp = 0.04 -- Amplitude of vertical waves
local bubbleSpawnDelayRange = Vector2.new(0.07, 0.13)
local bubbleSizeRange = Vector2.new(0.15, 0.8)
local bubbleTimeOnScreenRange = Vector2.new(1, 1.8)
local bubbleWavingSpeedRange = Vector2.new(5, 8)
local bubbleWavingAmplitude = 0.1

-- Set OriginalPosition attribute for each bone
local bones: {Bone} = wavyTextMesh:GetChildren()
for _, bone in bones do
	bone:SetAttribute("OriginalPosition", bone.WorldPosition)
end

-- Creates single bubble and handles its animation and destruction
local function CreateBubble()
	local bubble = bubbleClonable:Clone()
	local startPos = Vector3.new(rng:NextNumber(-2, 2), -1.5, rng:NextNumber(-1.4, -1.2))
	
	local size = rng:NextNumber(bubbleSizeRange.X, bubbleSizeRange.Y)
	local timeOnScreen = rng:NextNumber(bubbleTimeOnScreenRange.X, bubbleTimeOnScreenRange.Y)
	local waveSpeed = rng:NextNumber(bubbleWavingSpeedRange.X, bubbleWavingSpeedRange.Y)

	bubble.Size = Vector3.new(size, size, 0.01)
	bubble.Parent = viewport.Bubbles
	
	-- Start animating bubble in RenderStepped function
	local currentLifetime = 0
	local bubbleAnimateConnection: RBXScriptConnection
	bubbleAnimateConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
		currentLifetime += deltaTime
		local alpha = currentLifetime / timeOnScreen
		
		-- Destroy bubble and its animation connection if it has reached y level of 1 or over
		if bubble.Position.Y >= 1 then
			bubble:Remove()
			bubbleAnimateConnection:Disconnect()
			return
		end
		
		local y = -1.5 - (-1.5 - 1.5) * alpha -- Lerp from -1.5 to 1.5 with alpha to get current y
		local waveOffset = Vector3.new(math.sin(currentLifetime * waveSpeed) * bubbleWavingAmplitude, y, 0)
		bubble.Position = startPos + waveOffset
	end)
end

local currentTime = 0
local waveTime = 0
local currentDelay = rng:NextNumber(bubbleSpawnDelayRange.X, bubbleSpawnDelayRange.Y)
RunService.RenderStepped:Connect(function(deltaTime: number)
	currentTime += deltaTime
	if currentTime >= currentDelay then
		CreateBubble()
		currentTime = 0
		currentDelay = rng:NextNumber(bubbleSpawnDelayRange.X, bubbleSpawnDelayRange.Y)
	end
	
	if viewport:GetAttribute("UpdateTextWaving") then
		waveTime += deltaTime
		for _, bone in bones do
			local originalPosition: Vector3 = bone:GetAttribute("OriginalPosition")
			local xWaveOffset = math.sin(waveTime * horizontalWaveSpeed + originalPosition.Y * horizontalWaveFreq) * horizontalWaveAmp
			local yWaveOffset = math.sin(waveTime * verticalWaveSpeed + originalPosition.X * verticalWaveFreq) * verticalWaveAmp
			bone.WorldPosition = originalPosition + Vector3.new(xWaveOffset, yWaveOffset, 0)
		end
	end
end)