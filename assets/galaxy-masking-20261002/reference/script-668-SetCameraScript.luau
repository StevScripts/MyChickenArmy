-- This script sets ViewportFrame's CurrentCamera to workspace.CurrentCamera based on attribute

for _, child in script.Parent:GetChildren() do
	if child:IsA("ViewportFrame") then
		local useWorkspaceCamera = child:GetAttribute("UseWorkspaceCamera")
		if not useWorkspaceCamera or useWorkspaceCamera == false then continue end
		child.CurrentCamera = workspace.CurrentCamera
	end
end