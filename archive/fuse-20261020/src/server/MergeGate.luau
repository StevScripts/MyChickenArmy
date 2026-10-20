--!strict
-- Cosmetic sectional door for the authored fuse machine. Originals are restored exactly.
local TweenService=game:GetService("TweenService")
local Gate={}
Gate.__index=Gate

function Gate.new(model,frame)
 local bounds,size=model:GetBoundingBox()
 local self=setmetatable({model=model,frame=frame,originals={},rows={},tracks={},serial=0},Gate)
 local centers={}
 for _,part in model:GetDescendants() do
  if part:IsA("BasePart") then
   table.insert(self.originals,{part=part,transparency=part.Transparency,collide=part.CanCollide,
    query=part.CanQuery,touch=part.CanTouch})
   -- The authored broad horizontal panels define the four real door sections.
   if part:IsA("Part") and part.Shape==Enum.PartType.Block and part.Size.X>size.X*0.6
    and part.Size.Y>size.Y*0.06 and part.Size.Y<size.Y*0.25 then
    table.insert(centers,frame:PointToObjectSpace(part.Position).Y)
   end
  end
 end
 local bottom=frame:PointToObjectSpace(bounds.Position).Y-size.Y/2
 local top=bottom+size.Y
 if #centers==0 then for i=1,4 do table.insert(centers,bottom+size.Y*(i-0.5)/4) end end
 table.sort(centers)
 local radius=math.min(0.75,size.Y*0.14)
 local turnY=top-radius-0.25
 local distance=math.max(0,turnY-centers[1])+radius*math.pi/2+radius
 for i,y in centers do
  local row={parts={},y=y,bottom=if i==1 then bottom else (centers[i-1]+y)/2,
   top=if i==#centers then top else (centers[i+1]+y)/2,points={}}
  local rise=math.max(0,turnY-y)
  table.insert(row.points,{at=0,pose=frame*CFrame.new(0,y,0),hidden=0})
  table.insert(row.points,{at=rise/distance,pose=frame*CFrame.new(0,y+rise,0),hidden=0})
  -- Three ordinary CFrame tweens approximate the quarter-circle beneath the header.
  for step=1,3 do
   local angle=step*math.pi/6
   table.insert(row.points,{at=(rise+radius*angle)/distance,
    pose=frame*CFrame.new(0,y+rise+radius*math.sin(angle),radius*(1-math.cos(angle)))*CFrame.Angles(angle,0,0),
    hidden=if step==3 then 1 else 0})
  end
  table.insert(row.points,{at=(rise+radius*math.pi/2+radius)/distance,
   pose=frame*CFrame.new(0,y+rise+radius,radius*2)*CFrame.Angles(math.pi/2,0,0),hidden=1})
  table.insert(self.rows,row)
 end
 return self
end

function Gate:BuildSections()
 local folder=Instance.new("Folder");folder.Name="RetractingDoor";folder.Parent=self.model.Parent
 self.folder=folder
 local function add(source,row,cf,size)
  local part=source:Clone();part.Name="DoorSection";part:ClearAllChildren()
  part.Size,part.CFrame=size,cf
  part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch=true,false,false,false
  part.Parent=folder
  table.insert(row.parts,{part=part,offset=row.points[1].pose:ToObjectSpace(cf),transparency=source.Transparency})
 end
 for _,entry in self.originals do
  local part=entry.part
  local y=self.frame:PointToObjectSpace(part.Position).Y
  local nearest=self.rows[1]
  for _,row in self.rows do if math.abs(row.y-y)<math.abs(nearest.y-y) then nearest=row end end
  -- Split only plain, upright backing blocks. Keep trim/hinge shapes on their section.
  if part:IsA("Part") and part.Shape==Enum.PartType.Block and math.abs(part.CFrame.UpVector.Y)>0.99
   and part.Size.Y>(nearest.top-nearest.bottom)*1.4 then
   for _,row in self.rows do
    local low=math.max(y-part.Size.Y/2,row.bottom)
    local high=math.min(y+part.Size.Y/2,row.top)
    if high>low then
     add(part,row,part.CFrame+Vector3.new(0,(low+high)/2-y,0),Vector3.new(part.Size.X,high-low,part.Size.Z))
    end
   end
  else add(part,nearest,part.CFrame,part.Size) end
  part.Transparency,part.CanCollide,part.CanQuery,part.CanTouch=1,false,false,false
 end
end

function Gate:Move(open,seconds)
 self.serial+=1
 local serial=self.serial
 for _,tween in self.tracks do tween:Cancel() end;table.clear(self.tracks)
 if not self.folder then self:BuildSections() end
 for _,row in self.rows do
  local points=row.points
  for i=1,#points-1 do
   local from=if open then points[i] else points[#points-i+1]
   local goal=if open then points[i+1] else points[#points-i]
   local delay=if open then from.at*seconds else (1-from.at)*seconds
   local duration=math.max(0.001,math.abs(goal.at-from.at)*seconds)
   task.delay(delay,function()
    if self.serial~=serial or not self.folder or not self.model.Parent then return end
    for _,entry in row.parts do
     local tween=TweenService:Create(entry.part,TweenInfo.new(duration,Enum.EasingStyle.Linear),{
      CFrame=goal.pose*entry.offset,Transparency=entry.transparency+(1-entry.transparency)*goal.hidden})
     table.insert(self.tracks,tween);tween:Play()
    end
   end)
  end
 end
end

function Gate:Reset()
 self.serial+=1
 for _,tween in self.tracks do tween:Cancel() end;table.clear(self.tracks)
 if self.folder then self.folder:Destroy();self.folder=nil end
 for _,row in self.rows do table.clear(row.parts) end
 for _,entry in self.originals do
  if entry.part.Parent then
   entry.part.Transparency,entry.part.CanCollide=entry.transparency,entry.collide
   entry.part.CanQuery,entry.part.CanTouch=entry.query,entry.touch
  end
 end
end

return Gate
