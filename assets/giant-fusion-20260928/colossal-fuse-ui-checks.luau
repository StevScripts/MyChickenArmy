-- Disposable UI fixture. Run in Studio runtime; no real profile or purchases.
local Client=game.StarterPlayer.StarterPlayerScripts.PetRoll:Clone();Client.Name='FuseVisualChecks';Client.Parent=game.ServerStorage
local Browser=require(Client.MergeBrowser)
local Preview=require(Client.ChickenPreview)
local gui=Instance.new('ScreenGui');gui.Name='FuseFlowChecks';gui.Enabled=false;gui.Parent=game.ServerStorage
local panel=Instance.new('Frame');panel.Size=UDim2.fromOffset(1000,870);panel.Parent=gui
local recipe={price=2400,key='Camo:1:1',species='Camo',stars=1,level=1,count=3,petIds={'a','b','c'},inputEggRate=8,afterEggRate=16,beforeDps=10,afterDps=12.5}
local app={state={coins=2400,mergeOptions={recipe},pets={},plotIndex=1},panel=panel,panelWidth=1000,panelHeight=870,page='Merge',reducedMotion=true,
 audio={Play=function() end},requests={}}
function app:Pet(id) for _,pet in self.state.pets do if pet.id==id then return pet end end end
function app:Preview(...) return Preview.Create(...) end
function app:Request(action,payload) table.insert(self.requests,{action=action,payload=payload});return #self.requests end
function app:ClosePanel() self.panel.Visible=false end
local b=Browser.new(app,panel);b.root.Visible=true
function b:NearStand() return true end

local results={}
local function check(name,fn) local ok,why=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil}) end
local function stage(species)
 b.pending=nil;b:Reset();recipe.species=species;recipe.key=species..':1:1'
 app.state.pets={};b:Render(true)
 for i=1,3 do b:Slot(i);b:Choose(recipe.key) end
end
check('Fresh fuse preview displays exact Legendary and Mythic Colossal odds',function()
 stage('Wizard');assert(b.tradeoff.Text=='11–22 studs · 1% Colossal',b.tradeoff.Text)
 stage('StormDuck');assert(b.tradeoff.Text=='15–27.5 studs · 3% Colossal',b.tradeoff.Text)
end)
check('Inherited Colossal preview shows guaranteed result and fixed low-rarity size',function()
 stage('StormDuck');app.state.pets={{id='b',giantSize=22,level=1}};b:Render(true)
 assert(b.tradeoff.Text=='22–27.5 studs · 100% Colossal',b.tradeoff.Text)
 stage('Camo');app.state.pets={{id='b',giantSize=20.4,level=1}};b:Render(true)
 assert(b.tradeoff.Text=='Colossal · 20.4 studs',b.tradeoff.Text)
end)
b:Destroy();gui:Destroy();Client:Destroy()
return results

