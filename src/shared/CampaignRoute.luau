--!strict
-- Only main-path blockers are prerequisites. Side territories are independent.
-- Every lane runs Camp 1 → 2 → 3. A camp counts as cleared once the commander
-- has beaten it on that lane (saved), holds it now, or took it on this push.
local Progression=require(script.Parent.Progression)
local Config=require(script.Parent.Config)
local Route={}

-- "camp:N" is the commander's own lane; "camp:P:N" is camp N on plot P's lane.
-- Returns the camp index and the named plot (nil for the own-lane form).
function Route.Camp(target)
 if type(target)~="string" then return nil,nil end
 local plot,index=target:match("^camp:(%d+):(%d+)$")
 if plot then return tonumber(index),tonumber(plot) end
 return tonumber(target:match("^camp:(%d+)$")),nil
end

function Route.CampId(index,plot,ownPlot)
 return if plot==nil or plot==ownPlot then "camp:"..index else "camp:"..plot..":"..index
end

-- options.lanes[plot] holds another lane's cleared camps; a lane without an
-- entry has no commander and cannot be attacked. options.kingOpen sends the
-- army straight to the King once any lane has been fully beaten.
function Route.Plan(target,clearedCamps,clearedOutposts,options)
 if type(target)~="string" then return nil end
 if target=="income:1" then return if Config.IncomeOutpost and Config.IncomeOutpost.Enabled then {target} else nil end
 local campIndex,lane=Route.Camp(target)
 if campIndex then
  if not Progression.Camps(1)[campIndex] then return nil end
  local cleared=if lane then options and options.lanes and options.lanes[lane] else clearedCamps
  if not cleared then return nil end
  local result={}
  for i=1,campIndex-1 do if not cleared[i] then table.insert(result,Route.CampId(i,lane)) end end
  table.insert(result,target)
  return result
 end
 local kind,raw=target:match("^(%a+):([%-]?%d+)$")
 local index=tonumber(raw)
 if kind=="base" then return nil end -- Player homes are not attack destinations.
 if not index or (kind=="outpost" and not Progression.Outposts()[index])
  or (kind=="king" and index~=1) then return nil end
 if kind~="outpost" and kind~="king" then return nil end
 if kind=="outpost" then return {target} end
 if options and options.kingOpen then return {target} end
 local result={}
 for i=1,#Progression.Camps(1) do if not clearedCamps[i] then table.insert(result,"camp:"..i) end end
 table.insert(result,target)
 return result
end

function Route.Name(target)
 if target=="income:1" then return Config.IncomeOutpost.Name end
 local campIndex=Route.Camp(target)
 if campIndex then
  local entry=Progression.Camps(1)[campIndex]
  return if entry then entry.name else target
 end
 local kind,raw=target:match("^(%a+):(%d+)$");local index=tonumber(raw)
 if kind=="king" then return "Chicken King's Court" end
 local entry=if kind=="outpost" then Progression.Outposts()[index] else nil
 return if entry then entry.name else target
end
return Route
