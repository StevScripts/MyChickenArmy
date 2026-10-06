--!strict
-- Pure research rules and save validation. Transactions belong to ResearchService.
local Catalog=require(script.Parent.ResearchCatalog)
local Rules={}
local function integer(n,low,high)
	return type(n)=="number" and n==n and n>=low and n<=high and n%1==0
end
local function shortString(value,limit)
	return type(value)=="string" and #value>0 and #value<=limit and utf8.len(value)~=nil
end

function Rules.New()
	return {completed={Start=true},jobs={},revision=0,pinned=nil,rallyReadyAt=0,formations={},operationWins={},pendingOperationReward=0,eggValueRemainder=0}
end

function Rules.Effects(research)
	local result={damage=0,health=0,march=0,armor=0,recovery=0,bossDamage=0,rallySeconds=0,callArmy=0,fusion=0,
		production=0,eggValue=0,pickupStuds=0,bounty=0,offlineHours=8,rollingLuck=0,rollingSpeed=0,speed=0,slots=1,capture=0,walk=0,formations=0,operations=0}
	for id,owned in (research and research.completed) or {} do
		local node=Catalog.Nodes[id]
		if owned and node and node.effect then result[node.effect]=math.max(result[node.effect] or 0,node.value) end
	end
	return result
end

function Rules.Duration(node,effects)
	return math.max(1,math.ceil(node.duration/(1+effects.speed)))
end

function Rules.Job(research,nodeId)
	for _,job in research.jobs do if job.nodeId==nodeId then return job end end
	return nil
end

function Rules.Status(research,nodeId,coins)
	local node=Catalog.Nodes[nodeId]
	if not node then return "Unknown" end
	if research.completed[nodeId] then return "Completed" end
	if Rules.Job(research,nodeId) then return "Researching" end
	if not research.completed[node.prerequisite] then return "Locked" end
	return if coins>=node.price then "Available" else "Unaffordable"
end

function Rules.Copy(research)
	local result=table.clone(research)
	result.completed=table.clone(research.completed)
	result.jobs={};for _,job in research.jobs do table.insert(result.jobs,table.clone(job)) end
	result.formations={};for slot,preset in research.formations do result.formations[slot]={name=preset.name,petIds=table.clone(preset.petIds)} end
	result.operationWins=table.clone(research.operationWins)
	return result
end

function Rules.Read(value)
	if value==nil then return Rules.New() end
	if type(value)~="table" or type(value.completed)~="table" or type(value.jobs)~="table"
		or not integer(value.revision,0,2^53-1) or not integer(value.rallyReadyAt or 0,0,2^53-1) then return nil end
	local result=Rules.New();result.revision=value.revision;result.rallyReadyAt=value.rallyReadyAt or 0
	local count=0
	for id,owned in value.completed do
		count+=1
		if count>#Catalog.Order or type(id)~="string" or not Catalog.Nodes[id] or owned~=true then return nil end
		result.completed[id]=true
	end
	for id in result.completed do local node=Catalog.Nodes[id];if node.prerequisite and not result.completed[node.prerequisite] then return nil end end
	local jobIds,nodeIds={},{};count=0
	for index,job in value.jobs do
		count+=1
		if count>Catalog.MaxJobs or not integer(index,1,#value.jobs) or type(job)~="table"
			or not shortString(job.id,64) or jobIds[job.id] or type(job.nodeId)~="string" then return nil end
		local node=Catalog.Nodes[job.nodeId]
		if not node or job.nodeId=="Start" or nodeIds[job.nodeId] or result.completed[job.nodeId]
			or not result.completed[node.prerequisite] or not integer(job.startedAt,0,2^53-1)
			or not integer(job.finishAt,job.startedAt+1,2^53-1) or not integer(job.paid,0,1e12) then return nil end
		jobIds[job.id],nodeIds[job.nodeId]=true,true
		result.jobs[index]={id=job.id,nodeId=job.nodeId,startedAt=job.startedAt,finishAt=job.finishAt,paid=job.paid}
	end
	if count~=#value.jobs or count>Rules.Effects(result).slots then return nil end
	if value.pinned~=nil and (type(value.pinned)~="string" or not Catalog.Nodes[value.pinned]) then return nil end
	result.pinned=value.pinned
	local remainder=value.eggValueRemainder or 0
	if type(remainder)~="number" or remainder~=remainder or remainder<0 or remainder>=1 then return nil end
	result.eggValueRemainder=remainder
	if not integer(value.pendingOperationReward or 0,0,2^53-1) then return nil end
	result.pendingOperationReward=value.pendingOperationReward or 0
	if value.formations~=nil then
		if type(value.formations)~="table" then return nil end
		count=0
		for slot,preset in value.formations do
			count+=1
			-- String slots round-trip as dictionary keys through DataStore JSON.
			if count>3 or type(slot)~="string" or not table.find({"1","2","3"},slot)
				or type(preset)~="table" or not shortString(preset.name,40) or type(preset.petIds)~="table" then return nil end
			local ids,seen,entries={},{},0
			for index,id in preset.petIds do
				entries+=1
				if entries>15 or not integer(index,1,#preset.petIds) or not shortString(id,64) or seen[id] then return nil end
				ids[index]=id;seen[id]=true
			end
			if entries~=#preset.petIds then return nil end
			result.formations[slot]={name=preset.name,petIds=ids}
		end
	end
	if value.operationWins~=nil then
		if type(value.operationWins)~="table" then return nil end
		count=0
		for id,won in value.operationWins do
			count+=1
			if count>9 or type(id)~="string" or not string.match(id,"^[123]:[123]$") or won~=true then return nil end
			result.operationWins[id]=true
		end
	end
	return result
end

return Rules
