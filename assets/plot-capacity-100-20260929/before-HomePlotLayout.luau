--!strict
-- All six homes use the builder's normalized native template, in plot-local coordinates.
-- Front faces the center; roller at the rear, Sell and Merge along the left wall.
local Layout = {
 Width=72, Depth=60, GateWidth=26, FootY=0.30,
 Roll=CFrame.new(0.45,0,24.3),
 Merge=CFrame.new(-27,0,12)*CFrame.Angles(0,-math.pi/2,0),
 Sell=CFrame.new(-27.85,0,-10)*CFrame.Angles(0,-math.pi/2,0),
 Spawn=CFrame.new(-11,4,6), Entrance=CFrame.new(0,0.32,-29), AssemblyZ=-33,
 YardMinX=-15,YardMaxX=15,YardMinZ=-21,YardMaxZ=21,
}
local authored = {
 Width=73.86, Depth=78, GateWidth=13, FootY=0.193,
 Spawn=CFrame.new(-0.5,3.8,-23.5), Entrance=CFrame.new(-0.49,0.1,-31), AssemblyZ=-43,
 YardMinX=-11.9,YardMaxX=11.9,YardMinZ=-11.5,YardMaxZ=11.5,
}
local runtimeYards = {}

-- Plot1 starts square, extends past the fixed machines, then opens a wide back.
local teeStages = {
 {back=6.5,width=30}, {back=12.5,width=30}, {back=18.5,width=30}, {back=25.5,width=30},
 {back=33.5,width=48}, {back=39.5,width=60}, {back=45.5,width=72}, {back=50.5,width=84},
}
function Layout.TeeYard(level:number)
 local stage=teeStages[math.clamp(math.floor(level),0,#teeStages-1)+1]
 local front,stemHalf,shoulder=-23.5,15,math.min(stage.back,25.5)
 local half=stage.width/2
 local outline={Vector2.new(-stemHalf,front),Vector2.new(stemHalf,front),
  Vector2.new(stemHalf,shoulder),Vector2.new(half,shoulder),Vector2.new(half,stage.back),
  Vector2.new(-half,stage.back),Vector2.new(-half,shoulder),Vector2.new(-stemHalf,shoulder)}
 local minZ,maxZ=front+1.6,stage.back-1.6
 local regions={{minX=-stemHalf+1.6,maxX=stemHalf-1.6,minZ=minZ,maxZ=maxZ}}
 if half>stemHalf then
  -- The regions meet across the neck; there is no gap in the usable interior.
  regions[1].maxZ=shoulder+1.6
  table.insert(regions,{minX=-half+1.6,maxX=half-1.6,minZ=shoulder+1.6,maxZ=maxZ})
 end
 return {YardMinX=-half+1.6,YardMaxX=half-1.6,YardMinZ=minZ,YardMaxZ=maxZ,
  YardRegions=regions},outline
end

function Layout.Sample(layout,u:number,v:number):(number,number)
 local regions=layout.YardRegions
 if not regions then
  return layout.YardMinX+u*(layout.YardMaxX-layout.YardMinX),layout.YardMinZ+v*(layout.YardMaxZ-layout.YardMinZ)
 end
 local total=0
 for _,r in regions do total+=(r.maxX-r.minX)*(r.maxZ-r.minZ) end
 local remaining=math.clamp(v,0,1)*total
 for i,r in regions do
  local area=(r.maxX-r.minX)*(r.maxZ-r.minZ)
  if remaining<=area or i==#regions then
   return r.minX+u*(r.maxX-r.minX),r.minZ+math.clamp(remaining/area,0,1)*(r.maxZ-r.minZ)
  end
  remaining-=area
 end
 return layout.YardMinX,layout.YardMinZ
end

function Layout.Clamp(layout,x:number,z:number):(number,number)
 if not layout.YardRegions then
  return math.clamp(x,layout.YardMinX,layout.YardMaxX),math.clamp(z,layout.YardMinZ,layout.YardMaxZ)
 end
 local bestX,bestZ,distance=x,z,math.huge
 for _,r in layout.YardRegions do
  local cx,cz=math.clamp(x,r.minX,r.maxX),math.clamp(z,r.minZ,r.maxZ)
  local d=(cx-x)^2+(cz-z)^2
  if d<distance then bestX,bestZ,distance=cx,cz,d end
 end
 return bestX,bestZ
end

function Layout.CanWalkDirect(layout,x1:number,z1:number,x2:number,z2:number):boolean
 local regions=layout.YardRegions
 if not regions then return true end
 for _,r in regions do
  if x1>=r.minX and x1<=r.maxX and z1>=r.minZ and z1<=r.maxZ
   and x2>=r.minX and x2<=r.maxX and z2>=r.minZ and z2<=r.maxZ then return true end
 end
 if #regions<2 or math.abs(z2-z1)<1e-6 then return false end
 local stem,head=regions[1],regions[2]
 local t=(head.minZ-z1)/(z2-z1)
 local x=x1+(x2-x1)*t
 local a,b=Layout.Clamp(layout,x1,z1)
 local c,d=Layout.Clamp(layout,x2,z2)
 return math.abs(a-x1)+math.abs(b-z1)+math.abs(c-x2)+math.abs(d-z2)<1e-4
  and t>=0 and t<=1 and x>=stem.minX and x<=stem.maxX
end

function Layout.SetYard(index:number, bounds)
 if not bounds then runtimeYards[index]=nil;return end
 local layout=table.clone(authored)
 for key,value in bounds do layout[key]=value end
 runtimeYards[index]=layout
end
function Layout.ForPlot(index:number)
 return runtimeYards[index] or authored
end
function Layout.Home(index:number,plotIndex:number?):(number,number)
 local yard=plotIndex and runtimeYards[plotIndex]
 if yard then
  local cell=((math.max(1,math.floor(index))-1)*17)%64
  return Layout.Sample(yard,(cell%8+0.5)/8,(math.floor(cell/8)+0.5)/8)
 end
 local ordinal=(math.max(1,math.floor(index))-1)%40
 if plotIndex then
  local cell=(ordinal*17)%42
  return -10.5+(cell%6)*4.2,-10.5+math.floor(cell/6)*3.5
 end
 local columns={-13,-10,-7,7,10,13}
 -- Fill the whole yard from the first few recruits instead of filling front rows.
 local cell=(ordinal*17)%42
 return columns[cell%6+1],-18+math.floor(cell/6)*6
end
return Layout
