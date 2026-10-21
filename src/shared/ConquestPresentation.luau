--!strict
-- Presentation only. Capture authority and duration remain in Battle/Config.
local Colors=require(script.Parent.UIColors)
return table.freeze({
	Progress=Colors.Conquest,Owned=Colors.Money,Track=Colors.ConquestTrack,
	Width=20,Height=5.6,Elevation=11,MaxDistance=220,Segments=4,
	BurstSeconds=3.2,BurstRadiusMultiplier=1.6,SparkleCount=54,
	-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): the meter's own timings.
	FillSeconds=0.25, -- one snapshot's gain eased into the bar (snapshots arrive every 0.2 s)
	TickFlashSeconds=0.3,TickFlashPeak=0.5, -- white wash over the bar when a section completes
	TickPitchBase=0.9,TickPitchStep=0.1, -- CaptureTick/Pop pitch: base + step x section (1..Segments)
	PausedTransparency=0.4,DimSeconds=0.25, -- the meter dims while no attacker counts, and recovers
	AppearFrom=0.6,LeaveSeconds=0.14, -- grow-in scale and shrink-out time of the meter
	FanfareDelay=0.2, -- "Fanfare" follows the Victory burst by this much
	HitShakeGap=0.4,KnockoutShakeGap=1, -- screen-shake cooldowns: own chicken hit / knocked out
	HitShakeRange=30,KnockoutShakeRange=60, -- how close the chicken must be for a hit / knockout to shake the camera
})
