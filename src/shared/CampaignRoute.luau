--!strict
-- Only main-path blockers are prerequisites. Side territories are independent.
-- Clearance comes from current occupation or the army's current forward push.
local Progression=require(script.Parent.Progression)
local Config=require(script.Parent.Config)
local Route={}
function Route.Plan(target,clearedCamps,clearedOutposts)
 if type(target)~="string" then return nil end
 if target=="income:1" then return if Config.IncomeOutpost and Config.IncomeOutpost.Enabled then {target} else nil end
 local kind,raw=target:match("^(%a+):([%-]?%d+)$")
 local index=tonumber(raw)
 if kind=="base" then return nil end -- Player homes are not attack destinations.
 if not index or (kind=="camp" and not Progression.Camps(1)[index])
  or (kind=="outpost" and not Progression.Outposts()[index])
  or (kind=="king" and index~=1) then return nil end
 if kind~="camp" and kind~="outpost" and kind~="king" then return nil end
 if kind=="outpost" then return {target} end
 local result={}
 local homeLimit=if kind=="camp" then index-1 else #Progression.Camps(1)
 for i=1,homeLimit do if not clearedCamps[i] then table.insert(result,"camp:"..i) end end
 table.insert(result,target)
 return result
end
function Route.Name(target)
 if target=="income:1" then return Config.IncomeOutpost.Name end
 local kind,raw=target:match("^(%a+):(%d+)$");local index=tonumber(raw)
 if kind=="king" then return "Chicken King's Court" end
 local entry=if kind=="camp" then Progression.Camps(1)[index] elseif kind=="outpost" then Progression.Outposts()[index] else nil
 return if entry then entry.name else target
end
return Route
