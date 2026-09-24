--!strict
-- Static floor-centered camp kit. WorldBuilder owns ground, commands and labels.
-- Envelope: 36 square, clear radius 14, four 14-wide approaches.
local Scenery = {}
local rgb = Color3.fromRGB
local C = {
	wood=rgb(170,85,0), dark=rgb(117,59,0), brace=rgb(255,137,97),
	stone=rgb(141,141,211), pale=rgb(188,192,255), cream=rgb(240,230,204),
	gold=rgb(255,170,0), ink=rgb(57,63,65), hay=rgb(237,194,71),
	sack=rgb(218,193,139), grass=rgb(132,191,103),
}
local themes = {
	{ground=C.grass,wall=C.wood,accent=rgb(217,113,50),roof=rgb(217,113,50)},
	{ground=rgb(128,181,110),wall=C.stone,accent=rgb(54,164,191),roof=rgb(54,164,191)},
	{ground=rgb(132,177,109),wall=C.stone,accent=rgb(104,125,80),roof=rgb(104,125,80)},
	{ground=rgb(138,182,111),wall=C.stone,accent=rgb(198,66,53),roof=rgb(198,66,53)},
	{ground=rgb(130,183,113),wall=C.stone,accent=rgb(58,93,135),roof=rgb(58,93,135)},
}
local optional = {
	{key="iron",accent=rgb(105,120,128),roof=rgb(105,120,128),symbol="shield"},
	{key="knight",accent=rgb(111,133,78),roof=rgb(111,133,78),symbol="shield"},
	{key="royal",accent=rgb(198,66,53),roof=C.dark,symbol="crown"},
	{key="dragon",accent=rgb(231,121,51),roof=rgb(65,68,72),symbol="dragon"},
	{key="frozen",accent=rgb(87,183,207),roof=rgb(117,169,187),symbol="ice"},
	{key="thunder",accent=C.gold,roof=rgb(52,76,114),symbol="bolt"},
	{key="supply",accent=C.gold,roof=C.cream,symbol="crate"},
}
local function profile(campName)
	local name = string.lower(campName or "")
	for _,entry in optional do
		if string.find(name,entry.key,1,true) then return entry end
	end
	return nil
end
function Scenery.Theme(index, campName)
	local extra=profile(campName)
	if extra then return {ground=C.grass,wall=C.stone,accent=extra.accent,roof=extra.roof} end
	return themes[math.clamp(index,1,#themes)]
end

function Scenery.Build(builder, parent, frame, edge, index, campName)
	local art = Instance.new("Model")
	art.Name, art.Parent = "Scenery", parent
	art:SetAttribute("MapRevision","builder-kit-20260917")
	art:SetAttribute("AuthoredHalfSize",18)
	local t, extra = Scenery.Theme(index,campName), profile(campName)
	local stage = if extra then 2 else math.clamp(index,1,3)
	local isSupply = extra ~= nil and extra.key == "supply"
	local floorMarks = {}
	local function group(name)
		local model=Instance.new("Model")
		model.Name,model.Parent=name,art
		model.WorldPivot=frame
		return model
	end
	local function part(owner,name,size,cf,color,tint,studs)
		local p=builder.Part(owner,name,size,frame*cf,color,false)
		p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
		p.Material,p.CastShadow=Enum.Material.Plastic,size.Y>.4
		p.TopSurface=if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
		p.BottomSurface=Enum.SurfaceType.Smooth
		if studs and size.Y>=1 then
			p.FrontSurface,p.BackSurface=Enum.SurfaceType.Studs,Enum.SurfaceType.Studs
		end
		if tint then p:SetAttribute("CampTint",tint) end
		return p
	end
	local function block(owner,name,cf,x,y,z,sx,sy,sz,color,tint,studs)
		return part(owner,name,Vector3.new(sx,sy,sz),cf*CFrame.new(x,y,z),color,tint,studs)
	end
	local function wedge(owner,name,size,cf,color,tint)
		local p=Instance.new("WedgePart")
		p.Name,p.Size,p.CFrame,p.Color=name,size,frame*cf,color
		p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
		p.Material,p.CastShadow=Enum.Material.Plastic,true
		p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
		if tint then p:SetAttribute("CampTint",tint) end
		p.Parent=owner
		return p
	end
	local function brace(owner,cf,length)
		return part(owner,"WarmBrace",Vector3.new(length,.5,.35),cf*CFrame.Angles(0,0,math.rad(32)),C.brace)
	end
	local function floor(owner,name,cf,sx,sz,color)
		local p=part(owner,name,Vector3.new(sx,.014,sz),cf,color)
		table.insert(floorMarks,{part=p,y=cf.Y})
		return p
	end
	local function crate(owner,cf,size)
		block(owner,"FeedCrate",cf,0,size/2,0,size,size,size,C.wood,nil,true)
		block(owner,"CrateBand",cf,0,size*.7,0,size+.05,.22,size+.05,C.dark)
		part(owner,"CrateBrace",Vector3.new(size*.94,.22,.13),cf*CFrame.new(0,size/2,size/2+.07)*CFrame.Angles(0,0,math.rad(35)),C.brace)
	end
	local function crates(owner,cf)
		crate(owner,cf*CFrame.new(-1,0,0),1.8)
		crate(owner,cf*CFrame.new(1,0,.25),1.6)
		crate(owner,cf*CFrame.new(-1,1.8,0),1.2)
	end
	local function sacks(owner,cf)
		for i,at in {Vector3.new(-1.2,0,.7),Vector3.new(1.1,0,.65),Vector3.new(0,0,-1.2)} do
			local h=if i==3 then 2.2 else 1.65
			block(owner,"FeedSack",cf,at.X,h/2,at.Z,1.65,h,1.45,C.sack,nil,true)
			block(owner,"FoldedSackTop",cf,at.X,h+.08,at.Z,1.15,.18,.7,C.cream)
		end
	end
	local function roof(owner,cf,y,color)
		-- Native wedges form a shallow gable; complete eaves fit inside 5.8 square.
		for _,side in {-1,1} do
			wedge(owner,"GableRoof",Vector3.new(5.8,1.55,2.9),cf*CFrame.new(side*1.45,y+.775,0)*CFrame.Angles(0,-side*math.pi/2,0),color,"roof")
		end
		block(owner,"RoofRidge",cf,0,y+1.57,0,.32,.25,5.8,C.dark,nil,true)
	end
	local function emblem(owner,cf,kind)
		block(owner,"EmblemBoard",cf,0,0,0,2.5,2.1,.18,C.dark)
		if kind=="bread" then
			block(owner,"BreadCrust",cf,0,0,.16,2.1,.95,.3,C.gold)
			block(owner,"BreadCenter",cf,0,.16,.33,1.9,.55,.08,C.cream)
			for _,x in {-.55,0,.55} do
				part(owner,"BreadCut",Vector3.new(.13,.42,.06),cf*CFrame.new(x,.19,.39)*CFrame.Angles(0,0,math.rad(-22)),C.dark)
			end
		elseif kind=="sail" then
			block(owner,"SailMast",cf,0,0,.16,.18,1.65,.14,C.gold)
			wedge(owner,"LeftSail",Vector3.new(.12,1.15,.8),cf*CFrame.new(-.48,.03,.3)*CFrame.Angles(0,math.pi/2,0),C.cream,nil)
			wedge(owner,"RightSail",Vector3.new(.12,1.45,.8),cf*CFrame.new(.48,.12,.3)*CFrame.Angles(0,-math.pi/2,0),C.cream,nil)
		elseif kind=="bucket" then
			block(owner,"BucketFace",cf,0,0,.19,1.5,1.2,.2,C.pale)
			block(owner,"BucketRim",cf,0,.62,.32,1.85,.25,.16,C.gold)
			block(owner,"BucketHandle",cf,0,.85,.19,.75,.19,.13,C.cream)
		elseif kind=="bolt" then
			for _,v in {Vector3.new(.2,.52,0),Vector3.new(0,0,0),Vector3.new(-.2,-.52,0)} do
				part(owner,"LightningPlate",Vector3.new(.5,.82,.15),cf*CFrame.new(v.X,v.Y,.2)*CFrame.Angles(0,0,math.rad(-24)),C.gold,"accent")
			end
		elseif kind=="crown" then
			block(owner,"CrownBand",cf,0,-.3,.2,1.9,.5,.18,C.gold)
			for _,x in {-.7,0,.7} do block(owner,"CrownPoint",cf,x,.2,.2,.45,if x==0 then 1.15 else .8,.18,C.gold) end
		elseif kind=="dragon" then
			block(owner,"DragonHead",cf,.05,-.05,.2,1.45,.7,.18,t.accent,"accent")
			for _,x in {-.5,.4} do
				part(owner,"DragonHorn",Vector3.new(.3,.75,.18),cf*CFrame.new(x,.48,.2)*CFrame.Angles(0,0,math.rad(-20)),t.accent,"accent")
			end
			block(owner,"DragonEye",cf,.5,.03,.33,.15,.15,.08,C.cream)
		elseif kind=="ice" then
			part(owner,"IceDiamond",Vector3.new(1.05,1.05,.18),cf*CFrame.new(0,0,.2)*CFrame.Angles(0,0,math.pi/4),C.pale)
			block(owner,"IceCut",cf,0,0,.34,.18,1.5,.08,t.accent,"accent")
		elseif kind=="crate" then
			block(owner,"CrateBadge",cf,0,0,.2,1.65,1.35,.18,C.gold)
			block(owner,"CrateBadgeTie",cf,0,0,.32,.25,1.35,.1,C.cream)
		else
			block(owner,"ShieldFace",cf,0,.1,.2,1.5,1.2,.18,C.pale)
			part(owner,"ShieldPoint",Vector3.new(.8,.8,.18),cf*CFrame.new(0,-.45,.2)*CFrame.Angles(0,0,math.pi/4),C.pale)
			block(owner,"ShieldStripe",cf,0,.05,.33,.3,1.25,.08,t.accent,"accent")
		end
	end
	local function hut(owner,cf,height,kind,reinforced)
		local base=if reinforced then 1.5 else .45
		local roofBase=height-1.7
		block(owner,"StuddedFooting",cf,0,base/2,0,5.5,base,5.5,if reinforced then C.stone else C.dark,nil,true)
		for _,x in {-2.25,2.25} do for _,z in {-2.25,2.25} do
			block(owner,"TimberUpright",cf,x,(roofBase+base)/2,z,.65,roofBase-base,.65,C.wood,nil,true)
		end end
		block(owner,"StoreBack",cf,0,base+1.3,-2.35,4.6,2.6,.45,C.wood,nil,true)
		for _,side in {-1,1} do
			block(owner,"StoreSide",cf,side*2.35,base+1,0,.45,2,4.6,if stage==3 then t.accent else C.wood,if stage==3 then "accent" else nil,true)
			brace(owner,cf*CFrame.new(side*1.7,roofBase-.85,2.58)*CFrame.Angles(0,0,if side==1 then math.pi/2 else 0),1.8)
		end
		block(owner,"StoreCounter",cf,0,base+1.6,1.95,4.5,.65,1,C.dark,nil,true)
		if stage==3 then
			block(owner,"WatchDeck",cf,0,6.1,0,5,.45,5,C.pale,nil,true)
			block(owner,"UpperArmor",cf,0,6.95,-2.35,4.6,1.3,.35,t.accent,"accent",true)
			for _,side in {-1,1} do
				block(owner,"UpperArmor",cf,side*2.35,6.95,0,.35,1.3,4.6,t.accent,"accent",true)
				block(owner,"ArmorBolt",cf,side*1.85,7,2.4,.3,.3,.15,C.gold)
			end
		end
		roof(owner,cf,roofBase,t.roof)
		emblem(owner,cf*CFrame.new(0,roofBase-1.35,2.45),kind)
	end
	local function canopy(owner,cf,height)
		block(owner,"ShelterFooting",cf,0,.2,0,5.6,.4,5.2,C.stone,nil,true)
		for _,x in {-2.25,2.25} do for _,z in {-1.9,1.9} do
			block(owner,"CanopyPost",cf,x,height/2,z,.55,height,.55,C.wood,nil,true)
		end end
		block(owner,"CanvasRoof",cf,0,height-.2,0,5.8,.4,5.6,C.cream)
		for _,side in {-1,1} do
			block(owner,"CanvasStripe",cf,side*1.8,height+.02,0,.75,.05,5.6,t.accent,"accent")
			brace(owner,cf*CFrame.new(side*1.8,height-1,2.2)*CFrame.Angles(0,0,if side==1 then math.pi/2 else 0),1.7)
		end
		block(owner,"SupplyCounter",cf,0,2.3,1,4.1,.55,1.6,C.wood,nil,true)
		block(owner,"CounterSupport",cf,0,1.1,1,3.3,2.2,.7,C.dark)
	end
	local boundary=group("LowBoundary")
	for _,x in {-1,1} do for _,z in {-1,1} do
		block(boundary,"CornerFoot",CFrame.new(),x*17.1,.3,z*17.1,1.65,.6,1.65,C.pale,nil,true)
		block(boundary,"CornerPost",CFrame.new(),x*17.1,2.75,z*17.1,1.25,5,1.25,C.wood,nil,true)
	end end
	for quarter=0,3 do
		local q=CFrame.Angles(0,quarter*math.pi/2,0)
		for _,side in {-1,1} do
			block(boundary,"GateShoulder",q,side*7.75,2,17.15,1,4,1,C.wood,nil,true)
			local run=q*CFrame.new(side*12.35,0,17.15)
			if stage==1 then
				block(boundary,"LowerRail",run,0,1,0,8.2,.55,.7,C.wood,nil,true)
			else
				block(boundary,"StoneFooting",run,0,.8,0,8.2,1.5,.8,C.stone,nil,true)
			end
			block(boundary,"TopRail",run,0,2.55,0,8.2,.6,.75,C.wood,nil,true)
			brace(boundary,run*CFrame.new(0,1.75,.55),3.6)
		end
	end
	local markings=group("GroundDetails")
	if not extra then
		floor(markings,"RouteApron",CFrame.new(0,.073,0),14,36,C.cream)
	else
		-- Side compounds read as destinations in grass, never as road crossings.
		floor(markings,"InteriorApron",CFrame.new(0,.073,0),8,7,rgb(159,179,113))
	end
	for _,side in {-1,1} do
		floor(markings,"CornerWear",CFrame.new(side*14.5,.074,side*14.5),4,3,if stage==1 then rgb(180,158,92) else rgb(143,168,112))
	end
	local major,minor=group("MajorLandmark"),group("SecondaryShelter")
	local rearLeft,rearRight=group("LeftSupplies"),group("RightSupplies")
	local a,b=CFrame.new(-14.5,0,-14.5),CFrame.new(14.5,0,-14.5)
	local c,d=CFrame.new(-14.5,0,14.5),CFrame.new(14.5,0,14.5)
	local kind=if extra then extra.symbol elseif stage==1 then "bread" elseif stage==2 then "sail" else "bucket"
	if isSupply then
		canopy(major,a,7.5)
		emblem(major,a*CFrame.new(0,5.7,2.6),"crate")
		-- Low static feed wagon; squared toy wheels fit wholly in its corner bay.
		block(minor,"WagonBed",b,0,1.4,0,4.4,.6,4.4,C.wood,nil,true)
		for _,side in {-1,1} do
			block(minor,"WagonSide",b,side*2,2.3,0,.35,1.3,4.4,C.wood,nil,true)
			for _,z in {-1.45,1.45} do block(minor,"StaticWheel",b,side*2.35,.7,z,.5,1.3,1.3,C.dark) end
		end
		block(minor,"FeedLoad",b,0,2.45,0,3.3,1.4,3.7,C.hay,nil,true)
		crates(rearLeft,c);sacks(rearRight,d)
	else
		local height=if extra then 8.5 elseif stage==1 then 8 elseif stage==2 then 9 else 11
		hut(major,a,height,kind,stage>1)
		if extra and extra.key=="royal" then
			for _,side in {-1,1} do
				block(major,"RoyalCap",a,side*2.25,6.6,2.25,.8,.4,.8,C.gold,nil,true)
				block(major,"RoyalCloth",a,side*1.7,4.4,2.7,.7,2.5,.12,t.accent,"accent")
			end
		elseif extra and extra.key=="iron" then
			for _,side in {-1,1} do
				block(major,"IronBracePanel",a,side*2.6,3.8,0,.2,1.8,2.6,t.accent,"accent",true)
			end
		end
		if stage==1 then
			for _,side in {-1,1} do block(minor,"GrainPenRail",b,side*2,1.2,0,.35,1.7,4.5,C.wood,nil,true) end
			block(minor,"GrainPenBack",b,0,1.2,-2.1,4.5,1.7,.35,C.wood,nil,true)
			block(minor,"CappedHay",b,0,1.25,0,3.4,2.5,3.4,C.hay,nil,true)
			block(minor,"HayTie",b,0,1.27,0,.45,2.6,3.48,C.dark)
			crates(rearLeft,c);sacks(rearRight,d)
		else
			canopy(minor,b,if stage==3 then 8 else 7.5)
			crates(rearLeft,c)
			if not extra and stage==2 then
				crate(rearRight,d*CFrame.new(-.9,0,0),1.8)
				local anchor=d*CFrame.new(1,1.5,.3)*CFrame.Angles(0,0,math.rad(-18))
				block(rearRight,"AnchorStem",anchor,0,0,0,.35,2.5,.4,C.ink)
				block(rearRight,"AnchorArms",anchor,0,-.65,0,2.2,.4,.4,C.ink)
				for _,side in {-1,1} do block(rearRight,"AnchorTip",anchor,side*.95,-.4,0,.35,.75,.4,C.ink) end
				for _,y in {.2,.45,.7} do block(rearRight,"BroadRopeCoil",d,-.7,y,-1.5,1.8,.18,.85,C.sack) end
			elseif not extra and stage==3 then
				block(rearRight,"HelmetRack",d,0,.65,0,3.8,1.3,3.8,C.dark,nil,true)
				block(rearRight,"BucketHelmet",d,0,2.1,0,2.65,1.8,2.65,C.pale,nil,true)
				block(rearRight,"HelmetRim",d,0,1.35,0,3.35,.3,3.35,t.accent,"accent")
				block(rearRight,"HelmetVisor",d,0,2.05,1.36,1.8,.4,.1,C.ink)
			elseif extra and extra.key=="frozen" then
				block(rearRight,"IcePlinth",d,0,.25,0,4.1,.5,3.8,C.stone,nil,true)
				for _,side in {-1,1} do
					part(rearRight,"AngularIce",Vector3.new(1.25,2.25,1.25),d*CFrame.new(side*1,1.6,0)*CFrame.Angles(0,math.pi/4,side*.12),t.accent,"accent")
				end
			elseif extra and extra.key=="thunder" then
				block(rearRight,"CoilFoot",d,0,.35,0,3.3,.7,3.3,C.stone,nil,true)
				block(rearRight,"CoilCore",d,0,1.5,0,1.2,2.2,1.2,C.ink)
				for _,y in {1,1.6,2.2} do block(rearRight,"SquareCoil",d,0,y,0,2.3,.3,2.3,C.gold) end
			else
				sacks(rearRight,d)
			end
		end
	end
	local banner=group("CampPennant")
	block(banner,"FlagPole",CFrame.new(),10,3.5,-12,.35,7,.35,C.wood,nil,true)
	block(banner,"FlagCloth",CFrame.new(),11.6,5.7,-12,3,2,.13,t.accent,"accent")
	block(banner,"FlagBadge",CFrame.new(),11.6,5.7,-11.9,.65,.65,.08,C.cream)
	art.WorldPivot=frame
	art:ScaleTo(edge/18)
	-- Ground thickness is fixed; scaling must not bury the flat markings.
	for _,entry in floorMarks do
		local cf=frame:ToObjectSpace(entry.part.CFrame)
		entry.part.CFrame=frame*CFrame.new(cf.X,entry.y,cf.Z)*cf.Rotation
	end
	return art
end
return Scenery
