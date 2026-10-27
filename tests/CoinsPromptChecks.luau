-- October 27 (WS3) Coins-shortfall checkout gate checks (docs/team/COINS_SHORTFALL_PROMPT.md
-- "Gate"): CommerceService:CoinsPromptGate, PreparePurchase's "Shortfall" source and the
-- reply fields GameServer builds from them. Isolated sessions; no Marketplace, prompt or
-- DataStore. Studio: require(game.ServerStorage.PetRollTests.CoinsPromptChecks).Run()
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Commerce=require(Server.CommerceService)
local Session=require(Server.PlayerSession)
local Upgrades=require(Server.UpgradeService)
local Tree=require(Shared.UpgradeCatalog)
local ShopCatalog=require(Shared.ShopCatalog)
local Config=require(Shared.Config)
local Checks={}

local cfg=(Config :: any).CoinsPrompt

-- A fake session: what the gate reads, with steady income stubbed.
local function fake(play: number, rebirths: number, income: number?): any
	local s={tutorial={guideCompleted=true},rebirths=rebirths,playSeconds=play,coins=0,
		passiveEarned=0,battleEarned=0,income=income or 10,crateCredits=0}
	function s:PlaySeconds() return self.playSeconds end
	function s:PackIncome() return self.income end
	return s
end

-- CommerceService without Roblox services: never a test session, always active.
local function service(now: {value: number}): any
	local c=setmetatable({catalog=ShopCatalog,records={},serverNow=function() return now.value end},Commerce)
	c.TestAllowed=function() return false end
	c._Active=function() return true end
	return c
end

local player={UserId=4242}

local function prepare(c: any, s: any, key: string, source: string?, need: number?)
	c.records[player.UserId]={session=s}
	return c:PreparePurchase(player,s,key,true,nil,source,need)
end

function Checks.Run()
	local results={}
	local function test(name: string, fn: () -> ())
		local ok,why=pcall(fn)
		table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
		print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
	end
	local function expect(c: any, s: any, need: number?, now: number, open: boolean, reason: string)
		local gotOpen: any, gotReason: any = c:CoinsPromptGate(s, need, now)
		assert(gotOpen == open and gotReason == reason,
			"gate " .. tostring(gotOpen) .. "/" .. tostring(gotReason) .. ", expected " .. tostring(open) .. "/" .. reason)
	end
	local function withMode(mode: string, fn: () -> ())
		local old=cfg.Mode
		cfg.Mode=mode
		local ok,why=pcall(fn)
		cfg.Mode=old
		if not ok then error(why,0) end
	end

	test("Config.CoinsPrompt is the gate's plan values",function()
		assert(cfg and cfg.Mode=="Gated","Mode")
		assert(cfg.MinPlaySeconds==600 and cfg.MinRebirths==1 and cfg.LegacyEarned==2000,"thresholds")
		assert(cfg.SessionCap==2 and cfg.CooldownSeconds==600,"cap/cooldown")
		assert(cfg.MinShortfallIncomeSeconds==60 and cfg.ShopHintIncomeSeconds==300,"income seconds")
	end)

	test("Tutorial not done holds the checkout back",function()
		local c,s=service({value=1000}),fake(5000,3)
		s.tutorial.guideCompleted=false
		expect(c,s,5000,1000,false,"Tutorial")
	end)

	test("10 minutes of play or Rebirth 1 qualifies",function()
		local c=service({value=1000})
		expect(c,fake(300,0),5000,1000,false,"New")
		expect(c,fake(599,0),5000,1000,false,"New")
		expect(c,fake(600,0),5000,1000,true,"Open")
		expect(c,fake(0,1),5000,1000,true,"Open")
	end)

	test("Two auto-prompts a session, 600 s apart",function()
		local now={value=1000}
		local c,s=service(now),fake(900,0)
		local ok,message,purchase=prepare(c,s,"PocketCoins","Shortfall",5000)
		assert(ok and purchase and purchase.key=="PocketCoins",message)
		assert(s.coinsPromptLog.count==1 and s.coinsPromptLog.readyAt==1600,"log")
		expect(c,s,5000,1599,false,"Cooldown")
		expect(c,s,5000,1600,true,"Open")
		ok,message=prepare(c,s,"PocketCoins","Shortfall",5000)
		assert(not ok and message=="Not enough coins.","cooldown refused at "..now.value)
		now.value=1600
		ok,message=prepare(c,s,"PocketCoins","Shortfall",5000)
		assert(ok,message)
		now.value=5000
		expect(c,s,5000,5000,false,"Cap")
		ok=prepare(c,s,"PocketCoins","Shortfall",5000)
		assert(not ok,"third auto-prompt")
		-- A chosen Shop buy is never gated and never counts.
		ok,message=prepare(c,s,"PocketCoins",nil,nil)
		assert(ok and s.coinsPromptLog.count==2,message)
	end)

	test("Small compares the gap with MinShortfallIncomeSeconds of income",function()
		local c=service({value=1000})
		-- 10 Coins/s: 600 is a minute, 599 is less.
		expect(c,fake(900,0,10),600,1000,true,"Open")
		expect(c,fake(900,0,10),599,1000,false,"Small")
		expect(c,fake(900,0,100),500,1000,false,"Small")
		-- No need given (the snapshot mirror): Small is not checked.
		expect(c,fake(900,0,100),nil,1000,true,"Open")
	end)

	test("Mode Legacy is the October 23 gate: 2,000 Coins earned, no cap",function()
		withMode("Legacy",function()
			local now={value=1000}
			local c,s=service(now),fake(0,0,1000)
			s.passiveEarned=1999
			expect(c,s,1,1000,false,"Tutorial")
			s.passiveEarned=1500;s.battleEarned=500
			expect(c,s,1,1000,true,"Legacy")
			for i=1,5 do
				local ok,message=prepare(c,s,"PocketCoins","Shortfall",1)
				assert(ok,"Legacy prompt "..i..": "..tostring(message))
			end
		end)
	end)

	test("Mode Off never opens a checkout",function()
		withMode("Off",function()
			local c=service({value=1000})
			expect(c,fake(9000,5),5000,1000,false,"Off")
			local ok=prepare(c,fake(9000,5),"PocketCoins","Shortfall",5000)
			assert(not ok,"Off prepared a checkout")
		end)
	end)

	test("A test session is held back last (Test), with the real reason first",function()
		local c=service({value=1000})
		c.TestAllowed=function() return true end
		expect(c,fake(0,0),5000,1000,false,"New")
		expect(c,fake(900,0),5000,1000,false,"Test")
	end)

	test("Shortfall source buys only Coins packs; other sources unchanged",function()
		local c,s=service({value=1000}),fake(900,0)
		s.rebirthSkips=0
		local ok,message=prepare(c,s,"RebirthSkip1","Shortfall",5000)
		assert(not ok and message=="Not enough coins.",message)
		ok,message=prepare(c,s,"CommanderBanner","Shortfall",5000)
		assert(not ok and message=="Not enough coins.",message)
		assert((s.coinsPromptLog or {count=0}).count==0,"refusals counted")
		-- A held-back player can still buy a pack from the Shop.
		local held=fake(0,0)
		ok,message=prepare(c,held,"PocketCoins",nil,nil)
		assert(ok,message)
		ok=prepare(c,held,"PocketCoins","Shortfall",5000)
		assert(not ok,"New player auto-prompt")
	end)

	test("Snapshot mirrors the gate for the client",function()
		local now={value=1000}
		local c,s=service(now),fake(0,0,12)
		s.userId=4242;s.entitlements={};s.commerceAutomatic={};s.researchEffects={};s.luck=1;s.recruitTier=1
		function s:LuckGuarantee() return nil end
		local ok,snap=pcall(function() return c:Snapshot(s) end)
		assert(ok,"Snapshot threw: "..tostring(snap))
		local mirror=snap.coinsPrompt
		assert(type(mirror)=="table" and mirror.eligible==false and mirror.reason=="New","mirror New")
		assert(mirror.income==12 and mirror.minShortfallSeconds==60 and mirror.hintSeconds==300,"mirror income")
		s.playSeconds=600
		local open: any=c:Snapshot(s).coinsPrompt
		assert(open.eligible==true and open.reason=="Open" and open.readyAt==0,"mirror Open")
	end)

	test("A real shortfall: reply fields follow the gate (GameServer's rule)",function()
		local c=service({value=1000})
		local s=Session.new(4242,"Shortfall fixture",1)
		s.loaded=true;s.tutorial.guideCompleted=true;s.coins=0
		local upgrades=Upgrades.new(nil,nil)
		upgrades:BuyNode(s,"Start",0) -- claimed or already owned
		local price=Tree.Price("EggSpeed",1,0)
		local ok,message=upgrades:BuyNode(s,"EggSpeed1",price)
		assert(not ok and message=="Not enough coins." and s.coinShortfall==price,message)
		-- GameServer: shortCoins always, needCoins only when the gate opens.
		local function reply(): any
			local shortCoins=math.ceil(s.coinShortfall)
			local open,reason=c:CoinsPromptGate(s,shortCoins,1000)
			return {shortCoins=shortCoins,needCoins=if open then shortCoins else nil,coinsGate=reason}
		end
		s.playSeconds=0
		local held=reply()
		assert(held.shortCoins==price and held.needCoins==nil and held.coinsGate=="New",tostring(held.coinsGate))
		s.playSeconds=100000
		local opened=reply()
		-- The fresh profile earns nothing yet, so any gap is over a minute of income.
		assert(opened.needCoins==price and opened.coinsGate=="Open",tostring(opened.coinsGate))
	end)

	test("Analytics: shortfalls, held-back reasons, auto-prompts and quit60",function()
		local Ledger=require(Server.AnalyticsLedger)
		local Analytics=require(Server.Analytics)
		local Report=require(Server.AnalyticsReport)
		local function store()
			local data={}
			local fake={data=data}
			function fake:GetAsync(key) return data[key] end
			function fake:SetAsync(key,value) data[key]=value end
			function fake:UpdateAsync(key,fn) local value=fn(data[key]); if value~=nil then data[key]=value end; return value end
			return fake
		end
		local clock=100
		local ledger=Ledger.new({store=store(),playerStore=store(),studio=true,shard=0,version="v1",
			clock=function() return 1791547200 end})
		local analytics=Analytics.new({ledger=ledger,studio=true,clock=function() return clock end,
			wall=function() return 1791547200 end,sender=function() end,random=function() return 1 end})
		local session={userId=91,tutorial={guideCompleted=true},firstWins={},coins=0,pets={},offers={},upgradeTree={},rebirths=0}
		function session:Count() return 0 end
		function session:CanSpendCash(amount) return amount<=self.coins end
		analytics:Join({UserId=91},session);analytics:Loaded(session);task.wait()
		analytics:CoinsShortfall(session,"Buy","New",500)
		analytics:CoinsShortfall(session,"FeedChicken","Open",900)
		analytics:ClientEvents(session,{{n="coins.gated",d="Tree:Cooldown"},{n="coins.gated",d="Buy:Busy"},{n="coins.gated",d="Board:Open"}})
		analytics:Action(session,"PreparePurchase",true,"",0,{key="PocketCoins",source="Shortfall"},{})
		clock+=5
		analytics:Action(session,"RefreshShop",true,"",0,{},{})
		clock+=30
		analytics:Leave(session);task.wait()
		local c=ledger.pending["2026-10-09"]["v1"].c
		assert(c["shop.short.Buy"]==1 and c["shop.short.UpgradeChicken"]==1,"server shortfalls")
		assert(c["shop.short.Tree"]==1 and c["shop.short.Board"]==1,"client pre-check shortfalls")
		assert(c["shop.auto.gated.New"]==1 and c["shop.auto.gated.Cooldown"]==1 and c["shop.auto.gated.Busy"]==1,"held-back reasons")
		assert(c["shop.auto.gated.Open"]==nil,"Open is not held back")
		assert(c["shop.auto.prompt"]==1 and c["shop.auto.prompt.PocketCoins"]==1 and c["shop.prompt.PocketCoins"]==1,"auto-prompt")
		assert(c["shop.auto.quit60"]==1 and c["shop.intent.quit60"]==nil,"quit within 60 s of a cancel")
		local bucket=ledger.pending["2026-10-09"]["v1"]
		local summary=Report.Summarize({["2026-10-09"]={v={v1=bucket},shards=1,source="shards"}})
		local section=summary.coinsPrompt
		assert(section and section.autoPrompts==1 and section.intentPrompts==0 and section.auto.quit60==1,"report section")
		assert(section.gated.New==1 and section.shortfalls.Tree==1,"report counts")
	end)

	return results
end

return Checks
