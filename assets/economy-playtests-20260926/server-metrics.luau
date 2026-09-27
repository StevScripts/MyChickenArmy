local G=require(game.ServerStorage.PetRoll.GameServer)
local original=G.Step
_G.EconomyStepOriginal=original
_G.EconomyCpuSamples={}
G.Step=function(self,dt)
 local start=os.clock();original(self,dt)
 local elapsed=(os.clock()-start)*1000
 local p=game.Players:GetPlayers()[1]
 local label=p and p:GetAttribute('EconomyTestRun')
 if label then
  local r=_G.EconomyCpuSamples[label] or {cpu={},dt={}};_G.EconomyCpuSamples[label]=r
  if #r.cpu<30000 then table.insert(r.cpu,elapsed);table.insert(r.dt,dt*1000) end
 end
end
_G.EconomyCpuSummary=function()
 local out={}
 for name,raw in _G.EconomyCpuSamples do
  local c=table.clone(raw.cpu);local dt=table.clone(raw.dt);table.sort(c);table.sort(dt)
  local sum=0;for _,x in c do sum+=x end
  out[name]={n=#c,meanMs=sum/#c,p50Ms=c[math.ceil(#c*.5)],p95Ms=c[math.ceil(#c*.95)],maxMs=c[#c],heartbeatP50Ms=dt[math.ceil(#dt*.5)]}
 end
 return out
end
return 'Server CPU update and heartbeat timings enabled'
