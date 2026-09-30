-- Stable Command Bar entry point; reopens against the latest synced editor code.
return function()
	assert(not game:GetService("RunService"):IsRunning(),"Stop Play before editing saved menu layouts.")
	local renderer=script.Parent.MenuLayoutEditor:Clone()
	renderer.Name,renderer.Parent="ActiveRenderer",script.Parent
	local ok,result=pcall(function() return require(renderer).Open() end)
	renderer:Destroy()
	if not ok then error(result,0) end
	return result
end
