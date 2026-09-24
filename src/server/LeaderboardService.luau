--!strict
-- Global rankings are a projection of authoritative sessions, never a money source.
local Players=game:GetService("Players")
local DataStoreService=game:GetService("DataStoreService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Colors=require(Shared.UIColors)
local Leaderboards={}
Leaderboards.__index=Leaderboards
local DEFINITIONS={{name="CashBoard",title="MOST CASH",key="Cash",field="coins",cash=true},
 {name="DefeatsBoard",title="CHICKENS DEFEATED",key="EnemyDefeats",field="enemyKills"}}

local function amount(value,cash)
 local whole=tostring(math.floor(value))
 local grouped=whole:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
 return (if cash then "$" else "")..grouped
end

function Leaderboards.new(world,sessions,stores)
 local self=setmetatable({world=world,sessions=sessions,boards={},names={},stores=stores,
  nextUpdate=0,busy=false,alive=true,writing={}},Leaderboards)
 self.preview=stores==nil and (RunService:IsStudio() or not Config.SaveEnabled)
 if not self.preview and not self.stores then
  self.stores={}
  for _,def in DEFINITIONS do
   self.stores[def.key]=DataStoreService:GetOrderedDataStore(Config.SaveName.."_Global_"..def.key.."_v1")
  end
 end
 return self
end

function Leaderboards:Build()
 local plot=self.world.plots[1]
 local group=plot and plot.folder:FindFirstChild("Leaderboards")
 if not group then return end
 for _,def in DEFINITIONS do
  local board=group:FindFirstChild(def.name)
  local screen=board and board:FindFirstChild("Screen")
  if not screen then continue end
  for _,d in board:GetDescendants() do if d:IsA("BillboardGui") then d.Enabled=false end end
  local gui=Instance.new("SurfaceGui")
  gui.Name="GlobalRanking";gui.Face=Enum.NormalId.Left;gui.CanvasSize=Vector2.new(420,630)
  gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.MaxDistance=110;gui.Parent=screen
  local body=Instance.new("Frame");body.Size=UDim2.fromScale(1,1);body.BackgroundColor3=Color3.fromRGB(9,17,13)
  body.BackgroundTransparency=0.12;body.BorderSizePixel=0;body.Parent=gui
  local function label(name,text,y,height,size,color)
   local l=Instance.new("TextLabel");l.Name=name;l.Text=text;l.Font=Enum.Font.SourceSansBold;l.TextSize=size
   l.TextColor3=color or Colors.Text;l.TextStrokeColor3=Color3.fromRGB(6,12,8);l.TextStrokeTransparency=0.4
   l.BackgroundTransparency=1;l.Position=UDim2.fromOffset(14,y);l.Size=UDim2.new(1,-28,0,height);l.Parent=body
   return l
  end
  label("Heading",def.title,12,66,32,if def.cash then Colors.Rewards else Colors.Army)
  local status=label("Status",if self.preview then "STUDIO PREVIEW" else "GLOBAL",78,28,18)
  local rows={}
  for i=1,8 do
   rows[i]=label("Rank"..i,"",118+(i-1)*55,51,24)
   rows[i].TextXAlignment=Enum.TextXAlignment.Left
  end
  label("Footer",if def.cash then "Current cash" else "NPC defeats · tracked from this update",582,36,18)
  local mirrors={}
  for index,home in self.world.plots do if index~=1 then
   local otherGroup=home.folder:FindFirstChild("Leaderboards")
   local otherBoard=otherGroup and otherGroup:FindFirstChild(def.name)
   local otherScreen=otherBoard and otherBoard:FindFirstChild("Screen")
   if otherScreen then
    for _,d in otherBoard:GetDescendants() do if d:IsA("BillboardGui") then d.Enabled=false end end
    local copy=gui:Clone();copy.Parent=otherScreen
    local copyBody=copy:FindFirstChildOfClass("Frame")
    table.insert(mirrors,copyBody)
   end
  end end
  self.boards[def.key]={rows=rows,status=status,mirrors=mirrors}
  local function mirror()
   for _,copy in mirrors do
    copy.Status.Text=status.Text
    for i,row in rows do copy["Rank"..i].Text=row.Text end
   end
  end
  status:GetPropertyChangedSignal("Text"):Connect(mirror)
  for _,row in rows do row:GetPropertyChangedSignal("Text"):Connect(mirror) end
  mirror()
 end
end

function Leaderboards:Write(session)
 if self.preview or not session.loaded or session.saveLost or session.saveStatus=="studio-session"
  or self.writing[session.userId] then return end
 self.writing[session.userId]=true
 -- Capture before yielding; clients never submit leaderboard scores.
 local values={Cash=session.coins,EnemyDefeats=session.enemyKills or 0}
 for _,def in DEFINITIONS do
  local ok,err=pcall(function() self.stores[def.key]:SetAsync(tostring(session.userId),math.floor(values[def.key])) end)
  if not ok then warn("[ChickenLeaderboards] "..def.key.." update deferred: "..tostring(err)) end
 end
 self.writing[session.userId]=nil
end

function Leaderboards:Refresh()
 for _,def in DEFINITIONS do
  if not self.alive then return end
  local board=self.boards[def.key]
  if not board then continue end
  local entries={}
  local ok=true
  if self.preview then
   for _,session in self.sessions do if session.loaded and not session.saveLost then
    table.insert(entries,{key=tostring(session.userId),value=math.floor(session[def.field] or 0)})
    self.names[session.userId]=session.name
   end end
   table.sort(entries,function(a,b) if a.value==b.value then return a.key<b.key end;return a.value>b.value end)
  else
   ok,entries=pcall(function() return self.stores[def.key]:GetSortedAsync(false,8):GetCurrentPage() end)
  end
  if not ok then board.status.Text="Rankings unavailable · retrying";continue end
  board.status.Text=if self.preview then "STUDIO PREVIEW" else "GLOBAL"
  for i,row in board.rows do
   local entry=entries[i]
   if entry then
    local id=tonumber(entry.key)
    local name=self.names[id]
    if not name then
     local fetched,result=pcall(Players.GetNameFromUserIdAsync,Players,id)
     name=if fetched then result else "Player "..entry.key
     if fetched then self.names[id]=name end
    end
    if not self.alive then return end
    row.Text=i..". "..string.sub(name,1,16).."\n    "..amount(entry.value,def.cash)
   else row.Text=if i==1 then "No rankings yet" else "" end
  end
 end
end

function Leaderboards:Step(now)
 if not self.alive or self.busy or now<self.nextUpdate then return end
 self.nextUpdate=now+(if self.preview then 5 else 60);self.busy=true
 task.spawn(function()
  local ok,err=pcall(function()
   for _,session in self.sessions do if not session.closing then self:Write(session) end end
   self:Refresh()
  end)
  self.busy=false
  if not ok then warn("[ChickenLeaderboards] Refresh deferred: "..tostring(err)) end
 end)
end

function Leaderboards:Destroy()
 self.alive=false
end
return Leaderboards
