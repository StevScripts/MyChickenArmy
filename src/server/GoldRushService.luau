--!strict
-- October 20 Gold Rush (docs/team/GOLD_RUSH_FRIEND_BOOST.md): a server-wide event
-- that multiplies every earned Coin for Config.GoldRush.Seconds out of every
-- EverySeconds. One wall clock for every server, so rushes start at :00, :20 and
-- :40 and server hopping gains nothing. The server owns the state and publishes
-- the current (or next) window in server time as attributes on
-- ReplicatedStorage.PetRoll (GoldRushStartsAt, GoldRushEndsAt); GoldRushController
-- draws the chip, sky and particles from them. PlayerSession:EarnedAmount reads
-- Multiplier(). Offline earnings never include it.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Config=require(ReplicatedStorage.PetRoll.Shared.Config)
local GoldRushService={}

-- One clock per server. Until Start runs (isolated checks, the progression
-- simulation) no rush is active and Multiplier stays 1.
local started,active=false,false
local startsAt,endsAt=0,0
-- A rush started by hand (StartNow); the wall clock resumes after it ends.
local manualStartsAt,manualEndsAt=0,0

-- The scheduled window running at `now` (server time), otherwise the next one.
function GoldRushService.Window(now: number): (number, number)
	local rush=Config.GoldRush
	local start=now-(now-rush.OffsetSeconds)%rush.EverySeconds
	if now>=start+rush.Seconds then start+=rush.EverySeconds end
	return start,start+rush.Seconds
end

-- Coins multiplier for earned sources; 1 between rushes.
function GoldRushService.Multiplier(): number
	return if active then Config.GoldRush.CoinMultiplier else 1
end

function GoldRushService.Active(): boolean
	return active
end

-- Test/admin hook: a rush now for `seconds`; 0 ends a manual rush early.
function GoldRushService.StartNow(seconds: number)
	local now=workspace:GetServerTimeNow()
	if seconds>0 then manualStartsAt,manualEndsAt=now,now+seconds else manualStartsAt,manualEndsAt=0,0 end
end

-- Publishes window changes, and touches every session when a rush starts or ends
-- so income lines and egg values refresh at once.
function GoldRushService.Step(sessions)
	local now=workspace:GetServerTimeNow()
	local from,to=GoldRushService.Window(now)
	if manualEndsAt>now then from,to=manualStartsAt,manualEndsAt end
	if from~=startsAt or to~=endsAt then
		startsAt,endsAt=from,to
		local folder=ReplicatedStorage.PetRoll
		folder:SetAttribute("GoldRushStartsAt",startsAt)
		folder:SetAttribute("GoldRushEndsAt",endsAt)
	end
	local running=now>=from and now<to
	if running==active then return end
	active=running
	for _,session in sessions do session:Touch() end
end

-- GameServer starts the clock once; the connections join its own list.
function GoldRushService.Start(sessions, connections)
	if started or not Config.GoldRush.Enabled then return end
	started=true
	-- Studio playtests: set the server's workspace attribute PetRollGoldRushNow to a
	-- number of seconds (true = one normal rush; false or 0 ends it early).
	if RunService:IsStudio() then
		table.insert(connections,workspace:GetAttributeChangedSignal("PetRollGoldRushNow"):Connect(function()
			local value=workspace:GetAttribute("PetRollGoldRushNow")
			GoldRushService.StartNow(if value==true then Config.GoldRush.Seconds
				elseif type(value)=="number" then math.max(0,value) else 0)
			GoldRushService.Step(sessions)
		end))
	end
	GoldRushService.Step(sessions)
	local nextStepAt=0
	table.insert(connections,RunService.Heartbeat:Connect(function()
		local now=os.clock()
		if now<nextStepAt then return end
		nextStepAt=now+0.25
		GoldRushService.Step(sessions)
	end))
end

return GoldRushService
