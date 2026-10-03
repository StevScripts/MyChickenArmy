local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local rng = Random.new()
local plr = game.Players.LocalPlayer
local mouse = plr:GetMouse()
local viewport: ViewportFrame = script.Parent
local texture: SurfaceAppearance = viewport.MaskPlane.SurfaceAppearance
local image: EditableImage = Instance.new("EditableImage")
image.Parent = texture

local maskSize = 256
local circleSize = 10 -- Circle starting size
local circleSizeIncrement = 5 -- Amount each button press changes circle size
local circleMinSize, circleMaxSize = 1, maskSize
local mouseDown = false
local mouseInFrame = false
local drawMode: "Erase" | "Draw" = "Erase"

image.Size = Vector2.new(maskSize, maskSize)
local emptyTable = table.create(maskSize^2 * 4, 0)
image:WritePixels(Vector2.zero, image.Size, emptyTable)

-- Converts red pixles to black transparent pixels ie erases mask and draws the image below
local function DrawOnRedPixels(x, y)
	local position = Vector2.new(x - circleSize - 1, y - circleSize - 1)
	local size = Vector2.new(x + circleSize * 2 + 2, y + circleSize * 2 + 2)
	
	local pixels = image:ReadPixels(Vector2.zero, image.Size)
	for i = 1, image.Size.X * image.Size.Y do
		local pixelIndex = 1 + ((i - 1) * 4)
		
		if pixels[pixelIndex] > 0 then
			pixels[pixelIndex] = 0
			pixels[pixelIndex + 1] = 0
			pixels[pixelIndex + 2] = 0
			pixels[pixelIndex + 3] = 0
		end
	end
	image:WritePixels(Vector2.zero, image.Size, pixels)
end

RunService.RenderStepped:Connect(function()
	if not mouseDown or not mouseInFrame then return end
	
	local x = math.clamp(((mouse.X - viewport.AbsolutePosition.X) / viewport.AbsoluteSize.X) * image.Size.X, 0, image.Size.X)
	local y = math.clamp(((mouse.Y - viewport.AbsolutePosition.Y) / viewport.AbsoluteSize.Y) * image.Size.Y, 0, image.Size.Y)
	
	if drawMode == "Draw" then
		image:DrawCircle(Vector2.new(x, y), circleSize, Color3.new(1,0,0), 0)
		DrawOnRedPixels(x, y)
	else
		image:DrawCircle(Vector2.new(x, y), circleSize, Color3.new(0,0,0), 0)
	end
	
	-- Trigger viewport refresh
	viewport.Refresh.Position = rng:NextUnitVector()
end)

viewport.MouseEnter:Connect(function() mouseInFrame = true end)
viewport.MouseLeave:Connect(function() mouseInFrame = false end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseDown = true
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftControl then
		drawMode = "Draw"
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseDown = false
		return
	end
	
	if input.KeyCode == Enum.KeyCode.LeftControl then
		drawMode = "Erase"
		return
	end
	
	if input.KeyCode == Enum.KeyCode.T then
		circleSize = math.min(circleSize + circleSizeIncrement, circleMaxSize)
		return
	end
	
	if input.KeyCode == Enum.KeyCode.R then
		circleSize = math.max(circleSize - circleSizeIncrement, circleMinSize)
		return
	end
end)