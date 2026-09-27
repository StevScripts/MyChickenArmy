-- Silent isolated checks using a disposable copy of the authored sound library.
local source=game.StarterPlayer.StarterPlayerScripts.PetRoll.AudioController
local Audio=assert(loadstring(source.Source))()
local service=game:GetService("SoundService")
local original=service.MyChickenArmyAudio
local library=original:Clone();library.Name="AudioLibraryCheck";library.Parent=service
local runtime=Instance.new("Folder");runtime.Name="AudioPlaybackCheck";runtime.Parent=service
local tick=library.Fallbacks.Tick.SoundId
local impact=library.Fallbacks.Impact.SoundId
local counts,ids={},{}
for _,item in original:GetDescendants() do
	if item:IsA("Sound") then
		local cue=item:GetAttribute("AudioCue")
		counts[cue]=(counts[cue] or 0)+1;ids[cue]=item.SoundId
	end
end
-- Use bundled clips with muted groups; never preview the user's real music.
for _,item in library:GetDescendants() do
	if item:IsA("Sound") then item.SoundId=tick end
	if item:IsA("SoundGroup") then item.Volume=0 end
end
local audio=Audio.new();audio.folder=runtime;audio.musicEnabled=false
local results={}
local function check(name,ok) assert(ok,name);table.insert(results,name) end
local function loaded(sound)
	local stop=os.clock()+3
	while not sound.IsLoaded and os.clock()<stop do task.wait(0.05) end
	assert(sound.IsLoaded,"Bundled test sound did not load")
end
local ok,err=xpcall(function()
	local total=0
	for _,n in counts do check("unique cue "..tostring(total+1),n==1);total+=n end
	check("all original cues, purchase/error sounds and editable impact fallback are authored",total==18)
	check("original Money ID retained",ids.CashTick=="rbxassetid://6809101819")
	audio:BindLibrary(library)
	check("templates reference authored sounds",audio.templates.Click==library.Interface.Click and audio.templates.CashTick==library.Collection.Money)
	check("music uses disposable playback copy",audio.music~=audio.templates.Music and audio.music.Parent==runtime and audio.templates.Music.Parent==library.Music)
	loaded(audio.templates.Click)
	local first=audio:Play("Click",nil,{cooldown=0})
	check("first voice clones current sound ID",first and first.SoundId==tick and not first:GetAttribute("Fallback"))
	check("effects use local mix without moving source",first.SoundGroup==audio.sfxGroup and audio.templates.Click.Parent==library.Interface)
	first:Destroy()
	library.Interface.Click.SoundId=impact
	loaded(library.Interface.Click)
	local replacement=audio:Play("Click",nil,{cooldown=0})
	check("editing SoundId changes next voice",replacement and replacement.SoundId==impact and not replacement:GetAttribute("Fallback"))
	check("playback never resets edited template",library.Interface.Click.SoundId==impact)
	replacement:Destroy()
	library.Interface.Click.SoundId=""
	check("blank SoundId silences cue without fallback",audio:Play("Click",nil,{cooldown=0})==nil)
	library.Interface.Click.SoundId=tick;loaded(library.Interface.Click)
	library.Interface.Click.Name="My custom click"
	local renamed=audio:Play("Click",nil,{cooldown=0})
	check("display rename preserves AudioCue routing",renamed~=nil and renamed.Name=="My custom click")
	renamed:Destroy()
	audio.templates.Click.PlaybackSpeed=0.8
	local pitched=audio:Play("Click",nil,{cooldown=0})
	check("template speed used when cue has no override",math.abs(pitched.PlaybackSpeed-0.8)<0.001)
	pitched:Destroy()
	local contextual=audio:Play("Click",1.2,{volume=0.07,cooldown=0})
	check("existing contextual pitch and volume retained",math.abs(contextual.PlaybackSpeed-1.2)<0.001 and math.abs(contextual.Volume-0.07)<0.001)
	contextual:Destroy()
	library.Mix.Effects.Volume=0.23;task.wait()
	audio:SetEffects(false)
	check("effects mute only local mix",audio.sfxGroup.Volume==0 and library.Mix.Effects.Volume>0)
	check("muted effects create no voice",audio:Play("Click",nil,{cooldown=0})==nil)
	audio:SetEffects(true)
	check("unmute respects edited group volume",math.abs(audio.sfxGroup.Volume-0.23)<0.001)
	local oldMusic=audio.music
	library.Music.BackgroundMusic.SoundId=impact;task.wait()
	check("music ID edit replaces old voice",oldMusic.Parent==nil and audio.music.SoundId==impact)
	check("music edit respects disabled setting",not audio.music.IsPlaying and not audio.musicEnabled)
	check("authored music never starts playing",not library.Music.BackgroundMusic.IsPlaying)
	library.Music.BackgroundMusic.Volume=0.17;task.wait()
	check("music volume edit reaches playback copy",math.abs(audio.music.Volume-0.17)<0.001)
	local connections=table.clone(audio.connections)
	audio:Destroy()
	check("cleanup preserves authored library",library.Parent==service and library.Collection.Money.Parent==library.Collection)
	check("cleanup removes only playback folder",runtime.Parent==nil and audio.activeCount==0)
	for _,connection in connections do assert(not connection.Connected,"lingering audio binding") end
	check("all change listeners disconnected",#audio.connections==0)
end,debug.traceback)
audio:Destroy();library:Destroy()
assert(ok,err)
return {passed=#results,checks=results}
