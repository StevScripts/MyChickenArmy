local Http=game:GetService("HttpService")
local Guide=require(game.ReplicatedStorage.PetRoll.Shared.TutorialGuide)
local Commander=require(script.Parent.PetRoll.CommanderGuide)
local app
local original=Commander.Update
Commander.Update=function(self,...)
 app=self.app
 Commander.Update=original
 return original(self,...)
end
local control=Instance.new("BindableFunction")
control.Name="Control";control.Parent=script
local history,seenReceipts={},{}
local last
local function report()
 if not app or not app.state then return {ready=false} end
 local s=app.state;local g=Guide.Resolve(s)
 if g and g.id~=last then table.insert(history,{step=g.id,coins=s.coins,pets=#s.pets,carried=s.eggs.carriedCount});last=g.id end
 for _,r in (s.eggs or {}).deposits or {} do seenReceipts[r.id]=r end
 return {ready=true,step=g and g.id,title=g and g.title,coins=s.coins,pets=#s.pets,capacity=s.capacity,
 selectedCount=s.selectedCount,reserve=s.starterCashReserve,offer=s.offer,carried=s.eggs.carriedCount,
 carriedValue=s.eggs.carriedValue,history=history,tutorial=s.tutorial,saveStatus=s.saveStatus,
 upgrades=s.boardUpgrades,receipts=seenReceipts,armyState=s.armyState,outgoing=s.outgoing,lastResult=s.lastResult}
end
control.OnInvoke=function(action,args)
 if action=="Read" then return report() end
 assert(app,"App not ready")
 if action=="Request" then app:Request(args.action,args.payload);return "sent" end
 if action=="Buy" then app:Request("Buy",{stationIndex=1,offerId=app.state.offer.id});return "sent" end
 if action=="Expand" then
  local q=app.state.boardUpgrades.ArmySize
  app:Request("CashUpgrade",{upgradeKey="ArmySize",expectedLevel=q.level,expectedPrice=q.price});return "sent"
 end
 if action=="Close" then app:ClosePanel();app.research:Close();return "closed" end
 if action=="ResetHistory" then history={};seenReceipts={};last=nil;return "cleared" end
end
while script.Parent do script:SetAttribute("Report",Http:JSONEncode(report()));task.wait(.2) end

