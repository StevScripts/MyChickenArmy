-- Disposable client fixture; requests stay in memory, never sent to the server.
local player=game.Players.LocalPlayer
local Browser=require(player.PlayerScripts.PetRoll.ChickenBrowser)
local gui=Instance.new('ScreenGui');gui.Name='ColossalUIChecks';gui.DisplayOrder=100;gui.Parent=player.PlayerGui
local panel=Instance.new('Frame');panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
panel.Size=UDim2.fromOffset(930,600);panel.BackgroundTransparency=1;panel.Parent=gui
local function pet(id,species,size,selected)
 return {id=id,species=species,stars=1,level=2,giantSize=size,selected=selected,home=true,
  deployed=false,canSell=not selected,refund=100,income=8,levelCap=3}
end
local app={gui=gui,panel=panel,panelTitle=Instance.new('TextLabel'),panelWidth=930,panelHeight=600,selected='new',
 state={pets={pet('old','Dragon',21,true),pet('new','StormDuck',26,false),pet('normal','Duck',nil,true),
  pet('small','Camo',8,false),pet('other','Bucket',12,false)},selectedIds={'old','normal'},capacity=3,
  collectionLimit=25,selectionMode='Manual',armyState='Home',incomeLevel=0,homeEggsPerSecond=16},
 audio={Play=function() end},requests={}}
function app:Pet(id) for _,p in self.state.pets do if p.id==id then return p end end end
function app:Request(action,payload) table.insert(self.requests,{action=action,payload=payload});return #self.requests end
function app:ClosePanel() panel.Visible=false end
function app:OpenPage() end
function app:PetIncome(p) return p.income end
local b=Browser.new(app,panel);b.root.Visible=true;b.inspecting=true;b:Render(true)
local results={}
local function check(name,fn)
 local ok,why=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
 b.pending=nil;b.notice=nil;b:Render(true)
end
check('Colossal inspector labels actual size and offers an explicit replacement',function()
 assert(b.assign.Text=='Replace Colossal' and b.assign.Active)
 assert(b.detailNotice.Text=='Only 1 Colossal per army.')
 assert(string.find(b.metadata.Text,'Colossal · 26.0 studs',1,true))
 b:TogglePet('new');local r=app.requests[#app.requests]
 assert(r.action=='SetArmy' and table.concat(r.payload.petIds,',')=='new,normal')
 assert(table.concat(r.payload.expectedIds,',')=='old,normal')
end)
check('Dragging a second Colossal into a different slot or empty slot cannot submit',function()
 local n=#app.requests
 for _,slot in {2,3} do
  b:Drop('new',slot,false,app.state.selectedIds)
  assert(#app.requests==n and not b.pending and string.find(b.notice,'Only 1 Colossal',1,true))
 end
end)
check('Smaller Giants can equip normally; an equipped Colossal can unequip',function()
 b:TogglePet('small');assert(table.concat(app.requests[#app.requests].payload.petIds,',')=='old,normal,small')
 b.pending=nil;b:TogglePet('old');assert(table.concat(app.requests[#app.requests].payload.petIds,',')=='normal')
end)
check('Desktop and compact Colossal controls fit and retain accessible target sizes',function()
 for _,size in {{930,600},{390,720}} do
  app.panelWidth,app.panelHeight=size[1],size[2];panel.Size=UDim2.fromOffset(size[1],size[2]);b:Render(true)
  assert(b.assign.Text=='Replace Colossal' and b.assign.Size.Y.Offset>=44)
  assert(b.assign.Position.X.Offset+b.assign.Size.X.Offset<=b.detail.Size.X.Offset or b.assign.Size.X.Scale>0)
 end
end)
app.panelWidth,app.panelHeight=930,600;panel.Size=UDim2.fromOffset(930,600);b:Render(true)
_G.ColossalUIFixture={gui=gui,browser=b,app=app}
return results
