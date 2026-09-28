-- Disposable Roblox UI objects. Run in Edit; no actual app, profile or input controls.
local Client=game.StarterPlayer.StarterPlayerScripts.PetRoll
local Browser=require(Client.MergeBrowser)
local Preview=require(Client.ChickenPreview)
local gui=Instance.new('ScreenGui');gui.Name='FuseFlowChecks';gui.Enabled=false;gui.Parent=game.ServerStorage
local panel=Instance.new('Frame');panel.Size=UDim2.fromOffset(1000,870);panel.Parent=gui
local recipe={key='Camo:1:1',species='Camo',stars=1,level=1,count=3,petIds={'a','b','c'},inputEggRate=8,afterEggRate=16,beforeDps=10,afterDps=12.5}
local app={state={mergeOptions={recipe},pets={},plotIndex=1},panel=panel,panelWidth=1000,panelHeight=870,page='Merge',reducedMotion=true,
 audio={Play=function() end},requests={}}
function app:Preview(...) return Preview.Create(...) end
function app:Request(action,payload) table.insert(self.requests,{action=action,payload=payload});return #self.requests end
function app:ClosePanel() self.panel.Visible=false end
local b=Browser.new(app,panel);b.root.Visible=true
function b:NearStand() return true end
local results={}
local function fresh()
 b.pending=nil;b.animating=false;b:Reset();app.panel.Visible=true
 app.state={mergeOptions={recipe},pets={},plotIndex=1};b:Render(true)
end
local function stage()
 for _,i in {3,1,2} do b:Slot(i);b:Choose(recipe.key) end
end
local function check(name,fn)
 local ok,why=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
end
check('Picker search, remaining counts, sparse slots and Remove',function()
 fresh();b:Slot(3);assert(#b.cards==1 and b.cards[1].Count.Text=='×3')
 b:Choose(recipe.key);b:Slot(1);assert(b.cards[1].Count.Text=='×2')
 b.search.Text='unmatched';task.wait();assert(#b.cards==0 and b.empty.Visible and b.back.Text=='Clear search')
 b.search.Text='Camo';task.wait();assert(#b.cards==1)
 b:Choose(recipe.key);b:Slot(2);assert(b.cards[1].Count.Text=='×1');b:Choose(recipe.key)
 assert(b.action.Active and b.selection:Count()==3)
 b:Slot(1);assert(not b.action.Active and b.selection:Count()==2)
end)
check('Stale server eligibility clears slots and cannot submit',function()
 fresh();stage();app.state.mergeOptions={};b:Render(true)
 assert(b.selection:Count()==0 and not b.action.Active and b.notice)
 local before=#app.requests;b:Merge();assert(#app.requests==before)
end)
check('Success shows the actual chicken, level and egg/combat values; ignores repeat taps',function()
 fresh();stage();b:Merge();local p=b.pending;local n=#app.requests;b:Merge();assert(#app.requests==n)
 local survivor={id=p.payload.firstId,species='Camo',level=2,eggsPerSecond=16}
 app.state.pets={survivor};app.state.mergeOptions={}
 b:Receive({id=p.id,ok=true});assert(b.mode=='Result' and b.summaryName.Text=='Camo Chick')
 assert(b.summaryEggs.Text=='8 → 16 eggs/s' and b.summaryDps.Text=='10 → 12.5 DPS')
 b:Receive({id=p.id,ok=true});assert(b.mode=='Result')
end)
check('Closing preserves the request and prevents a late result from reopening',function()
 fresh();stage();b:Merge();local p=b.pending;b:Close();app.panel.Visible=false
 assert(b.pending==p)
 app.state.pets={{id=p.payload.firstId,species='Camo',level=2,eggsPerSecond=16}}
 b:Receive({id=p.id,ok=true});assert(not b.pending and b.mode=='Main' and not app.panel.Visible)
end)
check('Reopen an in-flight request; server rejection returns to safe empty selection',function()
 fresh();stage();b:Merge();local p=b.pending;b:Close();b:Reset();b:Render(true)
 assert(b.pending==p and b.mode=='Processing' and b.presentation)
 b:Receive({id=p.id,ok=false,message='That chicken is no longer available.'})
 assert(b.mode=='Main' and b.selection:Count()==0 and b.notice)
end)
check('Delayed request waits for acknowledged status, without submitting another fuse',function()
 fresh();stage();b:Merge();local p=b.pending;task.wait(12.1)
 assert(b.pending==p and p.checking and p.syncId and app.requests[p.syncId].action=='Sync')
 local before=#app.requests;b:Merge();assert(#app.requests==before)
 app.state.pets={{id=p.payload.firstId,species='Camo',level=2,eggsPerSecond=16}}
 b:Receive({id=p.id+1000,ok=true});assert(b.pending==p)
 b:Receive({id=p.syncId,action='Sync',ok=true});assert(b.mode=='Result' and not b.pending)
end)
check('Desktop and compact layouts preserve action targets and scroll short content',function()
 fresh();stage()
 for _,size in {{1000,870},{723,629},{390,720},{320,568},{700,320}} do
  app.panelWidth,app.panelHeight=size[1],size[2];panel.Size=UDim2.fromOffset(size[1],size[2]);b:Render(true)
  assert(b.action.Position.Y.Offset+b.action.Size.Y.Offset<=size[2])
  assert(b.action.Size.Y.Offset>=44 and b.closeButton.Size.Y.Offset>=44)
  for _,slot in b.slots do assert(slot.action.Size.Y.Offset>=44 and slot.box.Size.X.Offset>0) end
  assert(b.main.Size.Y.Offset>0 and b.main.CanvasSize.Y.Offset>0)
  if size[1]==1000 or size[1]==723 or size[1]==390 then assert(b.main.CanvasSize.Y.Offset<=b.main.Size.Y.Offset+2) end
 end
end)
b:Destroy();gui:Destroy()
return results
