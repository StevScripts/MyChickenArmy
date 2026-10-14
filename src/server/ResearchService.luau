--!strict
-- Non-yielding cash/job transactions. PlayerSession owns the saved research value.
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.ResearchCatalog)
local Rules=require(Shared.ResearchRules)
local Currency=require(Shared.CurrencyLimits)
local Service={}

function Service.Complete(session,now)
	local research=session.research;local completed={}
	for i=#research.jobs,1,-1 do
		local job=research.jobs[i]
		if job.finishAt<=now then
			if not research.completed[job.nodeId] then
				research.completed[job.nodeId]=true;table.insert(completed,job.nodeId)
			end
			table.remove(research.jobs,i);research.revision+=1
		end
	end
	if #completed>0 then
		session.researchEffects=Rules.Effects(research)
		session.researchRecap=session.researchRecap or {}
		for _,id in completed do table.insert(session.researchRecap,id) end
		session:Touch()
	end
	return completed
end

function Service.Start(session,nodeId,expectedRevision,expectedPrice,expectedDuration,now)
	Service.Complete(session,now)
	local research=session.research
	if expectedRevision~=research.revision then return false,"Research changed. Choose the node again." end
	local node=if type(nodeId)=="string" then Catalog.Nodes[nodeId] else nil
	if not node or nodeId=="Start" then return false,"Choose a research node." end
	local status=Rules.Status(research,nodeId,session.coins)
	if status=="Completed" then return false,"Research already completed." end
	if status=="Researching" then return false,"This research is already running." end
	if status=="Locked" then return false,"Complete "..Catalog.Nodes[node.prerequisite].name.." first." end
	if status=="Unaffordable" then return false,"Not enough cash for this research." end
	local effects=session.researchEffects or Rules.Effects(research)
	local duration=Rules.Duration(node,effects)
	if expectedPrice~=node.price or expectedDuration~=duration then return false,"The research quote changed." end
	if #research.jobs>=effects.slots then return false,"All researchers are busy." end
	local canSpend,reason=session:CanSpendCash(node.price)
	if not canSpend then return false,reason end
	local job={id=HttpService:GenerateGUID(false),nodeId=nodeId,startedAt=now,finishAt=now+duration,paid=node.price}
	session.coins-=node.price;table.insert(research.jobs,job);research.revision+=1;session:Touch()
	return true,node.name.." research started.",job.id
end

function Service.Cancel(session,jobId,expectedRevision,now)
	Service.Complete(session,now)
	local research=session.research
	if type(jobId)~="string" or #jobId>64 or research.revision~=expectedRevision then return false,"Research changed. Choose the job again." end
	for index,job in research.jobs do if job.id==jobId then
		if job.paid>Currency.MaxCoins-session.coins then return false,"Spend some cash before receiving this refund." end
		-- Refund exactly the original debit, with no earned-cash multipliers.
		session.coins+=job.paid;table.remove(research.jobs,index);research.revision+=1;session:Touch()
		return true,"Research cancelled; cash refunded."
	end end
	return false,"This research job has already finished or been cancelled."
end

-- Studio/admin only (GameServer checks access): finishes a running job now. The
-- original payment stays spent, exactly as if the timer had run out.
function Service.Skip(session,jobId,expectedRevision,now)
	Service.Complete(session,now)
	local research=session.research
	if type(jobId)~="string" or #jobId>64 or research.revision~=expectedRevision then return false,"Research changed. Choose the job again." end
	for _,job in research.jobs do if job.id==jobId then
		job.finishAt=now
		local node=Catalog.Nodes[job.nodeId]
		Service.Complete(session,now)
		return true,(if node then node.name else "Research").." finished."
	end end
	return false,"This research job has already finished or been cancelled."
end

function Service.Pin(session,nodeId)
	if nodeId~=nil and (type(nodeId)~="string" or not Catalog.Nodes[nodeId]) then return false,"Choose a research goal." end
	session.research.pinned=nodeId;session:Touch();return true,if nodeId then "Research goal pinned." else "Research goal cleared."
end

function Service.Snapshot(session,now)
	local data=Rules.Copy(session.research)
	data.rallyActiveUntil=session.rallyActiveUntil or 0
	data.serverTime=now;data.effects=table.clone(session.researchEffects or Rules.Effects(data))
	data.offers={}
	for _,id in Catalog.Order do local node=Catalog.Nodes[id]
		local status=Rules.Status(data,id,session.coins)
		local canSpend,reason=session:CanSpendCash(node.price)
		if status=="Available" and not canSpend then status="Unaffordable" end
		data.offers[id]={status=status,price=node.price,duration=Rules.Duration(node,data.effects),spendReason=reason}
	end
	data.recap=table.clone(session.researchRecap or {})
	return data
end

return Service
