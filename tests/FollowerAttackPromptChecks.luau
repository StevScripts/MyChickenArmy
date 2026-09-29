-- Client-only disposable command targets and snapshots; sends no requests.
local Base=require(game.Players.LocalPlayer.PlayerScripts.PetRoll.BaseController)
local Checks={}
function Checks.Run()
 local app={state={armyState='Following',plotIndex=1,selectedCount=3,deployedCount=0,power=100}}
 function app:Counts() return 3,25,3,self.state.selectedCount,self.state.deployedCount end
 local controller=Base.new(app)
 local model=Instance.new('Model')
 local results={}
 local function target(id,available)
  model:SetAttribute('CommandTarget',id);model:SetAttribute('LaneOwnerIndex',1)
  app.state.targets={{id=id,name='Fixture camp',available=available,reason='Territory busy',power=20,count=1,killRewardMin=5,killRewardMax=5}}
 end
 local function check(name,fn)
  local ok,why=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
 end
 check('Following can attack every eligible destination using selected count without deployed count',function()
  app.state.armyState='Following';app.state.selectedCount=3;app.state.deployedCount=0
  for _,id in {'camp:1','outpost:1','king:1','income:1'} do
   target(id,true);app.state.incomeOutpost={available=true,action='Conquer'}
   local command=controller:CommandFor(model)
   assert(command and command.action=='Attack' and command.targetId==id,id)
  end
 end)
 check('Following respects empty selection, blocked targets, foreign lanes and protected bases',function()
  target('camp:1',true);app.state.selectedCount=0;app.state.deployedCount=3
  assert(controller:CommandFor(model).action==nil)
  app.state.selectedCount=3;target('camp:1',false)
  assert(controller:CommandFor(model).action==nil)
  target('camp:1',true);model:SetAttribute('LaneOwnerIndex',2)
  assert(controller:CommandFor(model)==nil)
  target('base:123',true);assert(controller:CommandFor(model)==nil)
 end)
 check('Returning, Recovering and Defending still cannot issue an attack',function()
  target('camp:1',true)
  for _,state in {'Returning','Recovering','Defending'} do
   app.state.armyState=state;assert(controller:CommandFor(model)==nil,state)
  end
 end)
 check('Existing Home and deployed attack/redirect counts remain unchanged',function()
  target('camp:1',true);app.state.armyState='Home';app.state.selectedCount=3;app.state.deployedCount=0
  assert(controller:CommandFor(model).action=='Attack')
  app.state.selectedCount=0;app.state.deployedCount=2
  for _,state in {'Traveling','Fighting','Deployed'} do
   app.state.armyState=state;assert(controller:CommandFor(model).action=='Attack',state)
  end
 end)
 model:Destroy()
 return results
end
return Checks
