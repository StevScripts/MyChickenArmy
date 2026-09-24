--!strict
-- The builder's art stays in a native template. This module only binds its named roles.
local ServerStorage=game:GetService("ServerStorage")
local MapLayout=require(game:GetService("ReplicatedStorage").PetRoll.Shared.MapLayout)
local AuthoredPlot={}

function AuthoredPlot.Build(root,index,frame)
 local assets=ServerStorage:FindFirstChild("PetRollPlotAssets")
 local template=assets and assets:FindFirstChild("AuthoredHomePlot")
 assert(template,"AuthoredHomePlot template is missing")
 local plot=template:Clone()
 plot.Name="Plot"..index;plot:PivotTo(frame)
 plot:SetAttribute("PlotIndex",index);plot:SetAttribute("AuthoredPlot",true)
 plot:SetAttribute("EggDepositEnabled",true)
 -- The generated WalkRamp owns entry collision; the original thick steps are scenery.
 for _,part in plot.Props:GetChildren() do
  if part:IsA("BasePart") and part.Name=="Path" and part.Size.Y>1
   and frame:PointToObjectSpace(part.Position).Z< -MapLayout.HomeDeckHalfDepth+1 then
   part.CanCollide=false;part.CanQuery=false
  end
 end
 -- Remove the sample bird; the real rolling preview occupies the same pedestal.
 local sample=plot.Props:FindFirstChild("Chicken")
 if sample then sample:Destroy() end
 local title=plot.Props["Your Plot"]:FindFirstChildWhichIsA("TextLabel",true)
 assert(title,"Authored home title is missing")
 title.Text="HOME "..index.." · OPEN"
 -- A purchase display is reserved for later; never advertise its placeholder price.
 for _,d in plot.Props.Gamepass:GetDescendants() do
  if d:IsA("BillboardGui") then d.Enabled=false end
 end
 plot.Parent=root
 return plot,title
end

return AuthoredPlot
