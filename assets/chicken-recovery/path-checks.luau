-- Isolated Edit fault injection for asynchronous path ownership. No player data.
assert(not game:GetService("RunService"):IsRunning())
local api={mode="success",calls=0,paths={}}
function api:CreatePath()
 self.calls+=1
 if self.mode=="create-error" then error("Injected CreatePath failure") end
 local mode=self.mode
 local event=Instance.new("BindableEvent")
 local path={Status=Enum.PathStatus.Success,Blocked=event.Event,event=event}
 function path:ComputeAsync(origin,target)
  if mode=="hang" then task.wait(100) end
  if mode=="compute-error" then error("Injected ComputeAsync failure") end
  self.origin,self.target=origin,target
 end
 function path:GetWaypoints()return {{Position=self.origin},{Position=self.target}}end
 function path:Destroy()self.destroyed=true;event:Destroy()end
 table.insert(self.paths,path);return path
end
local cache={}
local function fresh(module)
 if cache[module] then return cache[module] end
 local fn,err=loadstring(module.Source,"="..module.Name);assert(fn,err)
 local env={script=module,require=function(m)if typeof(m)=="Instance" and m:IsA("ModuleScript")then return fresh(m)end;return require(m)end}
 if module.Name=="PetActor" then env.game=setmetatable({GetService=function(_,name)if name=="PathfindingService"then return api end;return game:GetService(name)end},{__index=game}) end
 setfenv(fn,setmetatable(env,{__index=getfenv()}));local result=fn();cache[module]=result;return result
end
local Actor=fresh(game.ServerStorage.PetRoll.PetActor)
local folder=Instance.new("Folder");folder.Name="RecoveryPathFixture";folder.Parent=workspace
local actors,results={},{}
local function actor()
 local a=Actor.new(folder,"PathFixture","Duck",1,Vector3.new(2000,3,2000));table.insert(actors,a)
 -- This fixture covers asynchronous control flow; live tests cover physics.
 a.RigIssue=function()return nil end;a._safeGround=function(_,v)return v end
 a._command=function(self,target)self.lastTestCommand=target end
 a:MoveTo(Vector3.new(2020,3,2000),8)
 return a
end
local function test(name,fn)local ok,why=xpcall(fn,debug.traceback);table.insert(results,{name=name,passed=ok,detail=if ok then nil else tostring(why)})end
test("CreatePath errors release both global slots",function()
 api.mode="create-error"
 for _=1,4 do local a=actor();local before=api.calls;a:_recover(os.clock());task.wait();assert(api.calls==before+1 and not a.requestPending);a:Destroy()end
end)
test("ComputeAsync errors release slots and destroy paths",function()
 api.mode="compute-error"
 for _=1,3 do local a=actor();a:_recover(os.clock());task.wait();assert(not a.requestPending and api.paths[#api.paths].destroyed);a:Destroy()end
end)
test("Two-request cap, timeout, and exact budget release",function()
 api.mode="hang";local a,b,c=actor(),actor(),actor();a:_recover(os.clock());b:_recover(os.clock());c:_recover(os.clock());task.wait()
 assert(a.requestPending and b.requestPending and not c.requestPending,"Global cap exceeded")
 local old=a.pathRequest;a.recoveries=2;old.startedAt=os.clock()-9;a:Step(os.clock())
 assert(old.done and old.path.destroyed and not a.requestPending and a.state=="blocked","Timeout did not cancel")
 api.mode="success";c:_recover(os.clock());task.wait();assert(c.path and not c.requestPending,"Timed-out slot leaked")
 a:Destroy();b:Destroy();c:Destroy()
end)
test("New route and Destroy cancel pending callbacks",function()
 api.mode="hang";local a=actor();a:_recover(os.clock());task.wait();local request=a.pathRequest
 a:MoveTo(Vector3.new(1980,3,2000),8)
 assert(request.done and request.path.destroyed and not a.requestPending)
 a:_recover(os.clock());task.wait();request=a.pathRequest;a:Destroy()
 assert(request.done and request.path.destroyed and a:Step(os.clock())=="destroyed")
 api.mode="success";local b=actor();b:_recover(os.clock());task.wait();assert(b.path);b:Destroy()
end)
test("Blocked event ignores passed segments and invalidates future segments",function()
 api.mode="success";local a=actor();a:_recover(os.clock());task.wait();local p=a.path;assert(p)
 a.waypointIndex=2;p.event:Fire(1);task.wait();assert(a.path==p)
 p.event:Fire(2);task.wait();assert(not a.path and p.destroyed and not a.waypoints)
 a:Destroy()
end)
test("Sideways jitter cannot reset the progress watchdog",function()
 api.mode="success";local a=actor();a.root.CFrame+=Vector3.new(0,0,1)
 a.progressAt=os.clock()-3;a:Step(os.clock());assert(a.requestPending,"Sideways motion was counted as progress")
 a:Destroy()
end)
for _,a in actors do a:Destroy()end;folder:Destroy()
local passed=0;for _,r in results do if r.passed then passed+=1 end end
return {passed=passed,total=#results,results=results}
