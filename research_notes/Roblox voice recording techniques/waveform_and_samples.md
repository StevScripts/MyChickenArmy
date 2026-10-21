# Waveform visualization and raw-sample access in the Roblox new audio API (as of Oct 20, 2026)

Version baseline: the API dump used below is MaximumADHD Roblox-Client-Tracker `version.txt` = **0.744.0.7441077**, the same major build as the user's Studio 0.744 — [version.txt](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/version.txt); [Full-API-Dump.json](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json). Creator Docs markdown pages were fetched with `last_updated: 2026-10-20`.

## 1. AudioAnalyzer: exact members, update rate, bin layout, mic support

### Takeaway
`AudioAnalyzer` exposes `RmsLevel`, `PeakLevel` (read-only floats, refreshed every audio buffer, no Changed events), `SpectrumEnabled`, `WindowSize: Enum.AudioWindowSize` and `GetSpectrum(): {number}` (RMS levels evenly spaced 0–24,000 Hz). It only works on the client. **`GetSpectrum()` officially returns an empty array if any input is an `AudioDeviceInput`**, so a mic can drive only a loudness (RMS/peak) meter, not a spectrum.

### Cited Findings
- Members in build 0.744: `PeakLevel: float [ReadOnly, NotReplicated]`, `RmsLevel: float [ReadOnly, NotReplicated]`, `SpectrumEnabled: bool`, `WindowSize: AudioWindowSize`, `GetSpectrum(): Array`, `GetConnectedWires(pin: string): Instances`, `GetInputPins()`, `GetOutputPins()`, event `WiringChanged(connected, pin, wire, instance)`. Enum `AudioWindowSize` = `Small(0)`, `Medium(1)`, `Large(2)` — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
- It has one `"Input"` pin and no output pins, so it is a measurement tap. Put it on a branch Wire beside the AudioDeviceOutput path — [AudioAnalyzer.md](https://create.roblox.com/docs/reference/engine/classes/AudioAnalyzer.md)
- Server: "all audio processing is disabled on the server in order to conserve resources; Properties and methods of AudioAnalyzer return empty or zero results when used from server scripts." — [AudioAnalyzer.md](https://create.roblox.com/docs/reference/engine/classes/AudioAnalyzer.md)
- `PeakLevel`: "The loudest volume observed during the last audio buffer. This property changes more often than the framerate and does not fire changed events." `RmsLevel`: root-mean-square average of the last buffer, "generally more stable than PeakLevel but it may not capture momentary volume spikes." Both are `0` on the server — [AudioAnalyzer.md](https://create.roblox.com/docs/reference/engine/classes/AudioAnalyzer.md)
- `SpectrumEnabled`: if `false`, `GetSpectrum()` returns an empty array, but CPU overhead "is dramatically reduced". The docs recommend turning it off when you only need volume — [AudioAnalyzer.md](https://create.roblox.com/docs/reference/engine/classes/AudioAnalyzer.md)
- `WindowSize` "Controls the size of arrays returned by GetSpectrum(). Larger windows contain more data (so more-accurate frequency responses) but change less often." — [AudioAnalyzer.md](https://create.roblox.com/docs/reference/engine/classes/AudioAnalyzer.md)
- `GetSpectrum()`: "Returns the frequency spectrum of the last audio buffer… The elements of the array are root-mean-square volume levels, evenly spaced from 0 hertz to 24,000 hertz. If any of the analyzer's inputs come from an AudioDeviceInput, or this method is used from a server script, it returns an empty array." — [AudioAnalyzer.md](https://create.roblox.com/docs/reference/engine/classes/AudioAnalyzer.md)
- Community history: in April 2024 `GetSpectrum` was "temporarily" disabled for over a month, then partly re-enabled, and "currently doesn't work with AudioDeviceInputs" — [DevForum: How do AudioAnalyzers work? (Apr 2024)](https://devforum.roblox.com/t/how-do-audioanalyzers-work/2909139)
- Nov 2025 feature request "Live Microphone Pitch Access for AudioAnalyzer": the author says `GetSpectrum()` is empty for mic input. A community reply says RMS/Peak "are updated for AudioDeviceInputs". The author agrees they "do update" but give only loudness, not pitch. No staff reply — [DevForum (Nov 12–14, 2025)](https://devforum.roblox.com/t/live-microphone-pitch-access-for-audioanalyzer/4065249)
- June 2024 report: `RmsLevel`/`PeakLevel` always 0 on an `AudioDeviceInput` wired to an analyzer, **from a server script**. The thread closed with no fix — [DevForum (Jun 2024)](https://devforum.roblox.com/t/audioanalyzerrmslevelpeaklevel-is-always-0-when-listening-to-audiodeviceinput/3024582). The zero result matches the documented server-side disable above, not a mic-specific block.

### Inferences
- Spectrum bins spaced evenly to 24 kHz imply a 48 kHz internal sample rate (24 kHz Nyquist). Bin frequency ≈ `(i-1) * 24000 / (#spectrum - 1)` or `/#spectrum`. The docs don't say which, so test it.
- RMS/Peak update once per audio buffer, faster than the frame rate, but a script can only read them once per frame. A RenderStepped poll therefore gives a loudness envelope at about 60 Hz (one value per frame) and drops the values in between. Use `PeakLevel` for spiky "level meter" visuals and `RmsLevel` for smooth bars.
- For the user's goal (mic → visualizer), use a **client LocalScript**: Wire from `Players.LocalPlayer.AudioDeviceInput` (Output pin) → `AudioAnalyzer` (Input pin), `SpectrumEnabled = false`, and poll `RmsLevel` in `RunService.RenderStepped`. A "frequency bars" display for the mic would be faked: an RMS history scrolling across bars, or RMS mapped onto pseudo-bands with noise.

### Gaps
- No source gives the exact `#GetSpectrum()` length for Small/Medium/Large, the buffer size, or the units (linear 0–1 vs dB) of RmsLevel/PeakLevel. To check, print `#analyzer:GetSpectrum()` per WindowSize in a client playtest with an AudioPlayer wired in.
- No official 2026 statement says whether the mic `GetSpectrum` block is a privacy policy or a temporary limit. It is documented behaviour as of Oct 20, 2026.

## 2. Any API for time-domain samples, sample writing, or oscillators/generators?

### Takeaway
There is **no** API to read live PCM samples, write samples, or build audio from a buffer. Build 0.744 has no `EditableAudio`, `AudioBuffer`, oscillator or tone generator. The only time-domain read is `AudioPlayer:GetWaveformAsync(timeRange, samples)` (and the same on `AudioTextToSpeech`). It downsamples a **loaded asset** to values in −1..1 and cannot read a live stream. The only "synthesizer" class is `AudioWindSynthesizer` (wind noise, NotBrowsable). `AudioRecorder` exists but is "in development and is not available yet". Its docs also say that "At this time, AudioDeviceInput cannot be recorded", so it would not capture the mic even once enabled.

### Cited Findings
- Search of the 0.744 dump for classes containing Editable/Oscill/Synth/Generator/Sample found only `EditableImage`, `EditableMesh`, `EditableService`, `AudioWindSynthesizer`, `TextGenerator`, `VideoSampler`. `AssetService` has only `CreateEditableImage*` and `CreateEditableMesh*`, with no audio equivalent — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
- Full list of wirable audio classes in 0.744: AudioAnalyzer, AudioChannelMixer, AudioChannelSplitter, AudioChorus, AudioCompressor, AudioDeviceInput, AudioDeviceOutput, AudioDistortion, AudioEcho, AudioEmitter, AudioEqualizer, AudioFader, AudioFilter, AudioFlanger, AudioGate, AudioLimiter, AudioListener, AudioPitchShifter, AudioPlayer, AudioRecorder (NotBrowsable), AudioReverb, AudioSpeechToText, AudioTextToSpeech, AudioTremolo, AudioWindSynthesizer (NotBrowsable). None generates a periodic tone from parameters — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
- `AudioWindSynthesizer` members: `Enabled`, `PositionInstance`, `PositionType`, `Profile: WindSoundProfile`, `Volume` — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
- `AudioPlayer:GetWaveformAsync(timeRange: NumberRange, samples: int): Array` yields and "Returns a sampling of the waveform data for the loaded Asset, allowing you to check the volume of an asset over its full duration without playing it. Unlike AudioAnalyzer, which measures volume levels of a live audio stream in real time, this method analyzes the asset ahead of time". It returns "A table of `samples` numbers ranging between -1 and 1 … or an empty table if a waveform could not be read." — [AudioPlayer.md](https://create.roblox.com/docs/reference/engine/classes/AudioPlayer.md)
- `AudioTextToSpeech:GetWaveformAsync(timeRange, samples)` returns the same kind of array for generated speech. TTS also has `Pitch` (−12..12 semitones), `Speed` (0.5–2.0), `PlaybackSpeed` (0–20), `Text` (300 chars max), `VoiceId` and `LoadAsync(): AssetFetchStatus`. Rate limit: "1 + (6 * number_of_concurrent_users)" requests/min per experience, plus a "client-side throttle of 4 requests per second per user" — [AudioTextToSpeech.md](https://create.roblox.com/docs/reference/engine/classes/AudioTextToSpeech.md)
- AudioRecorder members in 0.744: `IsRecording`, `TimeLength`, `RecordAsync()` (yields), `Stop()`, `Clear()`, `CanRecordAsync(): bool`, `GetUnrecordableInstancesAsync(): Instances`, `GetTemporaryContent(): Content`. Class tag `NotBrowsable` — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
- AudioRecorder docs: "**This API is in development and is not available yet.**" It records "with a fixed time limit of 60 seconds", and the result can load into an AudioPlayer (sample: `audioPlayer.Asset = audioRecorder:GetTemporaryContent().Uri`). "At this time, AudioDeviceInput cannot be recorded." `RecordAsync` "produces an error" if recording cannot begin — [AudioRecorder.md](https://create.roblox.com/docs/reference/engine/classes/AudioRecorder.md)
- `AudioPlayer` members useful for playback: `Asset: ContentId`, `AudioContent: Content` (hidden; "The audio content to be loaded"), `IsReady`, `TimeLength`, `TimePosition` (seconds, read/write playhead), `PlaybackRegion: NumberRange`, `LoopRegion`, `Looping`, `PlaybackSpeed` (0–20, changes pitch), `Volume` (0–10), `Play(atTime: double?): int64?`, `Stop(atTime?)`, `Cancel(actionId)`, `GetPlaybackState()`. `Play(atTime)` schedules against `SoundService:GetMixerTime()` — [AudioPlayer.md](https://create.roblox.com/docs/reference/engine/classes/AudioPlayer.md); [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
- Other members that look relevant but are not audio sample APIs: `HapticEffect:SetWaveformKeys(keys)` (haptics), `TestService:StartAudioCaptureAsync(artifactName, options)` / `StopAudioCaptureAsync()` (test tooling; security unknown), `Sound:GetUnderlyingAudioPlayer(): AudioPlayer` — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)

### Inferences
- A one-second mic clip **cannot be stored as audio and replayed** in Roblox as of 0.744. No API gives you mic samples, and every replay path (AudioRecorder, buffer-backed Content) is either unavailable or explicitly excludes AudioDeviceInput.
- What can be captured from the mic is a **~60 Hz RMS/Peak envelope** (about 60 numbers per second). Replaying it means using the envelope to drive something else. Examples: `Volume` (and maybe `PlaybackSpeed`) of a looping AudioPlayer holding a cluck, buzz or noise asset, or a TTS/"babble" voice. This gives an "Animal Crossing"-style gibberish echo of the player's speech rhythm, not their voice.
- `GetWaveformAsync` is the right tool to draw the **static waveform of a known asset** (or of a future AudioRecorder clip if `GetTemporaryContent()` loads into an AudioPlayer). It is not for live mic display.

### Gaps
- No source confirms whether `GetWaveformAsync` works on `GetTemporaryContent()` URIs, or what limit applies to `samples`.
- `TestService:StartAudioCaptureAsync` is undocumented in the sources fetched here. It is probably test-harness only and not usable in live games (unverified).
- No public roadmap date for enabling AudioRecorder or lifting the AudioDeviceInput restriction.

## 3. Has anyone resynthesized audio/speech from spectrum data in Roblox? Quality?

### Takeaway
Yes, but only with an **external server doing the analysis**: "Realtime Audio Synth" (Nov 2024) sends dominant frequencies to Roblox and plays them back by additive synthesis. Commenters praised the clarity, but the author reports "warbling" from uncontrolled phase. No code was released. The approach can't be fed from the local mic, because the mic spectrum is blocked; it would work only from AudioPlayer assets or off-platform data.

### Cited Findings
- LividDreaming, "Realtime Audio Synth" (Creations Feedback, Nov 6, 2024): pipeline is to "extract out the important frequencies, and then use additive synthesis on the Roblox side", with analysis done on an external server and playback in real time. The demo was driven by TTS. The author blames the warbling on not controlling each frequency's phase — [DevForum](https://devforum.roblox.com/t/realtime-audio-synth/3249593)
- Feedback: one commenter said they had "never such clear audio like your demo". Suggested fixes were setting phase through `TimePosition`, finer bin size and peak detection to reduce leakage, and tweening per-frequency volumes to stop popping. The author declined to release it, citing abuse risk. Oscillator count, update rate, and Sound vs AudioPlayer were not disclosed — [DevForum](https://devforum.roblox.com/t/realtime-audio-synth/3249593)
- Background on the technique: tools such as the VCV Rack "Kapow" module split audio into up to 256 sine partials plus a noise part — [VCV Community: DanT Kapow](https://community.vcvrack.com/t/dant-kapow/25895)

### Inferences
- The likely Roblox oscillator is N looping AudioPlayers, each holding a pure sine-wave asset. Frequency comes from `PlaybackSpeed` (ratio to the asset's base pitch; 0–20 range limits the span) and amplitude from `Volume` (0–10, tween it to avoid clicks). All are wired into an AudioFader → AudioDeviceOutput. Speech needs dozens of partials updated every 10–20 ms, but script updates are capped at the frame rate. Expect robotic, warbly, sometimes intelligible output at best. Intelligibility depends on frequency resolution and update rate, which Roblox restricts.
- To resynthesize *an asset* in-engine, a script could sample `GetSpectrum()` per frame from an AudioPlayer-fed analyzer. That is a proof of concept only; the real asset is already playable. It is useless for the mic case.

### Gaps
- No public Roblox code for spectrum-to-additive resynthesis was found. No objective quality or intelligibility measurements exist.

## 4. Waveform / level visualizer UI patterns and a playhead over a recorded clip

### Takeaway
Community visualizers use a row of Frame bars and update their `Size` Y-scale every `RenderStepped` from `GetSpectrum()` (resampled to the bar count, `sqrt`-scaled and clamped) or from loudness (`Sound.PlaybackLoudness`, the legacy equivalent of RmsLevel). For a mic, keep a ring buffer of RMS samples and draw a scrolling, mirrored waveform. For a "recorded" clip, store about 60 envelope samples per second, draw them as static bars, and move a playhead Frame by `t / duration`.

### Cited Findings
- April 2024 example (AlureonTime): a LocalScript collects bar Frames sorted by `LayoutOrder`, calls `local spectrum: {number} = audioAnalyzer:GetSpectrum() or {}`, maps the spectrum to the bar count, clamps to 0–1 and sets each bar's height scale in `RenderStepped`. A second version (StrongBigeMan9) maps bins with a power curve plus linear interpolation, applies `sqrt` × multiplier, clamps 0–10 and resizes Parts in a `task.wait()` loop — [DevForum](https://devforum.roblox.com/t/how-do-audioanalyzers-work/2909139)
- Open-source "Audio Visualizer Bars" module: constructor takes a GUI Frame and a bar count, and `Visualizer:LinkToSound(Sound)` hot-swaps sources. It "will automatically determine the sampling rate and bar falloff" — [DevForum](https://devforum.roblox.com/t/audio-visualizer-bars/1032002)
- Legacy loudness-based visualizers use `Sound.PlaybackLoudness` in a LocalScript — [DevForum: How to make audio visualizer](https://devforum.roblox.com/t/how-to-make-audio-visualizer/1607126); [Audio Visualizer Service](https://devforum.roblox.com/t/audio-visualizer-service/750903)
- "Resonance" acoustics library wraps AudioPlayer/AudioEmitter/AudioAnalyzer with optional real-time "peak, RMS, spectrum" analysis — [DevForum](https://devforum.roblox.com/t/resonance-acoustics-library/3924703)
- Static waveforms of assets can come from `GetWaveformAsync` before playback ("suitable for waveform visualization") — [AudioPlayer.md](https://create.roblox.com/docs/reference/engine/classes/AudioPlayer.md)

### Inferences
Illustrative pattern (untested; not from a source):

```lua
-- LocalScript (client only). Live mic level + 1-second "recorded" envelope with playhead.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local mic = Players.LocalPlayer:WaitForChild("AudioDeviceInput") :: AudioDeviceInput
local analyzer = Instance.new("AudioAnalyzer")
analyzer.SpectrumEnabled = false            -- spectrum is empty for mic anyway; saves CPU
analyzer.Parent = mic
local wire = Instance.new("Wire")
wire.SourceInstance = mic                   -- pin "Output"
wire.TargetInstance = analyzer              -- pin "Input"
wire.Parent = analyzer

local BARS = 48
local history = table.create(BARS, 0)       -- ring buffer for scrolling waveform
local head = 0
local bars: {Frame} = {}                    -- pre-created Frames, AnchorPoint (0, 0.5), Position Y 0.5 => mirrored

RunService.RenderStepped:Connect(function()
    local level = math.clamp(analyzer.RmsLevel * 4, 0, 1)   -- gain is a tuning guess
    head = head % BARS + 1
    history[head] = level
    for i = 1, BARS do
        local v = history[(head + i - 1) % BARS + 1]
        bars[i].Size = UDim2.fromScale(bars[i].Size.X.Scale, math.max(v, 0.03))
    end
end)
```

- Recording a 1 s envelope: during capture, append `analyzer.RmsLevel` and `os.clock()` each frame. Afterwards, resample to a fixed bar count (for example 60) by time. On replay, start a timer, set the playhead Frame `Position = UDim2.fromScale(t / 1, 0)` and drive the replay sound's `Volume` from the sample at `t`. Per project rules, a simple playhead sweep could be a single `TweenService` tween of `Position` over 1 s (`Enum.EasingStyle.Linear`).
- Bars should be pre-created once (UIListLayout plus fixed Frames) and only resized each frame. Don't create or destroy instances per frame.
- If the clip ever becomes a real AudioPlayer asset, the playhead fraction is `player.TimePosition / player.TimeLength`, and the static bars come from `player:GetWaveformAsync(NumberRange.new(0, player.TimeLength), BARS)` (take `math.abs` of each −1..1 value for heights).

### Gaps
- No sourced benchmark for the cost of updating ~50–100 Frames per frame. It is assumed cheap.

## 5. Mic prerequisites: voice eligibility, Studio testing, AudioDeviceInput properties

### Takeaway
Mic audio only flows when Roblox's core scripts have set `AudioDeviceInput.Active = true` (scripts can read it but not set it) and `Muted = false`. That happens only for voice-enabled users in an experience whose `VoiceChatService` uses the audio API. `Player` should be set from the server (or set locally only to `LocalPlayer`). `AccessType` plus `SetUserIdAccessList` control who hears it. Official eligibility and Studio-testing rules were not found in primary sources this pass.

### Cited Findings
- `AudioDeviceInput` "produces audio streams from physical devices, such as microphones. It provides a single Output pin" — [AudioDeviceInput.md](https://create.roblox.com/docs/reference/engine/classes/AudioDeviceInput.md)
- `Active`: "Controls whether the physical device is actively recording. This property is only set by Roblox core scripts, but it may be read by user scripts… may only be producing sound if Active is true and Muted is false." — [AudioDeviceInput.md](https://create.roblox.com/docs/reference/engine/classes/AudioDeviceInput.md)
- `Muted`: "Unlike Active, this property is publicly scriptable". Doc push-to-talk sample: `local audioIn: AudioDeviceInput = players.LocalPlayer:WaitForChild("AudioDeviceInput"); audioIn.Muted = true`, toggled on V `InputBegan`/`InputEnded` — [AudioDeviceInput.md](https://create.roblox.com/docs/reference/engine/classes/AudioDeviceInput.md)
- `Player`: "Determines whose device is producing sound… should only be assigned from the server. Assigning this property locally generally does not work, unless Player is Players.LocalPlayer." — [AudioDeviceInput.md](https://create.roblox.com/docs/reference/engine/classes/AudioDeviceInput.md)
- `AccessType: Enum.AccessModifierType` (`Allow` = only listed user IDs hear it; `Deny` = listed IDs are blocked) applies to the list given to `SetUserIdAccessList(userIds: {number})`. It "should only be assigned from the server" — [AudioDeviceInput.md](https://create.roblox.com/docs/reference/engine/classes/AudioDeviceInput.md)
- `IsReady` (read-only): "ready to produce sound, meaning all network connections have been established". `Volume` ranges 0–3 — [AudioDeviceInput.md](https://create.roblox.com/docs/reference/engine/classes/AudioDeviceInput.md)
- Hidden or not-scriptable members in 0.744: `AccessList`, `DictationEnabled`, `EchoCancellation`, `GainControl`, `NoiseSuppression`, `MutedByLocalUser`. `VoiceChatService` exposes `EnableDefaultVoice: bool`, `UseAudioApi: AudioApiRollout`, `DefaultDistanceAttenuation`, `IsVoiceEnabledForUserIdAsync(userId)` — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
- `AudioApiRollout`: `Disabled` (internal hidden voice), `Automatic` (currently same as Disabled), `Enabled` (voice "can be customized or controlled via AudioDeviceInputs") — [robloxapi.github.io (third-party)](https://robloxapi.github.io/ref/enum/AudioApiRollout.html)
- Voice eligibility (13+, phone/ID verification, opt-in) appears only in third-party blogs and is unverified — [noping.com blog](https://noping.com/blog/how-to-enable-voice-chat-in-roblox)

### Inferences
- In a client playtest, check `VoiceChatService:IsVoiceEnabledForUserIdAsync(LocalPlayer.UserId)`, wait for `AudioDeviceInput` under the player, and gate the UI on `Active`/`IsReady`. Show a "voice not available" fallback for the many players without voice (at minimum all under-13 players, if the blog eligibility holds).
- An analyzer tap on the local mic stays local, so it doesn't change who hears the player. To keep the mic private while visualizing, the server could set `AccessType = Allow` with an empty or self-only list (untested).

### Gaps
- No primary source found on whether `AudioDeviceInput` captures the developer's mic in a Studio Play solo test, or which Studio/account settings that needs. Needs a direct test: print `Active`, `IsReady` and `RmsLevel` in a client playtest.
- Official Roblox voice-eligibility policy was not fetched this pass.
