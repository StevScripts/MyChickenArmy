--!strict
-- Server-issued eligibility fixtures; no profile or currency writes.
local Selection=require(game.StarterPlayer.StarterPlayerScripts.PetRoll.MergeSelection)
local Checks={}
function Checks.Run()
 local results={}
 local function check(name,fn)
  local ok,why=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
 end
 local function recipe(ids,key)
  return {key=key or "Camo:1:1",species="Camo",stars=1,level=1,count=#ids,petIds=ids,price=2400}
 end
 check("Three-copy group stays available as 2 then 1; exact staged IDs",function()
  local s=Selection.new();local r=recipe({"a","b","c"});local options={r}
  assert(s:Add(options,r.key,1) and #s:Available(r)==2)
  assert(s:Add(options,r.key,2) and #s:Available(r)==1)
  assert(s:Add(options,r.key,3) and #s:Available(r)==0)
  local p=s:Payload(options,2)
  assert(p.firstId=="a" and p.secondId=="b" and p.thirdId=="c" and p.stationIndex==2 and p.expectedPrice==2400)
 end)
 check("Sparse slot order cannot stage a duplicate; survivor keeps server priority",function()
  local s=Selection.new();local r=recipe({"equipped","b","c","d"})
  assert(s:Add({r},r.key,3) and s:Add({r},r.key,1) and s:Add({r},r.key,2))
  local p=s:Payload({r},1);assert(p.firstId=="equipped")
  assert(s.slots[3]=="equipped" and s.slots[1]=="b" and s.slots[2]=="c")
  s:Remove(1);assert(s:Count()==2 and #s:Available(r)==2 and not s:Payload({r},1))
  assert(s:Add({r},r.key,1) and s:Payload({r},1))
 end)
 check("Species/level group locks until all inputs removed",function()
  local s=Selection.new();local a=recipe({"a","b","c"});local b=recipe({"d","e","f"},"Camo:1:2")
  assert(s:Add({a,b},a.key,2));assert(not s:Add({a,b},b.key,1))
  s:Remove(2);assert(s:Add({a,b},b.key,1))
 end)
 check("Stale ID removed without replacing remaining choices; replacement allowed",function()
  local s=Selection.new();local r=recipe({"a","b","c","d"})
  for i=1,3 do assert(s:Add({r},r.key,i)) end
  local fresh=recipe({"a","c","d"})
  assert(s:Reconcile({fresh}) and s.slots[1]=="a" and s.slots[2]==nil and s.slots[3]=="c")
  assert(s:Add({fresh},fresh.key,2));local p=s:Payload({fresh},1)
  assert(p.firstId=="a" and p.secondId=="c" and p.thirdId=="d")
 end)
 check("Unavailable trio clears; incomplete and occupied slots cannot submit",function()
  local s=Selection.new();local r=recipe({"a","b","c"})
  assert(s:Add({r},r.key,1));assert(not s:Add({r},r.key,1) and not s:Payload({r},1))
  assert(s:Reconcile({}) and s:Count()==0 and s.key==nil)
  assert(not s:Add({recipe({"a","b"})},r.key,1))
 end)
 check("Recovery accepts only the actual leveled survivor with both inputs gone",function()
  local p={firstId="a",secondId="b",thirdId="c",level=1}
  local chicken={id="a",species="Camo",level=2}
  assert(Selection.Result({chicken},p,"Camo")==chicken)
  assert(not Selection.Result({chicken,{id="c"}},p,"Camo"))
  assert(not Selection.Result({{id="a",species="Camo",level=1}},p,"Camo"))
  assert(not Selection.Result({{id="a",species="Slime",level=2}},p,"Camo"))
 end)
 return results
end
return Checks
