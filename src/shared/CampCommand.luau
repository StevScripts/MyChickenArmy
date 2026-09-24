--!strict
-- Native prompt location and server reach validation use the same geometry.
local Config=require(script.Parent.Config)
local MapLayout=require(script.Parent.MapLayout)
local Command={}
function Command.Anchor(model)
 return model and (model:FindFirstChild("CommandCenter") or model:FindFirstChild("CaptureAnchor")
  or model:FindFirstChild("Ground") or model:FindFirstChild("WelcomeStripe"))
end
function Command.Radius(model)
 if model.Name=="KingArena" then return MapLayout.King.PromptRadius end
 if model:GetAttribute("PlotIndex") then return Config.CommandDistance end
 -- Reach every edge of the larger camp with a small approach margin.
 return math.ceil(Config.CampHalfSize*math.sqrt(2))+4
end
function Command.InRange(model,position,margin)
 local anchor=Command.Anchor(model)
 return anchor~=nil and (position-(anchor.Position+Vector3.new(0,2.5,0))).Magnitude<=Command.Radius(model)+(margin or 0)
end
return Command
