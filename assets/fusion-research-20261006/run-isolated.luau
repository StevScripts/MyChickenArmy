assert(game.PlaceId==96683186622050)
local Http=game:GetService("HttpService")
local pack=Http:JSONDecode(Http:GetAsync("http://127.0.0.1:18877/source-pack.json",true))
local cache,loading={},{}
local base=getfenv()
local readModule
local function evaluate(source,name,module)
 local chunk,err=loadstring(source,"@"..name);assert(chunk,err)
 local environment=setmetatable({script=module,require=function(dependency) return readModule(dependency) end},{__index=base})
 setfenv(chunk,environment)
 return chunk()
end
readModule=function(module)
 assert(typeof(module)=="Instance" and module:IsA("ModuleScript"),"Unexpected external module")
 if cache[module]~=nil then return cache[module] end
 local path=module:GetFullName()
 assert(not loading[module],"Circular require: "..path)
 local source=assert(pack.sources[path],"Missing local source: "..path)
 loading[module]=true
 local result=evaluate(source,path,module)
 loading[module]=nil;cache[module]=result
 return result
end
local ok,result=xpcall(function() return evaluate(pack.fixture,"fusion-research-checks",nil) end,debug.traceback)
local modules=0;for _ in cache do modules+=1 end
return {ok=ok,result=result,isolatedModules=modules,scope="Latest local sources, separate require cache, disposable profiles; no mapped Source or live session writes"}
