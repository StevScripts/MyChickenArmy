local RunService = game:GetService("RunService")

local rng = Random.new()

local viewport: ViewportFrame = script.Parent
local cube1: Model = viewport.Cube1
local cube2: Model = viewport.Cube2
local letters = {}
for _, child: MeshPart in viewport.Text:GetChildren() do
	letters[tonumber(child.Name)] = child
end

local upDownCycleTime = 3 -- Time it takes to make a full up and down cycle
local upDownDistance = 0.4 -- Maximum distance from y = 0 the letters go up and down
local timeOffset = 0.07 -- Time offset between each consecutive letter
local noiseSpeed = 1 -- Speed of 1d perlin noise used to randomly rotate letters
local maxPitchAngle = 45 -- Maximum angles for letters
local maxYawAngle = 45
local maxRollAngle = 45
local cube1SpinTime = 11 -- Time it takes to make a full spin for cube 1
local cube2SpinTime = 6 -- Time it takes to make a full spin for cube 2

local currentTime = 0
RunService.RenderStepped:Connect(function(deltaTime: number)
	currentTime += deltaTime
	
	for i, letter: MeshPart in letters do
		local pos = letter.Position
		local height = math.sin((currentTime / upDownCycleTime + i * timeOffset) * 2 * math.pi) * upDownDistance
		
		local pitch = math.rad(math.noise(currentTime * noiseSpeed + i * 5000) * maxPitchAngle)
		local yaw = math.rad(math.noise(0, currentTime * noiseSpeed + i * 5000) * maxYawAngle)
		local roll = math.rad(math.noise(0, 0, currentTime * noiseSpeed + i * 5000) * maxRollAngle)
		
		letter.CFrame = CFrame.new(Vector3.new(pos.X, height, pos.Z)) * CFrame.Angles(pitch, yaw, roll)
	end

	cube1:PivotTo(CFrame.new(cube1.WorldPivot.Position) * CFrame.Angles(0, -math.rad(360 / cube1SpinTime) * currentTime, 0))
	cube2:PivotTo(CFrame.new(cube2.WorldPivot.Position) * CFrame.Angles(0, math.rad(360 / cube2SpinTime) * currentTime, 0))
end)