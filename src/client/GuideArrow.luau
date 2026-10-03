--!strict
-- Original chunky-simulator-icons artwork, shared by GUI and world guidance.
local Theme = require(script.Parent.UITheme)

return function(parent, name)
	local arrow = Instance.new("ImageLabel")
	arrow.Name, arrow.BackgroundTransparency = name, 1
	arrow.Image, arrow.ScaleType = "rbxassetid://99969806505252", Enum.ScaleType.Fit
	arrow.Active, arrow.Selectable, arrow.ZIndex = false, false, 2
	arrow.Parent = parent
	Theme.Aspect(arrow, 1)
	return arrow
end
