for _, guiObject in script.Parent:GetDescendants() do
	if guiObject:IsA("TextButton") and guiObject.Name:match("OpenTab") then
		guiObject.MouseButton1Click:Connect(function()
			local isOpen = guiObject:GetAttribute("IsOpen")
			if isOpen then
				guiObject.Parent.Info.Visible = false
				guiObject.Arrow.UIGradient.Rotation = 0
			elseif not isOpen then
				guiObject.Parent.Info.Visible = true
				guiObject.Arrow.UIGradient.Rotation = 90
			end
			guiObject:SetAttribute("IsOpen", not isOpen)
		end)
	end
end