-- October 27 (WS7) server moments (docs/team/SOCIAL_MOMENTS.md): who sees what, the exact
-- copy, the rate limits, the invite gates, and SocialService against a fake server (no
-- remotes, DataStores or live world).
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Catalog=require(Shared.PetCatalog)
local UIColors=require(Shared.UIColors)
local SocialMoments=require(Shared.SocialMoments)
local Session=require(Server.PlayerSession)
local SocialService=require(Server.SocialService)
local PlaytimeService=require(Server.PlaytimeService)
local Checks={}

local function same(shown,chat,toast,beacon,visit,why)
	assert(shown,why..": not shown")
	assert(shown.chat==chat and shown.toast==toast and shown.beacon==beacon and shown.visit==visit,
		why..": got chat="..tostring(shown.chat).." toast="..tostring(shown.toast).." beacon="..tostring(shown.beacon).." visit="..tostring(shown.visit))
end

-- The first rollable chicken of a rarity (with a "1 in X").
local function speciesOf(rarity)
	for _,id in Catalog.Order do
		local definition=Catalog[id]
		if definition.rarity==rarity and definition.oneIn and (definition.weight or 0)>0 then return id end
	end
	for _,id in Catalog.Order do if Catalog[id].rarity==rarity then return id end end
	return nil
end

local function withSocial(patch,fn)
	local saved=Config.Social
	Config.Social=patch
	local ok,why=pcall(fn)
	Config.Social=saved
	if not ok then error(why,0) end
end

local function newSession(id,plot)
	local s=Session.new(id,"Player"..math.abs(id),plot);s.loaded=true
	s.tutorial.guideCompleted=true;s.tutorial.bought=true
	return s
end

-- A fake GameServer: sessions, the ServerMoment remote, analytics, world and army commands.
local function fakeServer()
	local fired,events={},{}
	local remote={FireClient=function(_,player,payload) table.insert(fired,{to=player.UserId,payload=payload}) end}
	local server={sessions={},fired=fired,events=events,
		remotes={FindFirstChild=function(_,name) return if name=="ServerMoment" then remote else nil end},
		analytics={ServerEvent=function(_,_session,name,detail) table.insert(events,name..":"..tostring(detail)) end},
		world={SpawnFrame=function(_,index) return CFrame.new(index*100,5,0) end},
		armyCommands={following={},Release=function(self,session) self.following[session.userId]=nil end}}
	local service=SocialService.new(server)
	service.playerFor=function(userId) return {UserId=userId} end
	return server,service
end

local function character()
	local record={pivots={}}
	local humanoid={Health=100}
	local root={AssemblyLinearVelocity=Vector3.zero,AssemblyAngularVelocity=Vector3.zero,IsA=function(_,class) return class=="BasePart" end}
	record.model={
		FindFirstChildOfClass=function(_,class) return if class=="Humanoid" then humanoid else nil end,
		FindFirstChild=function(_,name) return if name=="HumanoidRootPart" then root else nil end,
		PivotTo=function(_,frame) table.insert(record.pivots,frame) end,
	}
	return record
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,why=pcall(fn)
		table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
		print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
	end

	test("Config.Social is on with the plan's limits",function()
		local settings=SocialMoments.Settings()
		assert(settings.enabled,"Moments off")
		assert(settings.actorGap==45 and settings.serverPerMinute==6 and settings.toastGap==20,"Limits differ")
		assert(settings.chatMin=="Rare" and settings.toastMin=="Epic" and settings.rebirthToastRank==5,"Thresholds differ")
	end)

	test("Finds: Common/Uncommon hidden, Rare chat only, Epic+ toast, beacon and Visit",function()
		assert(SocialMoments.Classify("find",{rarity="Common"})==nil,"Common shown")
		assert(SocialMoments.Classify("find",{rarity="Uncommon"})==nil,"Uncommon shown")
		same(SocialMoments.Classify("find",{rarity="Rare"}),true,false,false,false,"Rare")
		for _,rarity in {"Epic","Legendary","Mythic","Secret"} do
			same(SocialMoments.Classify("find",{rarity=rarity}),true,true,true,true,rarity)
		end
		local rare=speciesOf("Rare")
		same(SocialMoments.Classify("find",{species=rare}),true,false,false,false,"Rare from the catalog")
		assert(SocialMoments.Classify("find",{})==nil,"No chicken shown")
	end)

	test("Camps, the King, Rebirths and the Hill",function()
		assert(SocialMoments.Classify("camp",{campIndex=1})==nil,"Cluck Camp shown")
		same(SocialMoments.Classify("camp",{campIndex=2,camp="Fort Roost"}),true,false,false,false,"Fort Roost")
		same(SocialMoments.Classify("camp",{campIndex=3}),true,false,false,false,"Ironbeak HQ")
		same(SocialMoments.Classify("king",{}),true,true,true,true,"King")
		assert(SocialMoments.Classify("rebirth",{rank=0})==nil,"Rebirth 0 shown")
		same(SocialMoments.Classify("rebirth",{rank=4}),true,false,false,false,"Rebirth 4")
		same(SocialMoments.Classify("rebirth",{rank=5}),true,true,true,false,"Rebirth 5")
		same(SocialMoments.Classify("hill",{}),true,false,false,false,"Hill")
		assert(SocialMoments.Classify("trade",{})==nil,"Unknown kind shown")
	end)

	test("Kill switches: Social or Moments off shows nothing",function()
		withSocial(nil,function() assert(SocialMoments.Classify("king",{})==nil,"No Social block") end)
		local copy=table.clone(Config.Social);copy.Moments=table.clone(copy.Moments);copy.Moments.Enabled=false
		withSocial(copy,function() assert(SocialMoments.Classify("king",{})==nil,"Moments off") end)
		copy=table.clone(Config.Social);copy.Moments=table.clone(copy.Moments);copy.Moments.ToastMinRarity="Legendary"
		withSocial(copy,function()
			same(SocialMoments.Classify("find",{rarity="Epic"}),true,false,false,false,"Epic after the rollback")
			same(SocialMoments.Classify("find",{rarity="Legendary"}),true,true,true,true,"Legendary after the rollback")
		end)
	end)

	test("Copy: exact strings with whole-number odds",function()
		local rare=speciesOf("Rare")
		local odds=Catalog.OneInText(rare)
		assert(odds and string.match(odds,"^1 in [%d,]+$"),"Odds text "..tostring(odds))
		local text=SocialMoments.Text("find",{name="Ana",species=rare})
		assert(text=="Ana found "..Catalog[rare].name.."! "..odds,text)
		local secret=speciesOf("Secret")
		assert(secret,"No Secret chicken")
		local secretText=SocialMoments.Text("find",{name="Ana",species=secret})
		local digits=string.match(secretText,"1 in ([%d,]+)$")
		assert(digits and tonumber((digits:gsub(",","")))>=200000,"Secret odds "..secretText)
		assert(not string.find(secretText,"%.%d"),"Not a whole number: "..secretText)
		assert(SocialMoments.Text("camp",{name="Ana",campIndex=2,camp="Fort Roost"})=="Ana conquered Fort Roost!","Camp")
		assert(SocialMoments.Text("camp",{name="Ana",campIndex=3})=="Ana conquered Ironbeak HQ!","Camp fallback")
		assert(SocialMoments.Text("king",{name="Ana"})=="Ana defeated the Chicken King!","King")
		assert(SocialMoments.Text("rebirth",{name="Ana",rank=7})=="Ana reached Rebirth 7!","Rebirth")
		assert(SocialMoments.Text("hill",{name="Ana"})=="Ana won the Hill!","Hill")
		assert(SocialMoments.VisitText("Ana")=="You're at Ana's base.","Visit")
		for _,line in {text,secretText,SocialMoments.Text("king",{name="Ana"})} do
			for _,banned in {"pet","cash","$","Press E","Tap"} do
				assert(not string.find(string.lower(line),string.lower(banned),1,true),"Banned word "..banned.." in "..line)
			end
		end
	end)

	test("Colours: rarity for finds, gold for the King and Rebirths",function()
		assert(SocialMoments.Color("find",{rarity="Epic"})==UIColors.Rarities.Epic,"Epic")
		assert(SocialMoments.Color("king",{})==UIColors.Coins,"King")
		assert(SocialMoments.Color("rebirth",{rank=5})==UIColors.Coins,"Rebirth")
	end)

	test("Rate limits: 45 s per actor, 6 a minute per server",function()
		local limiter=SocialMoments.Limiter.new()
		assert(limiter:Allow(1,100),"First")
		assert(not limiter:Allow(1,144.9),"Same actor inside 45 s")
		assert(limiter:Allow(1,145),"Same actor after 45 s")
		limiter=SocialMoments.Limiter.new()
		for actor=1,6 do assert(limiter:Allow(actor,200+actor),"Actor "..actor) end
		assert(not limiter:Allow(7,210),"Seventh in a minute")
		assert(limiter:Allow(7,261.5),"After the oldest leaves the minute")
	end)

	test("Client toast gap is 20 s",function()
		assert(SocialMoments.ToastOpen(nil,5),"First toast")
		assert(not SocialMoments.ToastOpen(100,119.9),"Inside the gap")
		assert(SocialMoments.ToastOpen(100,120),"After the gap")
	end)

	test("Tutorial quiet rule facts",function()
		assert(not SocialMoments.TutorialDone({starterArmy=true}),"Fresh tutorial")
		assert(SocialMoments.TutorialDone({starterArmy=true,coreDone=true}),"Core done")
		assert(SocialMoments.TutorialDone({starterArmy=true,guideCompleted=true}),"Guide done")
		assert(SocialMoments.TutorialDone({starterArmy=true,guideSkipped=true}),"Skipped")
		assert(SocialMoments.TutorialDone({}),"Pre-guide save")
		assert(not SocialMoments.TutorialDone(nil),"No tutorial table")
	end)

	test("Invite gates: once, after the tutorial, 240 s in, no friend here",function()
		local facts={tutorialDone=true,sessionSeconds=240,friendBoost=0}
		assert(SocialMoments.InviteDue("Rebirth0",facts),"Due")
		assert(not SocialMoments.InviteDue("Rebirth0",{tutorialDone=true,sessionSeconds=239}),"Too early")
		assert(not SocialMoments.InviteDue("Rebirth0",{tutorialDone=false,sessionSeconds=900}),"In the tutorial")
		assert(not SocialMoments.InviteDue("EpicFind",{tutorialDone=true,sessionSeconds=900,friendBoost=0.1}),"Friend here")
		assert(not SocialMoments.InviteDue("FortRoost",{tutorialDone=true,sessionSeconds=900,invited=true}),"Already invited")
		assert(not SocialMoments.InviteDue("Shop",facts),"Unknown trigger")
	end)

	test("SocialService: a first Epic find reaches everyone else once",function()
		local server,service=fakeServer()
		local actor,other,third=newSession(-701,1),newSession(-702,2),newSession(-703,3)
		third.loaded=false
		server.sessions={[actor.userId]=actor,[other.userId]=other,[third.userId]=third}
		local epic=speciesOf("Epic")
		actor.offers={{id="o1",species=epic}}
		local unseen=service:Unseen(actor,"o1")
		assert(unseen,"Epic counted as already found")
		service:Bought(actor,{offer={species=epic}},unseen)
		assert(#server.fired==1 and server.fired[1].to==other.userId,"Fired "..#server.fired)
		local payload=server.fired[1].payload
		assert(payload.kind=="find" and payload.species==epic and payload.rarity=="Epic" and payload.plotIndex==1,"Payload")
		assert(payload.name==actor.name and payload.userId==actor.userId,"Actor fields")
		assert(table.find(server.events,"social.moment:find"),"social.moment not recorded")
		-- The same chicken again in this visit (or a later find inside 45 s) stays quiet.
		service:Bought(actor,{offer={species=epic}},true)
		assert(#server.fired==1,"Repeat fired")
		-- WS4's receipt wins over the fallback.
		service:Bought(actor,{offer={species=speciesOf("Legendary"),firstFind=false}},true)
		assert(#server.fired==1,"firstFind=false fired")
	end)

	test("SocialService: a Common find, an empty server and Hill participants stay quiet",function()
		local server,service=fakeServer()
		local actor,other=newSession(-711,1),newSession(-712,2)
		server.sessions={[actor.userId]=actor}
		assert(not service:Moment(actor,"king",{}),"Fired into an empty server")
		server.sessions[other.userId]=other
		service:Bought(actor,{offer={species="Duck"}},true)
		assert(#server.fired==0,"Common fired")
		assert(not service:Moment(actor,"hill",{exclude={[other.userId]=true}}),"Participant got the Hill line")
		assert(service:Moment(actor,"hill",{}),"Hill line")
		assert(#server.fired==1,"Hill fired "..#server.fired)
	end)

	test("SocialService: first wins map to camps and the King",function()
		local server,service=fakeServer()
		local actor,other=newSession(-721,1),newSession(-722,2)
		server.sessions={[actor.userId]=actor,[other.userId]=other}
		service:FirstWin(actor,1,false)
		assert(#server.fired==0,"Cluck Camp fired")
		service:FirstWin(actor,2,false)
		assert(#server.fired==1 and server.fired[1].payload.camp=="Fort Roost","Fort Roost")
		service.limiter=SocialMoments.Limiter.new()
		service:FirstWin(actor,nil,true)
		assert(#server.fired==2 and server.fired[2].payload.kind=="king","King")
	end)

	test("SocialService: the invite prompt once per visit, 240 s in",function()
		local server,service=fakeServer()
		local actor=newSession(-731,1)
		server.sessions={[actor.userId]=actor}
		PlaytimeService.Begin(actor,workspace:GetServerTimeNow()-60)
		assert(not service:HighMoment(actor,"Rebirth0"),"Too early")
		actor.playtime=nil
		PlaytimeService.Begin(actor,workspace:GetServerTimeNow()-300)
		assert(service:HighMoment(actor,"Rebirth0"),"Not due")
		assert(service:TakeInvite(actor)=="Rebirth0","Trigger not carried")
		assert(service:TakeInvite(actor)==nil,"Sent twice")
		assert(not service:HighMoment(actor,"EpicFind"),"Second prompt")
		assert(table.find(server.events,"invite.prompt:Rebirth0"),"invite.prompt not recorded")
		local friend=newSession(-732,2);friend.friendBoost=0.1
		PlaytimeService.Begin(friend,workspace:GetServerTimeNow()-300)
		assert(not service:HighMoment(friend,"FortRoost"),"Prompted with a friend here")
	end)

	test("SocialService: Visit checks and the shared GoBase wait",function()
		local server,service=fakeServer()
		local visitor,host=newSession(-741,1),newSession(-742,4)
		server.sessions={[visitor.userId]=visitor,[host.userId]=host}
		local body=character()
		local player={UserId=visitor.userId,Character=body.model}
		local ok,message=service:Visit(player,visitor,2,10)
		assert(not ok and message=="That base is empty.","Empty plot: "..tostring(message))
		ok,message=service:Visit(player,visitor,1,10)
		assert(not ok and message=="That's your own base.","Own plot: "..tostring(message))
		ok,message=service:Visit(player,visitor,99,10)
		assert(not ok and message=="That base is empty.","Out of range")
		visitor.tutorial={starterArmy=true}
		ok,message=service:Visit(player,visitor,4,10)
		assert(not ok and message=="Finish the tutorial first.","Tutorial: "..tostring(message))
		visitor.tutorial={starterArmy=true,guideCompleted=true}
		visitor.lastGoBase=9
		ok,message=service:Visit(player,visitor,4,10)
		assert(not ok and message=="Base teleport ready in 1s.","Shared wait: "..tostring(message))
		server.armyCommands.following[visitor.userId]={}
		ok,message=service:Visit(player,visitor,4,20)
		assert(ok and message=="You're at "..host.name.."'s base.","Visit: "..tostring(message))
		assert(#body.pivots==1 and body.pivots[1].Position==(CFrame.new(400,5,0)*CFrame.new(0,0,6)).Position,"Not at the sign")
		assert(visitor.lastGoBase==20,"GoBase wait not shared")
		assert(server.armyCommands.following[visitor.userId]==nil,"Following army not sent home")
		assert(table.find(server.events,"social.visit:nil"),"social.visit not recorded")
		local copy=table.clone(Config.Social);copy.Visit={Enabled=false}
		withSocial(copy,function()
			local off=service:Visit(player,visitor,4,40)
			assert(not off,"Visit while off")
		end)
	end)

	return results
end

return Checks
