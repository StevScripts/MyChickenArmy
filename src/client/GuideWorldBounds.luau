--!strict
-- Screen-space bounds of the actual world item, in the overlay's coordinates.
-- WorldToScreenPoint and GuiObject.AbsolutePosition share the Core UI origin.
local CORNERS={
	Vector3.new(-1,-1,-1),Vector3.new(-1,-1,1),Vector3.new(-1,1,-1),Vector3.new(-1,1,1),
	Vector3.new(1,-1,-1),Vector3.new(1,-1,1),Vector3.new(1,1,-1),Vector3.new(1,1,1),
}

return function(target, parts, origin)
	local camera=workspace.CurrentCamera
	if not camera or not target:IsDescendantOf(workspace) then return nil end
	local x1,y1,x2,y2=math.huge,math.huge,-math.huge,-math.huge
	local function include(item)
		if not item or not item:IsDescendantOf(workspace) then return true end
		local frame,extent
		if item:IsA("BasePart") then frame,extent=item.CFrame,item.Size
		elseif item:IsA("Model") then
			if not item:FindFirstChildWhichIsA("BasePart",true) then return true end
			frame,extent=item:GetBoundingBox()
		elseif item:IsA("Attachment") then
			frame,extent=item.WorldCFrame,Vector3.new(2,2,2)
		elseif item:IsA("BillboardGui") then
			local anchor=item.Adornee or item.Parent
			if not item.Enabled or not anchor then return true end
			local position=if anchor:IsA("Attachment") then anchor.WorldPosition else anchor.Position
			if item.MaxDistance>0 and (position-camera.CFrame.Position).Magnitude>item.MaxDistance then return true end
			-- Egg sprites use stud-sized billboards with no pixel offsets.
			frame=CFrame.new(position+item.StudsOffsetWorldSpace)*camera:GetRenderCFrame().Rotation*CFrame.new(item.StudsOffset)
			extent=Vector3.new(item.Size.X.Scale,item.Size.Y.Scale,0)
		else return true end
		for _,corner in CORNERS do
			local projected=camera:WorldToScreenPoint(frame:PointToWorldSpace(extent*corner*.5))
			-- Near-plane crossings must never turn into an enormous/inverted cutout.
			if projected.Z<=math.abs(camera.NearPlaneZ)+.05 then return false end
			local x,y=projected.X-origin.X,projected.Y-origin.Y
			x1,y1,x2,y2=math.min(x1,x),math.min(y1,y),math.max(x2,x),math.max(y2,y)
		end
		return true
	end
	if parts then
		for _,part in parts do if not include(part) then return nil end end
	elseif not include(target) then return nil end
	if x1==math.huge then return nil end
	return x1,y1,x2,y2
end
