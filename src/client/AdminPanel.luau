--!strict
-- Admin page (Settings > Admin, or F2). Shown only when the server says this
-- player is an admin; every command is still checked on the server.
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Commands=require(Shared.AdminCommands)
local Theme=require(script.Parent.UITheme)
local C=Theme.Colors

local Panel={}
Panel.__index=Panel

local LOG_LIMIT=12
-- One-tap shortcuts; each is a normal admin command.
local QUICK={
	{"Give me 1M Coins","cash me 1m"},
	{"Finish all my research","research me all"},
	{"Beat all camps and the King","king me"},
	{"Next roll ready","roll me"},
	{"Open a Hill round","hill open"},
	{"Close the Hill round","hill close"},
	{"Who's here","players"},
	{"Recent admin actions","logs"},
}

function Panel.new(app)
	return setmetatable({app=app,log={},draft=""},Panel)
end

function Panel:Run(text)
	text=text:match("^%s*(.-)%s*$") or ""
	text=(string.gsub(text,"^/a%a*%s*","")) :: string
	if text=="" then return end
	self:Append("> "..text,C.muted)
	self.app:Request("Admin",{text=text})
end

function Panel:Append(text,color)
	for line in string.gmatch(text,"[^\n]+") do
		table.insert(self.log,{text=line,color=color})
	end
	while #self.log>LOG_LIMIT do table.remove(self.log,1) end
end

-- Returns true when the reply belongs on this page instead of a toast.
function Panel:Receive(result): boolean
	if not result or result.action~="Admin" then return false end
	self:Append(result.message or "",if result.ok then Theme.Arcade.green else C.red)
	local app=self.app
	local shown=app.panel.Visible and app.page=="Admin"
	if shown then app:RenderPanel(true) end
	-- Chat replies: long lists show their first line; the panel keeps the rest.
	if not shown and result.message and result.message:find("\n") then
		app:Notify((result.message:match("^[^\n]+") or "").." (full list: F2)",result.ok)
		return true
	end
	return shown
end

function Panel:Render()
	local app=self.app
	local state=app.state
	app.panelTitle.Text="Admin"
	local rank=state.admin and state.admin.rank
	if not rank then app:Text("Denied","Admin commands are for admins only.",18,60);return end
	app:Text("Help",rank.." · type a command, or in chat use /a <command>. Targets: me, all, others or a name.",15,46,C.muted)
	local row=app:Text("CommandRow","",20,45)
	local box=Instance.new("TextBox")
	box.Name,box.Text,box.PlaceholderText,box.ClearTextOnFocus="Command",self.draft,"cash me 1m",false
	box.Font,box.TextScaled,box.TextColor3,box.PlaceholderColor3=Theme.Font,true,C.ink,C.muted
	box.TextXAlignment=Enum.TextXAlignment.Left
	box.BackgroundColor3,box.BorderSizePixel=C.card,0
	box.Position,box.Size=UDim2.fromScale(.015,.02),UDim2.fromScale(.97,.94)
	box.Parent=row;Theme.Stroke(box,C.line,1)
	local padding=Instance.new("UIPadding");padding.PaddingLeft=UDim.new(0.02,0);padding.Parent=box
	box:GetPropertyChangedSignal("Text"):Connect(function() self.draft=string.sub(box.Text,1,300) end)
	box.FocusLost:Connect(function(enter)
		if enter then local text=box.Text;self.draft="";self:Run(text) end
	end)
	app:Button("RunCommand","Run command",function() local text=box.Text;self.draft="";self:Run(text) end,Theme.ActionColors.purchase)
	if #self.log>0 then
		app:Text("OutputHeading","OUTPUT",13,24,Theme.Arcade.green)
		for index,entry in self.log do app:Text("Output"..index,entry.text,14,26,entry.color) end
	end
	app:Text("QuickHeading","QUICK ACTIONS",13,24,Theme.Arcade.green)
	for index,item in QUICK do
		app:Button("Quick"..index,item[1],function() self:Run(item[2]) end,Theme.ActionColors.navigation)
	end
	local group
	for _,command in Commands.List do
		if not Commands.Allowed(rank,command) then continue end
		if command.group~=group then
			group=command.group
			app:Text("Group"..group,string.upper(group),13,24,Theme.Arcade.green)
		end
		app:Text("Usage"..command.name,command.usage.."  ·  "..command.help,14,30,C.ink)
	end
end

return Panel
