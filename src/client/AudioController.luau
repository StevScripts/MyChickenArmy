--!strict
-- Public free Creator Store assets. Preload is bounded to a background task; UI never waits on audio.
-- Native fallback files were verified in installed Roblox / Roblox Studio content/sounds.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local AudioController = {}
AudioController.__index = AudioController

AudioController.Assets = {
	Click = "rbxassetid://82845990304289", -- Free UI glass click, Johnson_BaconMain.
	Collect = "rbxassetid://135483737426662", -- Coin Collect, G00byBBQSauce.
	Pop = "rbxassetid://6586979979", -- cartoon_pop, Schnogrind.
	Victory = "rbxassetid://9044739323", -- Sugar Crash sting, APMOfficial / APM Music.
	Music = "rbxassetid://136012265808588", -- Happy Ukulele Day, DistrokidOfficial.
	-- Free Creator Store / Pro Sound Effects. Individual cues, never a ripped game loop.
	RollLever = "rbxassetid://9120914570", -- Short wood clunk.
	RollTick = "rbxassetid://9119717523", -- Toggle-switch click.
	RollLand = "rbxassetid://9120914570", -- Softer, pitched landing layer.
	RollReveal = "rbxassetid://9126073001", -- Short synth sparkle bell.
	RollRare = "rbxassetid://9126073318", -- Longer sparkle bell for epic+ reveals.
}
local FALLBACK = "rbxasset://sounds/volume_slider.ogg"
local IMPACT = "rbxasset://sounds/action_jump_land.mp3"

function AudioController.new()
	return setmetatable({musicEnabled = true, sfxEnabled = true, templates = {}, last = {}, voices = {}, active = {}, activeCount = 0, alive = true}, AudioController)
end

function AudioController:Start()
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "PetRollAudio", SoundService
	self.folder = folder
	self.musicGroup = Instance.new("SoundGroup")
	self.musicGroup.Name, self.musicGroup.Volume, self.musicGroup.Parent = "Music", 0.13, folder
	self.sfxGroup = Instance.new("SoundGroup")
	self.sfxGroup.Name, self.sfxGroup.Volume, self.sfxGroup.Parent = "Effects", 0.55, folder
	for name, id in AudioController.Assets do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId = name, id
		sound.Volume = if name == "Collect" then 0.55 else 0.4
		sound.SoundGroup = if name == "Music" then self.musicGroup else self.sfxGroup
		sound.Parent = folder
		self.templates[name] = sound
	end
	local impact = Instance.new("Sound")
	impact.Name, impact.SoundId, impact.Volume = "Impact", IMPACT, 0.25
	impact.SoundGroup, impact.Parent = self.sfxGroup, folder
	self.templates.Impact = impact
	local tick = Instance.new("Sound")
	tick.Name, tick.SoundId, tick.Volume = "Tick", FALLBACK, 0.18
	tick.SoundGroup, tick.Parent = self.sfxGroup, folder
	self.templates.Tick = tick
	task.spawn(function()
		local sounds = {}
		for _, sound in self.templates do table.insert(sounds, sound) end
		pcall(function() ContentProvider:PreloadAsync(sounds) end)
		if not self.alive then return end
		for name, sound in self.templates do
			if name ~= "Music" and not sound.IsLoaded then sound.SoundId = FALLBACK end
		end
		local music = self.templates.Music
		music.Looped = true
		if music.IsLoaded and self.musicEnabled then music:Play() end
	end)
end

function AudioController:Play(name, pitch, options)
	if not self.alive or not self.sfxEnabled then return end
	options = options or {}
	local now = os.clock()
	local cooldown = options.cooldown or (if name == "Impact" then 0.12 elseif name == "Collect" then 0.08 else 0.04)
	local key = options.voiceKey or name
	if now - (self.last[key] or -10) < cooldown then return end
	self.last[key] = now
	local template = self.templates[name] or self.templates.Pop
	if not template then return end
	if options.voiceKey then
		local previous = self.voices[key]
		if previous then previous:Destroy() end
	end
	if self.activeCount >= 24 then return end
	local sound = template:Clone()
	if not template.IsLoaded then sound.SoundId = if name == "Impact" then IMPACT else FALLBACK end
	sound.PlaybackSpeed = pitch or 1
	if options.volume then sound.Volume=options.volume end
	if options.parent then
		sound.RollOffMode=Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance,sound.RollOffMaxDistance=8,42
	end
	sound.Parent = options.parent or self.folder
	if options.voiceKey then
		self.voices[key]=sound
	end
	self.active[sound] = true
	self.activeCount += 1
	sound.Destroying:Once(function()
		if self.active[sound] then self.active[sound] = nil;self.activeCount -= 1 end
		if self.voices[key] == sound then self.voices[key] = nil end
	end)
	local function cleanup()
		if self.voices[key]==sound then self.voices[key]=nil end
		sound:Destroy()
	end
	sound.Ended:Once(cleanup)
	sound:Play()
	if options.maxDuration then
		task.delay(math.max(0,options.maxDuration-0.03),function()
			if not sound.Parent then return end
			local fade=TweenService:Create(sound,TweenInfo.new(0.03),{Volume=0})
			fade.Completed:Once(cleanup)
			fade:Play()
		end)
	end
	Debris:AddItem(sound, 7)
end

function AudioController:SetMusic(enabled)
	self.musicEnabled = enabled
	local music = self.templates.Music
	if not music then return end
	if enabled and music.IsLoaded then music:Resume() else music:Pause() end
end

function AudioController:SetEffects(enabled)
	self.sfxEnabled = enabled
	if self.sfxGroup then self.sfxGroup.Volume = if enabled then 0.55 else 0 end
end

function AudioController:Destroy()
	self.alive = false
	for sound in self.active do sound:Destroy() end
	table.clear(self.voices)
	if self.folder then self.folder:Destroy() end
end

return AudioController
