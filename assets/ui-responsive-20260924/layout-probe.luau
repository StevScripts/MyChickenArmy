-- Disposable CLIENT probe. Evaluate in Studio Flow's live client VM, then click
-- a HUD menu once. The one-shot wrapper immediately restores OpenPage.
local App=require(game.Players.LocalPlayer.PlayerScripts.PetRoll.AppController)
local original=App.OpenPage
local probe={results={}}
_G.McaUiProbe=probe
App.OpenPage=function(app,...)
 App.OpenPage=original
 probe.app=app
 return original(app,...)
end
function probe:Snapshot(label)
 local app=self.app
 local gui,shell,panel=app.gui,app.gui.Shell,app.panel
 local r={label=label,safe={gui.AbsoluteSize.X,gui.AbsoluteSize.Y},touch=game:GetService('UserInputService').TouchEnabled,
  panel={panel.AbsoluteSize.X,panel.AbsoluteSize.Y},failures={},buttons={},grids={},scrolls={}}
 local function shown(item)
  local node=item
  while node and node~=gui do
   if node:IsA('GuiObject') and not node.Visible then return false end
   node=node.Parent
  end
  return true
 end
 for _,item in gui:GetDescendants() do
  if item:IsA('GuiButton') and shown(item) then
   local size=item.AbsoluteSize
   table.insert(r.buttons,{name=item.Name,size={size.X,size.Y}})
   if item.Active and (size.X<47.5 or size.Y<47.5) then table.insert(r.failures,item.Name..' below 48px') end
  elseif item:IsA('UIGridLayout') and shown(item.Parent) then
   table.insert(r.grids,{name=item.Parent.Name,columns=item.AbsoluteCellCount.X,expected=item.FillDirectionMaxCells})
   local cells=0
   for _,child in item.Parent:GetChildren() do if child:IsA('GuiObject') and child.Visible then cells+=1 end end
   if item.AbsoluteCellCount.X~=math.min(cells,item.FillDirectionMaxCells) then table.insert(r.failures,item.Parent.Name..' unexpected wrap') end
  elseif item:IsA('ScrollingFrame') and shown(item) then
   table.insert(r.scrolls,{name=item.Name,window={item.AbsoluteWindowSize.X,item.AbsoluteWindowSize.Y},canvas={item.AbsoluteCanvasSize.X,item.AbsoluteCanvasSize.Y}})
   if item.AbsoluteCanvasSize.X>item.AbsoluteWindowSize.X+1 then table.insert(r.failures,item.Name..' horizontal overflow') end
  end
 end
 if panel.Visible then
  local pos,size=panel.AbsolutePosition-shell.AbsolutePosition,panel.AbsoluteSize
  if pos.X<0 or pos.Y<0 or pos.X+size.X>gui.AbsoluteSize.X+1 or pos.Y+size.Y>gui.AbsoluteSize.Y+1 then table.insert(r.failures,'Panel outside safe bounds') end
  if panel.Size.X.Offset~=0 or panel.Size.Y.Offset~=0 then table.insert(r.failures,'Panel uses fixed screen size') end
  if app.hud.settings.Visible then table.insert(r.failures,'Settings overlaps modal') end
 else
  local rail=app.hud.shortcuts
  r.hudCenter=(rail.AbsolutePosition.Y+rail.AbsoluteSize.Y/2-shell.AbsolutePosition.Y)/shell.AbsoluteSize.Y
  if not r.touch and math.abs(r.hudCenter-0.5)>0.001 then table.insert(r.failures,'Shop/Index not centered') end
 end
 table.insert(self.results,r)
 return r
end
function probe:Pages(label)
 local summary={}
 for _,page in {'Army','Shop','Index','Upgrades','Settings'} do
  self.app:OpenPage(page)
  task.wait(0.35)
  local r=self:Snapshot(label..'/'..page)
  table.insert(summary,{page=page,failures=r.failures,grids=r.grids})
 end
 return summary
end
function probe:ArmyExtras(label)
 self.app:OpenPage('Army');task.wait(0.3)
 local browser=self.app.chickenBrowser
 local fixtures={}
 for index=1,12 do
  local card=Instance.new('Frame')
  card.Name,card.BackgroundTransparency,card.LayoutOrder='LayoutFixture'..index,1,100+index
  card.Parent=browser.grid;table.insert(fixtures,card)
 end
 task.wait(0.1)
 local dense=self:Snapshot(label..'/Army-dense')
 for _,card in fixtures do card:Destroy() end
 local pet=self.app.state.pets[1]
 if pet then browser:Inspect(pet.id) end
 task.wait(0.1)
 local detail=self:Snapshot(label..'/Army-detail')
 browser.showInfo,browser.showCapacity=true,false;browser:Render(true);task.wait(0.1)
 local info=self:Snapshot(label..'/Army-stats')
 browser.showInfo,browser.showCapacity=false,true;browser:Render(true);task.wait(0.1)
 local capacity=self:Snapshot(label..'/Army-capacity')
 self.app:OpenPage('Shop');task.wait(0.3)
 self.app.shopBrowser:ShowDetails('Luck');task.wait(0.1)
 local shop=self:Snapshot(label..'/Shop-details')
 return {dense=dense.failures,detail=detail.failures,info=info.failures,capacity=capacity.failures,shop=shop.failures}
end
return 'Click any HUD menu to capture the real app, then call _G.McaUiProbe:Pages(label).'
