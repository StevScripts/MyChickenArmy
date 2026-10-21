-- Restores Stevin's approved sound library (October 21, 2026) from
-- assets/audio/library_20261021.json. Use it only if an unsaved Studio session lost his
-- picks. Studio Edit only: serve this folder on localhost first
--   python3 -m http.server 8765 --bind 127.0.0.1   (run inside assets/audio)
-- then paste this file into the Command Bar. It sets SoundId, Volume, PlaybackSpeed and
-- Looped on each listed Sound (creating any missing one under its folder), marks it
-- OwnerApproved and changes nothing else. Save the place afterwards.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning(), "Run in canonical Edit mode")
local HttpService=game:GetService("HttpService")
local library=game:GetService("SoundService"):WaitForChild("MyChickenArmyAudio")
local data=HttpService:JSONDecode(HttpService:GetAsync("http://127.0.0.1:8765/library_20261021.json"))
local restored,created=0,0
for _,entry in data.sounds do
	local parts=string.split(entry.path,".")
	local parent=library
	for i=1,#parts-1 do
		local child=parent:FindFirstChild(parts[i])
		if not child then child=Instance.new("Folder");child.Name=parts[i];child.Parent=parent end
		parent=child
	end
	local sound=parent:FindFirstChild(parts[#parts])
	if not (sound and sound:IsA("Sound")) then
		sound=Instance.new("Sound");sound.Name=parts[#parts];sound.Parent=parent
		sound:SetAttribute("AudioCue",entry.cue);created+=1
	end
	sound.SoundId=entry.soundId
	sound.Volume=entry.volume
	sound.PlaybackSpeed=entry.speed
	sound.Looped=entry.looped==true
	if entry.playsWhen then sound:SetAttribute("PlaysWhen",entry.playsWhen) end
	sound:SetAttribute("OwnerApproved","2026-10-21")
	restored+=1
end
print(("restore_library_20261021: restored %d sounds (%d re-created). Save the place."):format(restored,created))
