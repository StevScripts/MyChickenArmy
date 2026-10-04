local p=game.Players.LocalPlayer;local Theme=require(p.PlayerScripts.PetRoll.UITheme);local Focus=require(p.PlayerScripts.PetRoll.GuideFocus)
local gui=p.PlayerGui:WaitForChild('PetRollGui',15);assert(gui)
local host=Theme.Container(gui.Shell.OTHER,'StrokeFixture');host.ZIndex=80
local background=Instance.new('Frame');background.Size=UDim2.fromScale(1,1);background.BackgroundColor3=Color3.fromRGB(100,175,240);background.BorderSizePixel=0;background.Parent=host
local target=Instance.new('TextButton');target.Name='Target';target.Text='CLICK';target.Font=Enum.Font.SourceSansBold;target.TextScaled=true;target.Position=UDim2.fromScale(.45,.45);target.Size=UDim2.fromScale(.14,.12);target.BackgroundColor3=Color3.fromRGB(255,255,255);target.Parent=host
local focus=Focus.new(host);_G.StrokeFixture={host=host,target=target,focus=focus,clicks=0};target.Activated:Connect(function() _G.StrokeFixture.clicks+=1 end)
for i=1,3 do game:GetService('RunService').RenderStepped:Wait() end
focus:SetTarget(target,false)
game:GetService('ContentProvider'):PreloadAsync({focus.arrow})
return {viewport=tostring(workspace.CurrentCamera.ViewportSize),white=focus.arrow.Image}
