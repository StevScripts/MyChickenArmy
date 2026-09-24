-- Attach to the editable preview ScreenGui. Preview actions have no purchase effects.
local screen = script.Parent
local canvas = screen:WaitForChild("DesignCanvas")
local input = game:GetService("UserInputService")
local viewportConnection

local function attachCamera()
	if viewportConnection then viewportConnection:Disconnect() end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local function resize()
		canvas.UIScale.Scale = math.min(camera.ViewportSize.X / 1280, camera.ViewportSize.Y / 860, 1.2)
	end
	resize()
	viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
end

attachCamera()
local cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera)
local keyConnection = input.InputBegan:Connect(function(key, processed)
	if not processed and key.KeyCode == Enum.KeyCode.F8 then screen.Enabled = not screen.Enabled end
end)
canvas.ShopHeader.Close.Activated:Connect(function() screen.Enabled = false end)

for _, button in screen:GetDescendants() do
	if button:IsA("TextButton") and button.Name == "HitTarget" then
		button.Activated:Connect(function()
			screen:SetAttribute("PreviewActivationCount", (screen:GetAttribute("PreviewActivationCount") or 0) + 1)
		end)
	end
end

screen.Destroying:Once(function()
	if viewportConnection then viewportConnection:Disconnect() end
	cameraConnection:Disconnect()
	keyConnection:Disconnect()
end)
