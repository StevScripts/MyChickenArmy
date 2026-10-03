-- Show TextLabel which tells that EditableImages aren't yet supported in game if game isn't being played in studio
if game:GetService("RunService"):IsStudio() then
	script.Parent.TextLabel.Visible = true
else
	script.Parent.NotSupported.Visible = true
end