local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local p=Players.LocalPlayer
local modules=p.PlayerScripts:WaitForChild("PetRoll")
local Feedback=require(modules.ActionFeedback)
local probe={started=os.clock(),receipts={},seen={},states={},cashCalls=0,depositBursts=0,cashSounds=0,depositSounds=0,unloads=0}
local originalStep=Feedback.Step
Feedback.Step=function(self,now)
 Feedback.Step=originalStep;probe.app=self.app
 return originalStep(self,now)
end
local deadline=os.clock()+10
while not probe.app and os.clock()<deadline do task.wait(.1) end
Feedback.Step=originalStep
local app=assert(probe.app,"Could not attach live feedback probe")
probe.startCoins=app.state.coins
local function wrap(object,key,before)
 local original=object[key]
 object[key]=function(self,...) before(...);return original(self,...) end
end
wrap(app.feedback,"Cash",function() probe.cashCalls+=1 end)
wrap(app.feedback,"DepositBurst",function() probe.depositBursts+=1 end)
wrap(app.audio,"Play",function(name)
 if name=="CashTick" then probe.cashSounds+=1 elseif name=="EggDeposit" then probe.depositSounds+=1 end
end)
wrap(app.eggs.vacuum,"Deposit",function(receipt)
 probe.unloads+=1
 probe.lastUnload={value=receipt.value,count=receipt.count,id=receipt.id}
end)
script:SetAttribute("Status","watching")
local control=Instance.new("BindableFunction")
control.Name="Control"
control.OnInvoke=function(action)
 if action=="manual" then probe.manualStartCoins=app.state.coins;return true end
end
control.Parent=script
local lastReport=0
RunService.Heartbeat:Connect(function()
 local s=app.state;if not s then return end
 probe.coins=s.coins
 local eggs=s.eggs or {}
 local rover=eggs.rover
 if rover then
  if rover.state~=probe.lastState then
   table.insert(probe.states,{at=math.round((os.clock()-probe.started)*10)/10,state=rover.state})
   probe.lastState=rover.state
  end
  probe.rover={state=rover.state,cargoCount=rover.cargoCount,cargoValue=rover.cargoValue,unloadSerial=rover.unloadSerial,enabled=rover.enabled}
 end
 for _,receipt in eggs.deposits or {} do
  if not probe.seen[receipt.id] then
   probe.seen[receipt.id]=true
   table.insert(probe.receipts,{id=receipt.id,collector=receipt.collector,count=receipt.count,value=receipt.value,coins=s.coins,at=math.round((os.clock()-probe.started)*10)/10})
  end
 end
 if os.clock()-lastReport>=.5 then
  lastReport=os.clock()
  script:SetAttribute("Report",HttpService:JSONEncode({elapsed=math.round((os.clock()-probe.started)*10)/10,startCoins=probe.startCoins,coins=probe.coins,manualStartCoins=probe.manualStartCoins,receipts=probe.receipts,states=probe.states,rover=probe.rover,cashCalls=probe.cashCalls,depositBursts=probe.depositBursts,cashSounds=probe.cashSounds,depositSounds=probe.depositSounds,unloads=probe.unloads,carriedCount=eggs.carriedCount,pets=#(s.pets or {}),reducedMotion=app.reducedMotion}))
 end
end)
app:Request("Debug",{command="Grant",argument="Duck"})

