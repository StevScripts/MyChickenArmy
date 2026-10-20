--!strict
-- Local staging only. Eligibility and consumption always come from the server.
local Selection={}
Selection.__index=Selection

function Selection.new()
 return setmetatable({slots={},key=nil},Selection)
end

function Selection:Count()
 local count=0
 for i=1,3 do if self.slots[i] then count+=1 end end
 return count
end

function Selection:Clear()
 table.clear(self.slots);self.key=nil
end

function Selection:Recipe(options)
 for _,recipe in options or {} do
  if recipe.key==self.key and recipe.count>=3 then return recipe end
 end
 return nil
end

function Selection:Contains(id)
 for i=1,3 do if self.slots[i]==id then return true end end
 return false
end

function Selection:Available(recipe)
 if self.key and self.key~=recipe.key then return {} end
 if (recipe.count or 0)<3 then return {} end
 local available={}
 for _,id in recipe.petIds or {} do
  if not self:Contains(id) then table.insert(available,id) end
 end
 return available
end

function Selection:Reconcile(options)
 if not self.key then return false end
 local recipe=self:Recipe(options)
 if not recipe then self:Clear();return true end
 local changed=false
 for i=1,3 do
  local id=self.slots[i]
  if id and not table.find(recipe.petIds,id) then self.slots[i]=nil;changed=true end
 end
 if self:Count()==0 then self.key=nil end
 return changed
end

function Selection:Add(options,key,slot)
 if slot<1 or slot>3 or slot%1~=0 or self.slots[slot] then return false end
 for _,recipe in options or {} do
  if recipe.key==key then
   local id=self:Available(recipe)[1]
   if not id then return false end
   self.key,self.slots[slot]=key,id
   return true
  end
 end
 return false
end

function Selection:Remove(slot)
 self.slots[slot]=nil
 if self:Count()==0 then self.key=nil end
end

function Selection:Payload(options,stationIndex)
 if self:Reconcile(options) or self:Count()~=3 then return nil end
 local recipe=self:Recipe(options)
 if not recipe then return nil end
 -- The server orders eligible IDs to retain an equipped chicken first. Respect
 -- that order even when the player fills the visual slots from right to left.
 local ids={}
 for _,id in recipe.petIds do if self:Contains(id) then table.insert(ids,id) end end
 if #ids~=3 then return nil end
 return {firstId=ids[1],secondId=ids[2],thirdId=ids[3],level=recipe.level,stationIndex=stationIndex,expectedPrice=recipe.price}
end

-- Called only after an acknowledged Sync, never from an uncorrelated snapshot.
function Selection.Result(pets,payload,species)
 local byId={}
 for _,pet in pets or {} do byId[pet.id]=pet end
 local survivor=byId[payload.firstId]
 if survivor and survivor.species==species and survivor.level==payload.level+1
  and not byId[payload.secondId] and not byId[payload.thirdId] then return survivor end
 return nil
end

return Selection
