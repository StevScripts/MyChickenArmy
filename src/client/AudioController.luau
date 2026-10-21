--!strict
-- Edit sound IDs in SoundService.MyChickenArmyAudio, not in scripts.
-- Authored templates survive cleanup; only local playback copies are disposable.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local AudioController = {}
AudioController.__index = AudioController
local LIBRARY_NAME = "MyChickenArmyAudio"

function AudioController.new()
	return setmetatable({musicEnabled = true, sfxEnabled = true, templates = {}, last = {}, voices = {}, pools = {}, fallbackCounts = {}, active = {}, activeCount = 0, alive = true, connections = {}, revisions = {}}, AudioController)
end

function AudioController:Prepare(name, template)
	local revision = (self.revisions[name] or 0) + 1
	self.revisions[name] = revision
	if name == "Music" then
		if self.music then self.music:Destroy() end
		local music = template:Clone()
		music:Stop()
		music.SoundGroup, music.Parent = self.musicGroup, self.folder
		self.music = music
	end
	if template.SoundId == "" then return end
	-- Each cue loads independently. Late completion cannot restart an older track.
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({template}) end)
		if not self.alive or self.revisions[name] ~= revision then return end
		if name == "Music" then self:SetMusic(self.musicEnabled) end
	end)
end

function AudioController:BindLibrary(library)
	local mix = library:FindFirstChild("Mix")
	local musicGroup = mix and mix:FindFirstChild("Music")
	local effectsGroup = mix and mix:FindFirstChild("Effects")
	if not musicGroup or not musicGroup:IsA("SoundGroup") or not effectsGroup or not effectsGroup:IsA("SoundGroup") then
		warn("My Chicken Army audio is missing its SoundService Mix groups.")
		return
	end
	self.musicGroup, self.sfxGroup = musicGroup:Clone(), effectsGroup:Clone()
	self.musicGroup.Parent, self.sfxGroup.Parent = self.folder, self.folder
	local function applyMix()
		self.musicGroup.Volume = musicGroup.Volume
		self.effectsVolume = effectsGroup.Volume
		self.sfxGroup.Volume = if self.sfxEnabled then self.effectsVolume else 0
	end
	applyMix()
	table.insert(self.connections, musicGroup:GetPropertyChangedSignal("Volume"):Connect(applyMix))
	table.insert(self.connections, effectsGroup:GetPropertyChangedSignal("Volume"):Connect(applyMix))
	for _,template in library:GetDescendants() do
		if not template:IsA("Sound") then continue end
		local name = template:GetAttribute("AudioCue") or template.Name
		if type(name) ~= "string" or self.templates[name] then
			warn("Duplicate or invalid audio cue: "..template:GetFullName())
			continue
		end
		self.templates[name] = template
		table.insert(self.connections, template:GetPropertyChangedSignal("SoundId"):Connect(function()
			self:Prepare(name, template)
		end))
		if name == "Music" then
			for _,property in {"Volume", "PlaybackSpeed", "Looped"} do
				table.insert(self.connections, template:GetPropertyChangedSignal(property):Connect(function()
					if self.music then self.music[property] = template[property] end
				end))
			end
		end
		self:Prepare(name, template)
	end
end

function AudioController:Start()
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "PetRollAudio", SoundService
	folder:SetAttribute("EditingHelp", "Temporary playback copies. Edit MyChickenArmyAudio instead.")
	self.folder = folder
	-- Library replication/loading never blocks the UI startup path.
	task.spawn(function()
		local library = SoundService:WaitForChild(LIBRARY_NAME, 10)
		if not self.alive then return end
		if not library then warn("Missing SoundService."..LIBRARY_NAME.." audio library."); return end
		self:BindLibrary(library)
	end)
end

function AudioController:FadeVoice(sound)
	if not sound or not sound.Parent or sound:GetAttribute("Fading") then return end
	sound:SetAttribute("Fading", true)
	local fade = TweenService:Create(sound, TweenInfo.new(0.04), {Volume=0})
	fade.Completed:Once(function() sound:Destroy();fade:Destroy() end)
	fade:Play()
end

function AudioController:BindUI(root)
	if self.uiBindings then return end
	self.uiBindings={}
	local function remove(button)
		if not self.uiBindings then return end
		local bindings=self.uiBindings[button]
		if bindings then for _,connection in bindings do connection:Disconnect() end;self.uiBindings[button]=nil end
	end
	local function bind(button)
		if not self.uiBindings or not button:IsA("GuiButton") or self.uiBindings[button] then return end
		local function hover()
			if not button.Active or not button.Selectable or not button:IsDescendantOf(root) then return end
			local cue,ancestor=nil,button
			while ancestor do
				if ancestor:IsA("GuiObject") and not ancestor.Visible then return end
				if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return end
				cue=cue or ancestor:GetAttribute("HoverAudioCue")
				if ancestor==root then break end
				ancestor=ancestor.Parent
			end
			self:Play(if type(cue)=="string" then cue else "UIHover",nil,{noFallback=true,voiceKey="UIHover",cooldown=.075,maxDuration=.5})
		end
		self.uiBindings[button]={button.MouseEnter:Connect(hover),button.SelectionGained:Connect(hover)}
	end
	for _,item in root:GetDescendants() do bind(item) end
	table.insert(self.connections,root.DescendantAdded:Connect(bind))
	table.insert(self.connections,root.DescendantRemoving:Connect(remove))
end

-- October 21 game feel: whether an authored cue exists with a SoundId, so callers can
-- pick a fallback cue themselves instead of relying on the generic Pop.
function AudioController:Has(name)
	local template = self.templates[name]
	return template ~= nil and template.SoundId ~= ""
end

-- Play `name` when it is authored, else `fallback` (nil fallback = silence). Never the
-- generic Pop: a cue that is not in the library yet should stay quiet, not click.
function AudioController:Cue(name, fallback, pitch, options)
	local merged = table.clone(options or {})
	if merged.noFallback == nil then merged.noFallback = true end
	local chosen = if self:Has(name) then name else fallback
	if not chosen then return nil end
	return self:Play(chosen, pitch, merged)
end

-- A positioned one-shot (8–42 stud roll-off) at a world point: a transient
-- attachment under Terrain carries the voice and is swept up after it ends.
function AudioController:PlayAt(name, position, pitch, options)
	if not self.alive or not self.sfxEnabled then return end
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.WorldPosition = "PetRollAudioPoint", position
	attachment.Parent = workspace.Terrain
	local merged = table.clone(options or {})
	merged.parent = attachment
	local sound = self:Play(name, pitch, merged)
	if not sound then attachment:Destroy(); return nil end
	sound.Destroying:Once(function() attachment:Destroy() end)
	Debris:AddItem(attachment, 8)
	return sound
end

-- VFX templates are optional and never fall back to UI clicks. Reuse each
-- spatial loop; changes to its authored ID replace only that playback copy.
function AudioController:VFXLoop(name, parent, current)
	local template=self.templates[name]
	local enabled=self.alive and self.sfxEnabled and template and template.SoundId~="" and parent and parent.Parent
	if current and (not enabled or not current.Parent or current.SoundId~=template.SoundId) then
		current:Destroy();current=nil
	end
	if not enabled then return nil end
	if current then
		current.Volume,current.PlaybackSpeed=template.Volume,template.PlaybackSpeed
		return current
	end
	return self:Play(name,nil,{parent=parent,looped=true,noFallback=true})
end

function AudioController:Play(name, pitch, options)
	if not self.alive or not self.sfxEnabled then return end
	options = options or {}
	local now = os.clock()
	local cooldown = options.cooldown or (if name == "Impact" then 0.12 elseif name == "Collect" then 0.08 else 0.04)
	local key = options.voiceKey or name
	if now - (self.last[key] or -10) < cooldown then return end
	local template = self.templates[name] or (if not options.noFallback then self.templates.Pop else nil)
	if not template or template.SoundId == "" then return end
	if self.activeCount >= 24 then return end
	-- Reserve voices for gameplay feedback even in a flock of noisy chickens.
	if options.looped then
		local loops=0
		for sound in self.active do if sound.Looped then loops+=1 end end
		if loops>=8 then return end
	end
	self.last[key] = now
	local pool
	if options.maxVoices then
		pool = self.pools[key] or {}
		self.pools[key] = pool
		while #pool >= math.max(1, options.maxVoices) do self:FadeVoice(table.remove(pool, 1)) end
	elseif options.voiceKey then
		local previous = self.voices[key]
		if previous then previous:Destroy() end
	end
	local sound = template:Clone()
	local fallbackUsed = false
	if not template.IsLoaded and not options.noFallback then
		local fallback = self.templates[if name == "Impact" or name == "EggDeposit" then "FallbackImpact" else "Tick"]
		if fallback and fallback.SoundId ~= "" then
			sound.SoundId = fallback.SoundId
			fallbackUsed = true
			self.fallbackCounts[name] = (self.fallbackCounts[name] or 0) + 1
		end
	end
	sound:SetAttribute("Fallback", fallbackUsed)
	sound.SoundGroup, sound.Looped, sound.PlayOnRemove = self.sfxGroup, options.looped==true, false
	sound.PlaybackSpeed = pitch or template.PlaybackSpeed
	-- October 21 game feel: a little random pitch so repeated cues (clucks, ticks,
	-- pickups) never sound like one sample on a loop.
	if options.pitchVariance then sound.PlaybackSpeed *= 1 + (math.random() * 2 - 1) * options.pitchVariance end
	if options.volume then sound.Volume=options.volume end
	if options.parent then
		sound.RollOffMode=Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance,sound.RollOffMaxDistance=8,42
	end
	sound.Parent = options.parent or self.folder
	if pool then table.insert(pool, sound)
	elseif options.voiceKey then
		self.voices[key]=sound
	end
	self.active[sound] = true
	self.activeCount += 1
	sound.Destroying:Once(function()
		if self.active[sound] then self.active[sound] = nil;self.activeCount -= 1 end
		if self.voices[key] == sound then self.voices[key] = nil end
		if pool then local index=table.find(pool,sound);if index then table.remove(pool,index) end end
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
			self:FadeVoice(sound)
		end)
	end
	if not options.looped then Debris:AddItem(sound, 7) end
	return sound
end

function AudioController:SetMusic(enabled)
	self.musicEnabled = enabled
	local music = self.music
	if not music then return end
	-- The intro cutscene holds the loop while it plays its own score.
	if enabled and music.IsLoaded and not self.musicHold then
		if music.IsPaused then music:Resume() elseif not music.IsPlaying then music:Play() end
	else music:Pause() end
end

function AudioController:SetEffects(enabled)
	self.sfxEnabled = enabled
	if self.sfxGroup then self.sfxGroup.Volume = if enabled then self.effectsVolume else 0 end
end

function AudioController:Destroy()
	self.alive = false
	for _,bindings in self.uiBindings or {} do for _,connection in bindings do connection:Disconnect() end end
	self.uiBindings=nil
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for sound in self.active do sound:Destroy() end
	table.clear(self.voices)
	table.clear(self.pools)
	table.clear(self.templates)
	if self.folder then self.folder:Destroy() end
end

return AudioController
