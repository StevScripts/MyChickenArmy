-- One-time migration/recovery recipe. Never overwrite an existing sound's ID.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning(), "Expected canonical Edit mode")
local service=game:GetService("SoundService")
local function folder(parent,name)
	local item=parent:FindFirstChild(name)
	if not item then item=Instance.new("Folder"); item.Name=name; item.Parent=parent end
	assert(item:IsA("Folder"),"Expected folder "..name)
	return item
end
local library=folder(service,"MyChickenArmyAudio")
library:SetAttribute("EditingHelp","Change a Sound's SoundId in Edit mode, then save the place. Keep its AudioCue attribute.")
local mix=folder(library,"Mix")
local groups={}
for name,volume in {Music=0.13,Effects=0.55} do
	local group=mix:FindFirstChild(name)
	if not group then group=Instance.new("SoundGroup");group.Name=name;group.Volume=volume;group.Parent=mix end
	assert(group:IsA("SoundGroup"),"Expected SoundGroup "..name)
	groups[name]=group
end
local definitions={
	{"Music","BackgroundMusic","Music","rbxassetid://136012265808588",0.4,"Looping background music; Happy Ukulele Day, DistrokidOfficial."},
	{"Interface","Click","Click","rbxassetid://82845990304289",0.4,"Menu/button click; Johnson_BaconMain UI glass click."},
	{"Interface","Pop","Pop","rbxassetid://6586979979",0.4,"General pop: recruits, egg laying, merges, battle transitions; Schnogrind cartoon_pop."},
	{"Collection","Collect","Collect","rbxassetid://135483737426662",0.55,"Battle coin pickup; G00byBBQSauce Coin Collect."},
	{"Collection","EggPickup","EggPickup","rbxassetid://6586979979",0.4,"Manual and vacuum egg pickup; Schnogrind cartoon_pop."},
	{"Collection","EggDeposit","EggDeposit","rbxassetid://9120914570",0.4,"Egg delivery at the selling stand; short wood contact."},
	{"Collection","Money","CashTick","rbxassetid://6809101819",0.25,"Cash collection and chicken sale confirmation; original authored Money sound."},
	{"Collection","ChickenPurchase","ChickenPurchase","rbxassetid://77584650945481",0.5,"Confirmed chicken purchase; uses the authored volume and playback speed."},
	{"Collection","Error","Error","rbxassetid://87519554692663",0.5,"Failed-action error notifications; uses the authored volume and playback speed."},
	{"Rolling","RollLever","RollLever","rbxassetid://9120914570",0.4,"Roll lever's wood clunk."},
	{"Rolling","RollTick","RollTick","rbxassetid://9119717523",0.4,"Roll shuffle and merge preparation; toggle-switch click."},
	{"Rolling","RollLand","RollLand","rbxassetid://9120914570",0.4,"Podium landing layer; short wood clunk."},
	{"Rolling","RollReveal","RollReveal","rbxassetid://9126073001",0.4,"Normal reveal, upgrades, merges; short synth sparkle bell."},
	{"Rolling","RollRare","RollRare","rbxassetid://9126073318",0.4,"Epic-or-better reveal; longer sparkle bell."},
	{"Combat","Impact","Impact","rbxasset://sounds/action_jump_land.mp3",0.25,"Battle impact; bundled Roblox landing sound."},
	{"Combat","Victory","Victory","rbxassetid://9044739323",0.4,"Capture victory; APMOfficial / APM Music Sugar Crash sting."},
	{"Fallbacks","Tick","Tick","rbxasset://sounds/volume_slider.ogg",0.18,"Quiet fallback while a configured sound loads."},
	{"Fallbacks","Impact","FallbackImpact","rbxasset://sounds/action_jump_land.mp3",0.25,"Fallback while an impact/deposit sound loads."},
}
local results={}
for _,entry in definitions do
	local category,name,cue,id,volume,usage=table.unpack(entry)
	local parent=folder(library,category)
	local sound=parent:FindFirstChild(name)
	if not sound and cue=="CashTick" then
		local assets=game.ReplicatedStorage.PetRoll:FindFirstChild("Assets")
		local old=assets and assets:FindFirstChild("Sounds")
		sound=old and old:FindFirstChild("Money")
	end
	if not sound then
		sound=Instance.new("Sound");sound.Name=name;sound.SoundId=id;sound.Volume=volume
		sound.Looped=cue=="Music"
	end
	assert(sound:IsA("Sound"),"Expected Sound "..name)
	sound:SetAttribute("AudioCue",cue)
	sound:SetAttribute("Usage",usage)
	sound.SoundGroup=if cue=="Music" then groups.Music else groups.Effects
	sound.PlayOnRemove=false
	sound.Parent=parent
	table.insert(results,{cue=cue,path=sound:GetFullName(),id=sound.SoundId})
end
return results
