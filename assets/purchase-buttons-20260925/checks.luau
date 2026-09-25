local player=game.Players.LocalPlayer
local modules=player.PlayerScripts.PetRoll
local Theme=require(modules.UITheme)
local Yard=require(modules.UpgradeBoardController)
local Egg=require(modules.EggProcessorController)
local Motion=require(modules.UIMotion)
local world=workspace.PetRollWorld
local fixture=Instance.new("Folder")
fixture.Name="PurchasePresentationCheck"; fixture.Parent=player.PlayerGui
local results={}
local function check(name,ok) assert(ok,name); table.insert(results,name) end
local function same(a,b)
 if #a.Keypoints~=#b.Keypoints then return false end
 for i,p in a.Keypoints do local q=b.Keypoints[i] if p.Time~=q.Time or p.Value~=q.Value then return false end end
 return true
end
local requested=0
local app={state={plotIndex=1,coins=0,boardUpgrades={},eggs={processor={enabled=true,queuedCount=100,readyCash=0,rate=1,level=0,upgradePrice=100}}},
 audio={Play=function() end},commerce={State=function() return "ready" end},
 Request=function() requested+=1;return "fixture" end,Notify=function() end}
for _,key in require(game.ReplicatedStorage.PetRoll.Shared.UpgradeCatalog).Order do
 app.state.boardUpgrades[key]={ready=true,price=100,unlocked=true,currentText="1",nextText="2",level=0}
end
local yard=Yard.new(app); yard.playerGui=fixture
local egg=Egg.new(app); egg.playerGui=fixture
local motion=Motion.new()
local ok,err=xpcall(function()
 yard:Bind(world.UpgradesStand.Screen.SurfaceGui)
 egg:Bind(world.EggCollectionBoard.Screen.SurfaceGui)
 local _,yv=next(yard.views); local _,ev=next(egg.views)
 check("authored boards bind",yv~=nil and ev~=nil)
 local finish=ev.content.FinishNow.Visual.Face.UIGradient.Color
 for _,coins in {0,99,100,101,0,100} do
  app.state.coins=coins; yard:Render();egg:Render()
  for key,c in yv.cards do
   check("yard "..key.." cash "..coins,same(c.gradient.Color,if coins<100 then Theme.UnaffordableGradient else c.affordableGradient))
   check("yard "..key.." fixed hit target",c.button.BackgroundTransparency==1 and c.visual:FindFirstChild("Outline")~=nil and c.button:FindFirstChild("Outline")==nil)
  end
  check("egg upgrade cash "..coins,same(ev.upgradeGradient.Color,if coins<100 then Theme.UnaffordableGradient else ev.affordableGradient))
  check("Finish Now unchanged cash "..coins,same(ev.content.FinishNow.Visual.Face.UIGradient.Color,finish))
 end
 app.state.coins=0
 yard:Purchase("EggSpeed");egg:Activate("Upgrade")
 check("unaffordable sends no purchase request",requested==0)
 yard.pending.EggSpeed="fixture";egg.pending="fixture"
 yard:Render();egg:Render()
 check("pending prevents duplicate activation",not yv.cards.EggSpeed.button.Active and not ev.content.Upgrade.Active)
 yard.pending.EggSpeed=nil;egg.pending=nil
 app.state.boardUpgrades.EggSpeed.price=nil;app.state.eggs.processor.upgradePrice=nil
 yard:Render();egg:Render()
 check("MAX remains inactive",not yv.cards.EggSpeed.button.Active and not ev.content.Upgrade.Active)
 check("MAX restores authored gradients",same(yv.cards.EggSpeed.gradient.Color,yv.cards.EggSpeed.affordableGradient) and same(ev.upgradeGradient.Color,ev.affordableGradient))
 -- Exercise the exact bound callbacks with signals, real visual instances and real tweens.
 local signals={}
 local function signal(name)
  local s={callbacks={}}
  function s:Connect(fn)
   local c={Connected=true}
   function c:Disconnect() self.Connected=false end
   table.insert(self.callbacks,{fn=fn,c=c});return c
  end
  function s:Fire() for _,v in self.callbacks do if v.c.Connected then v.fn() end end end
  signals[name]=s;return s
 end
 local button={Active=true}
 for _,name in {"MouseEnter","MouseLeave","SelectionGained","SelectionLost","MouseButton1Down","MouseButton1Up","Activated","Destroying"} do button[name]=signal(name) end
 function button:GetPropertyChangedSignal(name) return signals[name] or signal(name) end
 local visual=Instance.new("Frame");visual.Parent=fixture
 local face=Instance.new("Frame");face.ZIndex=20;face.Parent=visual
 local rim=Instance.new("UIStroke");rim.Parent=face
 motion:BindButton(button,visual,face,rim)
 local scale=visual.MotionScale
 local function close(actual,expected) return math.abs(actual-expected)<0.002 end
 signals.MouseEnter:Fire();task.wait(0.2)
 check("PC hover grows visual",close(scale.Scale,1.03))
 check("shine renders above raised face",face.MotionShine.ZIndex>face.ZIndex)
 signals.MouseButton1Down:Fire();task.wait(0.1)
 check("PC press compresses visual",close(scale.Scale,0.955))
 signals.MouseButton1Up:Fire();signals.MouseLeave:Fire();task.wait(0.2)
 check("release settles",close(scale.Scale,1))
 signals.Activated:Fire()
 check("tap activation compresses without hover",close(scale.Scale,0.955))
 task.wait(0.2);check("tap release settles",close(scale.Scale,1))
 button.Active=false;signals.Active:Fire();signals.Activated:Fire();task.wait(0.2)
 check("inactive has no press feedback",close(scale.Scale,1))
 button.Active=true;signals.Active:Fire();motion.reduced=true;signals.Activated:Fire()
 check("reduced motion skips scale",close(scale.Scale,1))
 signals.Destroying:Fire()
 check("binding cleanup",motion.bindings[button]==nil)
end,debug.traceback)
yard:Destroy();egg:Destroy();fixture:Destroy()
assert(ok,err)
return game:GetService("HttpService"):JSONEncode({passed=#results,checks=results,requests=requested})
