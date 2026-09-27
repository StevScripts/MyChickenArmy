-- Studio Edit authoring only. Builds inert snapshots of the actual menu constructors.
-- Does not write mapped Source, start Play, load profiles, or make purchases.
-- Before running, also confirm Studio Flow solo_playtest status is stopped and
-- discovery exposes only Edit. An Edit peer's IsRunning() alone is insufficient.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local starter=game:GetService("StarterGui")
local storage=game:GetService("ServerStorage")
local variants={
	{name="Desktop",width=1440,height=900},
	{name="PhoneLandscape",width=749,height=368},
	{name="PhonePortrait",width=389,height=762},
}
for _,page in {"Shop","Army"} do
	for _,variant in variants do
		assert(not starter:FindFirstChild("MCA_Tune_"..page.."_"..variant.name),"Existing edits found; do not overwrite previews")
	end
end
local modules=Instance.new("Folder")
modules.Name="MCA_TemporaryAuthoringModules"
modules.Parent=storage
for _,item in game.StarterPlayer.StarterPlayerScripts.PetRoll:GetChildren() do
	if item:IsA("ModuleScript") then item:Clone().Parent=modules end
end
local Theme=require(modules.UITheme)
local Shop=require(modules.ShopBrowser)
local Army=require(modules.ChickenBrowser)
local Catalog=require(game.ReplicatedStorage.PetRoll.Shared.PetCatalog)
Theme.Motion:SetReduced(true)
local baseline=Instance.new("Folder")
baseline.Name="MCA_ManualUILayoutBaseline_"..os.time()
baseline.Parent=storage
local viewport=workspace.CurrentCamera.ViewportSize
local created={}
local ok,err=xpcall(function()
	for _,page in {"Shop","Army"} do
		for _,variant in variants do
			local w,h=variant.width,variant.height
			local screen=Instance.new("ScreenGui")
			screen.Name="MCA_Tune_"..page.."_"..variant.name
			screen.Enabled=false
			screen.ResetOnSpawn=false
			screen.IgnoreGuiInset=true
			screen.ScreenInsets=Enum.ScreenInsets.None
			screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
			screen.DisplayOrder=50
			screen:SetAttribute("AuthoringOnly",true)
			screen:SetAttribute("DesignWidth",w)
			screen:SetAttribute("DesignHeight",h)
			screen:SetAttribute("Menu",page)
			screen:SetAttribute("Instructions","Edit in STOPPED Studio. Enable one preview. Canvas.Zoom is editor zoom only. Window controls menu bounds. Grid CellSize/CellPadding control cards. No purchases or live data.")
			local canvas=Instance.new("Frame")
			canvas.Name,canvas.Size="Canvas",UDim2.fromOffset(w,h)
			canvas.AnchorPoint,canvas.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
			canvas.BackgroundColor3,canvas.BackgroundTransparency,canvas.BorderSizePixel=Color3.fromRGB(12,18,24),0.3,0
			canvas.Parent=screen
			local zoom=Instance.new("UIScale")
			zoom.Name,zoom.Scale,zoom.Parent="Zoom",math.min(1,(viewport.X-24)/w,(viewport.Y-24)/h),canvas
			local pw,ph=math.min(if page=="Shop" then 1080 else 1120,w-24,w*0.94),math.min(740,h-24,h*0.92)
			local window=Instance.new("Frame")
			window.Name,window.Size="Window",UDim2.fromScale(pw/w,ph/h)
			window.AnchorPoint,window.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
			window.BackgroundTransparency,window.BorderSizePixel,window.ZIndex=1,0,2
			window.Parent=canvas
			local state={pets={},selectedIds={},capacity=6,collectionLimit=40,selectionMode="Manual",armyState="Home",incomeLevel=0,
				shop={policyReady=true,paidRandomAllowed=true,productReady=true,automatic={}}}
			for i,species in {"Duck","Noob","Mallard","Penguin","Cheesy","Bucket","Viking","Knight","Wizard","Dragon","Rainbow","StormDuck"} do
				local pet={id="PreviewChicken"..i,species=species,stars=1,level=1,levelCap=10,home=true,deployed=false,
					selected=i<=4,canSell=i>4,refund=0,income=Catalog[species].income}
				table.insert(state.pets,pet)
				if i<=4 then table.insert(state.selectedIds,pet.id) end
			end
			local app={state=state,gui={AbsoluteSize=Vector2.new(w,h)},panelWidth=pw,panelHeight=ph,
				panelTitle={Text="Your Chickens!"},reducedMotion=true,page=page,
				audio={Play=function() end},commerce={products={},togglePending={},State=function() return "unconfigured" end}}
			function app:Pet(id) for _,pet in self.state.pets do if pet.id==id then return pet end end end
			function app:ClosePanel() end
			function app:OpenPage() end
			function app:Request() return 0 end
			local view=(if page=="Shop" then Shop else Army).new(app,window)
			view.root.Visible=true
			if page=="Army" then view:OpenInventory() end
			view:Render(true)
			if page=="Shop" then
				view.previewStatus.Text="LAYOUT PREVIEW · prices / checkout are disconnected"
				for _,item in view.root:GetDescendants() do
					if item:IsA("TextButton") and item:GetAttribute("State") then item.Text="Preview price" end
				end
			end
			-- Clone drops all temporary constructor connections, so manual edits stay put.
			local editable=screen:Clone()
			editable.Parent=starter
			editable.Enabled=page=="Army" and variant.name=="Desktop"
			local copy=editable:Clone()
			copy.Enabled=false
			copy.Parent=baseline
			table.insert(created,editable:GetFullName())
			if page=="Shop" then view:Destroy() else view.root:Destroy() end
			screen:Destroy()
		end
	end
end,debug.traceback)
Theme.Motion:Reset()
modules:Destroy()
assert(ok,err)
return {created=created,baseline=baseline:GetFullName(),visible="MCA_Tune_Army_Desktop",note="Editable snapshots only; runtime layout unchanged"}
