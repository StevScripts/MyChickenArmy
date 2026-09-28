assert(game.PlaceId==96683186622050 and not game:GetService('RunService'):IsRunning())
local models=game.ServerStorage.ApprovedEightImport20260927.Models
local textures={Glitter='rbxassetid://78670800898830',Star='rbxassetid://108947004524152',Smoke='rbxassetid://96448486330893'}
local function seq(a,b,c) return NumberSequence.new({NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(.3,b),NumberSequenceKeypoint.new(1,c)}) end
local function anchor(m,label,bone,point)
 local b=assert(m.Body:FindFirstChild(m.Name..'_'..bone,true))
 local a=Instance.new('Attachment');a.Name='TraitVFX_'..label;a.Parent=b
 -- Author coordinates use Blender X/right, Y/back, Z/up. Convert to Roblox Y/up.
 local p=Vector3.new(point[1],point[3],-point[2])*.670163170
 a.CFrame=b.WorldCFrame:ToObjectSpace(CFrame.new(p));return a
end
local function particles(a,label,texture,color,rate,size,speed,gravity)
 local e=Instance.new('ParticleEmitter');e.Name=label;e.Texture=textures[texture]
 e.Color=ColorSequence.new(Color3.fromRGB(table.unpack(color)));e.Rate=rate;e.Lifetime=NumberRange.new(.5,1.05)
 e.Size=seq(0,size,0);e.Transparency=seq(.9,.1,1);e.Speed=NumberRange.new(speed*.55,speed)
 e.Acceleration=Vector3.new(0,gravity,0);e.SpreadAngle=Vector2.new(28,28);e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-35,35)
 e.LightEmission=.75;e.LightInfluence=0;e.Brightness=1.4;e.Enabled=true;e.Parent=a;return e
end
local function glow(a,color,brightness)
 local l=Instance.new('PointLight');l.Name='TraitGlow';l.Color=Color3.fromRGB(table.unpack(color));l.Brightness=brightness;l.Range=4;l.Shadows=false;l.Parent=a
end
for _,m in models:GetChildren() do
 assert(not m:GetAttribute('TraitVFXReady'),'Already authored '..m.Name)
 local n=m.Name
 if n=='Lollipop' then
  for _,s in {-1,1} do particles(anchor(m,'Candy'..s,'Wing_'..(if s<0 then 'L' else 'R'),{s*1.32,.1,2.35}),'CandyConfetti','Star',if s<0 then {255,30,156} else {15,230,255},2,.17,.5,.15) end
 elseif n=='Honeycomb' then
  for _,s in {-1,1} do particles(anchor(m,'Honey'..s,'Wing_'..(if s<0 then 'L' else 'R'),{s*1.3,.2,1.4}),'HoneyDrops','Glitter',{255,184,27},2,.14,.1,-1.4) end
 elseif n=='Toxic' then
  local a=anchor(m,'Vents','BackSocket',{0,1.45,3.62})
  local fog=particles(a,'ToxicVapor','Smoke',{156,255,24},4,.42,.45,.25);fog.Transparency=seq(1,.7,1)
  particles(a,'AcidSparks','Glitter',{202,255,0},4,.13,.7,.3)
 elseif n=='Water' then
  for _,s in {-1,1} do particles(anchor(m,'Spray'..s,'Wing_'..(if s<0 then 'L' else 'R'),{s*1.42,.1,2.82}),'WaterSpray','Glitter',{124,244,255},4,.13,.9,-1.2) end
  local e=particles(anchor(m,'Foam','BackSocket',{0,1.5,4.05}),'FoamMist','Smoke',{219,252,255},2,.29,.3,.1);e.Transparency=seq(1,.8,1)
 elseif n=='SolarFlare' then
  for _,s in {-1,1} do particles(anchor(m,'SolarWing'..s,'Wing_'..(if s<0 then 'L' else 'R'),{s*2.1,.1,2.3}),'SolarSparks','Glitter',{255,179,30},4,.2,.65,.3) end
  local a=anchor(m,'Corona','BackSocket',{0,1.7,3.8});particles(a,'CoronaStars','Star',{255,229,69},3,.2,.4,.3);glow(a,{255,204,38},.75)
 elseif n=='Heavenly' then
  for _,s in {-1,1} do particles(anchor(m,'AngelWing'..s,'Wing_'..(if s<0 then 'L' else 'R'),{s*2.15,.3,3.45}),'HeavenlyStars','Star',{255,241,172},2,.18,.4,-.15) end
  local a=anchor(m,'Halo','Head',{0,-.9,4.76});particles(a,'HaloGlimmer','Glitter',{255,245,185},2,.14,.3,.1);glow(a,{255,241,194},.4)
 elseif n=='Devil' then
  for _,s in {-1,1} do particles(anchor(m,'Embers'..s,'Wing_'..(if s<0 then 'L' else 'R'),{s*1.8,.1,2.4}),'DevilEmbers','Glitter',{255,96,18},3,.13,.5,.4) end
  local a=anchor(m,'Tail','BackSocket',{0,2.24,3.59});glow(a,{255,87,29},.3)
 elseif n=='Jungle' then
  particles(anchor(m,'Flower','Head',{.42,-1.12,4.65}),'FlowerPollen','Glitter',{255,218,72},2,.10,.22,-.1)
  for _,s in {-1,1} do particles(anchor(m,'Leaves'..s,'Wing_'..(if s<0 then 'L' else 'R'),{s*1.5,.2,2.5}),'LeafMotes','Glitter',{143,244,77},1,.12,.3,.1) end
 end
 m:SetAttribute('TraitVFXReady',true)
end
local library=game.ReplicatedStorage.PetRoll.ChickenAssets
local installed={}
for _,m in models:GetChildren() do
 assert(not library:FindFirstChild(m.Name),'Do not overwrite an existing species')
 local clone=m:Clone();clone.Parent=library;table.insert(installed,m.Name)
end
return installed
