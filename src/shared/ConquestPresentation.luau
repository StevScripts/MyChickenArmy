--!strict
-- Presentation only. Capture authority and duration remain in Battle/Config.
local Colors=require(script.Parent.UIColors)
return table.freeze({
	Progress=Colors.Conquest,Owned=Colors.Money,Track=Colors.ConquestTrack,
	Width=20,Height=5.6,Elevation=11,MaxDistance=220,Segments=4,
	BurstSeconds=3.2,BurstRadiusMultiplier=1.6,SparkleCount=54,
})
