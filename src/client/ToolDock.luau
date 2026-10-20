--!strict
-- October 20 tool dock (docs/team/COLLECTION_TOOLS.md), after the Drop a Fruit hotbar:
-- one square slot per owned tool with its key number, the equipped one outlined in
-- white, and the Egg Vacuum's "carried / capacity" meter above the dock while it is
-- in hand. One layout for every device, sitting just above My Army. ToolController
-- owns equipping; this only draws and reports slot presses.
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Tools=require(Shared.VacuumConfig)
local Theme=require(script.Parent.UITheme)
local Dock={}
Dock.__index=Dock

local SLOT=Color3.fromRGB(24,26,30)
local GOLD=Theme.Arcade.gold
local RED=Theme.Arcade.red
local WHITE=Color3.new(1,1,1)
local DIM=Color3.fromRGB(60,64,72)

local function text(parent,name,value,color)
 local label=Theme.Label(parent,name,value,24,color or WHITE)
 label.TextScaled,label.TextWrapped,label.TextXAlignment=true,false,Enum.TextXAlignment.Center
 return label
end

function Dock.new(app,onSelect)
 local self=setmetatable({app=app,slots={},onSelect=onSelect},Dock)
 local root=Theme.Container(app.hudLayer,"ToolDock")
 root.AnchorPoint,root.Position,root.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.735),UDim2.fromScale(0.15,0.085)
 root.Visible=false
 Theme.Aspect(root,2.2)
 self.root=root
 local row=Theme.Container(root,"Slots")
 local layout=Instance.new("UIListLayout")
 layout.FillDirection,layout.SortOrder=Enum.FillDirection.Horizontal,Enum.SortOrder.LayoutOrder
 layout.HorizontalAlignment,layout.VerticalAlignment=Enum.HorizontalAlignment.Center,Enum.VerticalAlignment.Center
 layout.Padding,layout.Parent=UDim.new(0.06,0),row
 for index,name in Tools.ToolOrder do self:Slot(row,index,name) end
 -- The vacuum meter: "120 / 300", and a sell hint once it is full.
 local meter=Theme.Frame(root,"VacuumMeter",UDim2.fromScale(1.15,0.62),Color3.new(0,0,0))
 meter.AnchorPoint,meter.Position,meter.BackgroundTransparency=Vector2.new(0.5,1),UDim2.fromScale(0.5,-0.12),0.35
 meter.Visible=false
 Theme.Stroke(meter,Color3.new(0,0,0),2)
 self.count=text(meter,"Count","0 / 0",GOLD)
 self.count.Position,self.count.Size=UDim2.fromScale(0.05,0.06),UDim2.fromScale(0.9,0.6)
 self.hint=text(meter,"Hint","Full! Sell on the pad",WHITE)
 self.hint.Position,self.hint.Size=UDim2.fromScale(0.05,0.64),UDim2.fromScale(0.9,0.3)
 self.meter=meter
 -- Gamepad players collect with R2; the button's own glyph, shown only on a gamepad.
 local pad=Theme.Container(root,"GamepadHint")
 pad.AnchorPoint,pad.Position,pad.Size=Vector2.new(0,0.5),UDim2.fromScale(1.04,0.5),UDim2.fromScale(0.62,0.42)
 local glyph=Theme.Image(pad,"Button",UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonR2),UDim2.fromScale(0.34,1))
 Theme.Aspect(glyph,1)
 local collect=text(pad,"Text","Collect",WHITE)
 collect.Position,collect.Size,collect.TextXAlignment=UDim2.fromScale(0.38,0),UDim2.fromScale(0.62,1),Enum.TextXAlignment.Left
 self.gamepad=pad
 return self
end

function Dock:Slot(row,index,name)
 local button=Instance.new("TextButton")
 button.Name,button.Text,button.LayoutOrder=name,"",index
 button.Size,button.AutoButtonColor,button.BorderSizePixel=UDim2.fromScale(0.45,1),false,0
 button.BackgroundColor3,button.BackgroundTransparency=SLOT,0.25
 Theme.Aspect(button,1)
 local outline=Theme.Stroke(button,DIM,2)
 local icon=Theme.Image(button,"Icon",Tools.ToolIcons[name] or "",UDim2.fromScale(0.78,0.78),UDim2.fromScale(0.5,0.52))
 icon.AnchorPoint=Vector2.new(0.5,0.5)
 -- Until an icon loads (or without one) the tool's name reads in the slot.
 local label=text(button,"Name",Tools.ToolNames[name] or name,WHITE)
 label.AnchorPoint,label.Position,label.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.96),UDim2.fromScale(0.92,0.26)
 label.Visible=icon.Image==""
 local number=text(button,"Key",tostring(index),WHITE)
 number.Position,number.Size,number.TextXAlignment=UDim2.fromScale(0.06,0.03),UDim2.fromScale(0.3,0.3),Enum.TextXAlignment.Left
 button.Parent=row
 -- A UIScale press keeps the list layout still.
 Theme.Motion:BindButton(button,Theme.Motion:ScaleOf(button))
 button.Activated:Connect(function() self.onSelect(name) end)
 self.slots[name]={button=button,outline=outline}
end

-- owned: tool name -> true; equipped: the tool in hand; vacuum: state.tools.vacuum.
function Dock:Render(owned,equipped: string?,vacuum)
 local any=false
 for name,slot in self.slots do
  local has=owned[name]==true
  any=any or has
  slot.button.Visible=has
  local selected=has and equipped==name
  slot.outline.Color=if selected then WHITE else DIM
  slot.outline.Thickness=if selected then 3 else 2
 end
 local panel=self.app.panel
 self.root.Visible=any and not (panel and panel.Visible)
 local showMeter=equipped=="EggVacuum" and type(vacuum)=="table"
 self.meter.Visible=showMeter
 if showMeter then
  local count,capacity=math.floor(vacuum.count or 0),math.max(1,math.floor(vacuum.capacity or 0))
  local full=count>=capacity
  local value=Theme.Money(count).." / "..Theme.Money(capacity)
  if self.count.Text~=value then
   self.count.Text=value
   if not self.app.reducedMotion then Theme.Motion:Pulse(self.count,1.06) end
  end
  self.count.TextColor3=if full then RED else GOLD
  self.hint.Visible=full
 end
 self.gamepad.Visible=any and UserInputService.PreferredInput==Enum.PreferredInput.Gamepad
end

function Dock:Destroy()
 self.root:Destroy()
end

return Dock
