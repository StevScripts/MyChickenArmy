-- Disposable server-VM playtest. The client walks with Humanoid:MoveTo.
local g=assert(_G.MapQA)
local p=game.Players:GetPlayers()[1]
local s=g.sessions[p.UserId]
assert(s.saveStatus=='studio-session' and not next(g.data.entries))
local results=assert(_G.MapResults)
local requestId=23000
local function record(name,details)
 details.case=name;table.insert(results.events,details)
end
local function request(action,args)
 requestId+=1;args=args or {};args.action=action;args.id=requestId
 g:Handle(p,args)
end
local function walk(target,name,seconds)
 p:SetAttribute('MapQATarget',target)
 local started=os.clock()
 while os.clock()-started<(seconds or 12) do
  local at=p.Character.HumanoidRootPart.Position
  if ((at-target)*Vector3.new(1,0,1)).Magnitude<1.5 then
   record(name,{ok=true,seconds=os.clock()-started,position=tostring(at)})
   return true
  end
  task.wait(0.15)
 end
 local failure={case=name,target=tostring(target),position=tostring(p.Character.HumanoidRootPart.Position)}
 table.insert(results.failures,failure)
 return false
end
_G.MapWalk=walk
_G.MapRequest=request
_G.MapRecord=record
_G.MapPhase='collecting'
task.spawn(function()
 local ok,err=pcall(function()
  local frame=g.world:PlotFrame(1)
  local l=require(game.ReplicatedStorage.PetRoll.Shared.HomePlotLayout).ForPlot(1)
  local cx,cz=(l.YardMinX+l.YardMaxX)/2,(l.YardMinZ+l.YardMaxZ)/2
  for i,xz in {{-.65,-.65},{.65,-.65},{.65,.65},{-.65,.65},{0,0}} do
   local target=frame:PointToWorldSpace(Vector3.new(cx+xz[1]*(l.YardMaxX-l.YardMinX)/2,3,cz+xz[2]*(l.YardMaxZ-l.YardMinZ)/2))
   walk(target,'yard walk '..i)
  end
  task.wait(1)
  record('manual pickup',{count=s.eggCarry.count,value=s.eggCarry.value})
  local pad=g.world:EggDeposit(1)
  walk(pad.Position,'walk to moved sell pad')
  task.wait(1)
  record('instant selling',{bag=s.eggCarry.count,ready=s.eggProcessor.readyValue})
  local board=g.eggs:Board(s)
  local cash=board and board:FindFirstChild('TouchPart',true) or pad
  local before=s.coins
  walk(cash.Position-cash.CFrame.RightVector*2,'cash pad approach')
  walk(cash.Position+cash.CFrame.RightVector*2,'cash pad cross')
  task.wait(.5)
  record('cash payout',{before=before,after=s.coins,ready=s.eggProcessor.readyValue})
 end)
 _G.MapPhase=if ok then 'collection complete' else 'error'
 if not ok then table.insert(results.failures,{case='driver',error=tostring(err)}) end
 p:SetAttribute('MapQATarget',nil)
end)
return 'Physical collection/selling check started'
