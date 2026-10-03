--!strict
-- Native geometry keeps arrows independent of font glyph coverage.
local Theme = require(script.Parent.UITheme)

return function(parent, name)
	local arrow = Theme.Container(parent, name)
	Theme.Aspect(arrow, 1)
	local segments = {
		{.44, .5, .68, .15, 0},
		{.695, .355, .41, .15, 45},
		{.695, .645, .41, .15, -45},
	}
	-- Draw the whole outline behind the whole fill to avoid internal seams.
	for layer=1,2 do
		for i,segment in segments do
			local pad = if layer==1 then .07 else 0
			local part = Theme.Frame(arrow, "Segment"..layer..i,
				UDim2.fromScale(segment[3]+pad,segment[4]+pad),
				if layer==1 then Theme.Arcade.border else Theme.Arcade.gold)
			part.AnchorPoint,part.Position = Vector2.new(.5,.5),UDim2.fromScale(segment[1],segment[2])
			part.Rotation,part.ZIndex = segment[5],layer
			part.Active,part.Selectable = false,false
		end
	end
	return arrow
end
