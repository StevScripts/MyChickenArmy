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
function Layout.ForPlot(index:number)
 return authored
end
function Layout.Home(index:number,plotIndex:number?):(number,number)
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
