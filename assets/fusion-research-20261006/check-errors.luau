-- Run only through the isolated current-source loader in Studio Edit.
-- Actual controller methods; all collaborators are plain tables. No native UI,
-- audio, remotes, player profiles or input selection are created or changed.
local Client = game.StarterPlayer.StarterPlayerScripts.PetRoll
local App = require(Client.AppController)
local Research = require(Client.ResearchBrowser)
local requirement = "Unlock the Fuse Machine in the skill tree first."
local checks = {}

local function check(name, ok)
	table.insert(checks, {name=name, ok=ok==true})
	assert(ok, name)
end

local function noop() end

local function fake(options)
	options = options or {}
	local log = {notices={}, nodes={}, requests={}, pages={}}
	local app = {
		state={plotIndex=1, mergeUnlocked=false, lastResult=""},
		page="Army", panel={Visible=options.panel==true},
		dialogueActive=options.dialogue==true,
		commerce={cratePresenting=options.crate==true, ReceiveState=noop,
			Receive=function() return options.commerceFeedback==true end},
		research={root={Visible=options.tree==true},
			Receive=function() return options.researchFeedback==true end},
		eggs={Receive=noop}, researchExtras={Receive=noop},
		chickenBrowser={Receive=noop}, mergeBrowser={Receive=noop},
		progression={Receive=noop}, eggBoard={Receive=noop},
		base={RefreshPromptOwnership=noop, UpdateObjective=noop},
		hud={Update=noop}, offlineCash={Receive=noop},
		TrackProductionUpgrade=function() return options.productionFeedback==true, false end,
		Counts=function() return 0, 1, 3, 0, 0 end,
		StepRecruitFeedback=noop, RenderPanel=noop,
	}
	function app:Notify(text, ok)
		table.insert(log.notices, {text=text, ok=ok})
	end
	function app:Request(action)
		table.insert(log.requests, action)
	end
	function app:OpenPage(page)
		table.insert(log.pages, page)
	end
	function app.research:OpenNode(id)
		table.insert(log.nodes, id)
		self.root.Visible = true
	end
	return app, log
end

local direct, directLog = fake()
App.OpenPage(direct, "Merge")
check("locked OpenPage emits exactly one false Notify", #directLog.notices==1
	and directLog.notices[1].ok==false and directLog.notices[1].text==requirement)
check("locked OpenPage focuses FuseMachine", #directLog.nodes==1 and directLog.nodes[1]=="FuseMachine")
check("locked OpenPage never opens Fuse or submits a purchase", direct.page=="Army"
	and direct.panel.Visible==false and #directLog.pages==0 and #directLog.requests==0)

local navigation, activations, purchases = {}, 0, 0
local browser = {
	nodes={FuseMachine={}},
	app={Request=function() purchases+=1 end},
	Open=function() table.insert(navigation, "Open") end,
	Center=function(_, id) table.insert(navigation, "Center:"..id) end,
	Select=function(_, id, persistent)
		table.insert(navigation, "Select:"..id..":"..tostring(persistent))
		-- Deliberately leave selected nil: even on a connected gamepad the actual
		-- OpenNode method cannot write GuiService.SelectedObject in this fixture.
	end,
	Activate=function() activations+=1 end,
}
Research.OpenNode(browser, "FuseMachine")
check("OpenNode opens then centers and persistently selects the requested node",
	table.concat(navigation, "|")=="Open|Center:FuseMachine|Select:FuseMachine:true")
check("OpenNode does not activate research or purchase", activations==0 and purchases==0)
check("OpenNode fixture never supplies a native selected object", browser.selected==nil)

local cases = {
	{name="ordinary locked reply", open=true},
	{name="research feedback in the same packet", researchFeedback=true, open=true},
	{name="all other feedback paths in the same packet", researchFeedback=true,
		productionFeedback=true, commerceFeedback=true, open=true},
	{name="a newer menu", panel=true, researchFeedback=true, open=false},
	{name="an already open research tree", tree=true, researchFeedback=true, open=false},
	{name="a newer dialogue", dialogue=true, researchFeedback=true, open=false},
	{name="a crate presentation", crate=true, researchFeedback=true, open=false},
}
for _, options in cases do
	local app, log = fake(options)
	App.Receive(app, {
		state={plotIndex=1, mergeUnlocked=false, eggs={}, banner="", lastResult=""},
		result={id=1, action="OpenMerge", ok=false, message=requirement},
	})
	check(options.name..": exactly one actionable error", #log.notices==1
		and log.notices[1].ok==false and log.notices[1].text==requirement)
	check(options.name..": navigation respects newer UI", #log.nodes==(if options.open then 1 else 0)
		and (not options.open or log.nodes[1]=="FuseMachine"))
	check(options.name..": no Fuse menu or transaction", #log.pages==0 and #log.requests==0
		and app.page=="Army" and app.panel.Visible==(options.panel==true))
end

return {passed=#checks, checks=checks,
	scope="Actual AppController.OpenPage/Receive and ResearchBrowser.OpenNode with table collaborators; no live UI, remotes, profiles or selection writes",
	limitations="Notify is recorded rather than rendered or played; OpenNode gamepad assignment and actual tree layout are not exercised"}
