# AudioRecorder rollout status and official audio capture/replay APIs (as of October 20, 2026)

Research date: 2026-10-20. Engine version cross-checked: the MaximumADHD Roblox-Client-Tracker was at `0.744.0.7441077` (commit dated 2026-10-21T01:33Z UTC), the same build the user is running. So the API dump and FFlag list below match the user's Studio exactly.

## 1. Has Roblox announced AudioRecorder, and can it be enabled today?

### Takeaway
No. AudioRecorder has never been publicly announced, beta-tested or released. It exists in the engine API but is turned off by a compiled-in feature flag, `FFlagEnableAudioRecorder5`. Roblox's public client settings do not switch that flag on for the desktop client or for Studio on Mac or Windows. There is no Studio Beta Feature, game setting or opt-in that a developer can use to enable it. "AudioRecorder is not enabled yet" is the expected result on build 0.744 on both client and server, and no restart or toggle changes that. Roblox would have to roll the flag out on its side.

### Cited Findings
- The official docs YAML (the source of the Creator Hub page) opens its description with: "**This API is in development and is not available yet.**" It then says AudioRecorder "records audio streams in-experience with a fixed time limit of 60 seconds. The results can be loaded into an AudioPlayer for playback." It adds: "At this time, AudioDeviceInput cannot be recorded." — [creator-docs AudioRecorder.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AudioRecorder.yaml); [Creator Hub page](https://create.roblox.com/docs/reference/engine/classes/AudioRecorder)
- Documentation history from the Git log of that file:
  - **2025-05-15**: first descriptions added (commit "AudioRecorder and Issue Request (#1104)"), with no "not available" warning.
  - **2025-10-14** (commit be666c7360): the line "This API is in development and is not available yet." was added.
  - **2026-02-02, 2026-03-05, 2026-03-17**: only summaries and return types filled in.
  - **2026-03-17**: last change to the file.
  - The warning was never removed. — [GitHub commits for AudioRecorder.yaml](https://github.com/Roblox/creator-docs/commits/main/content/en-us/reference/engine/classes/AudioRecorder.yaml)
- The API dump for build 0.744.0.7441077 still lists the class with tag `NotBrowsable` (hidden from Studio's Insert Object / Explorer browsing) and memory category `Internal`. — [Roblox-Client-Tracker Full-API-Dump.json](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
  - Properties: `IsRecording` (read None / write RobloxSecurity) and `TimeLength` (ReadOnly, NotReplicated).
  - Functions: `Clear`, `GetConnectedWires`, `GetInputPins` (only "Input"), `GetOutputPins` (none), `GetTemporaryContent` (returns `Content`), `Stop`, and the yielding `CanRecordAsync`, `GetUnrecordableInstancesAsync` and `RecordAsync`.
  - Event: `WiringChanged`.
  - All members have the `Audio` capability and script security None, so they are meant to be callable from ordinary scripts once enabled.
- The FFlag list for the same build contains two AudioRecorder gate flags: `[C++] FFlagEnableAudioRecorder5` and `[C++] FFlagAllowAudioRecorderInRobloxScripts`. The "5" suffix means the flag has been re-versioned several times. — [Roblox-Client-Tracker FVariables.txt](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/FVariables.txt)
- The public client settings that Roblox serves (checked 2026-10-20) do **not** contain `FFlagEnableAudioRecorder5` or `FFlagAllowAudioRecorderInRobloxScripts` for `PCDesktopClient`, `PCStudioApp` or `MacStudioApp`. The only AudioRecorder flag they serve is `FFlagAudioRecorderScaleBitrateWithChannels = True`, which tunes the internal implementation. — [clientsettingscdn PCDesktopClient](https://clientsettingscdn.roblox.com/v2/settings/application/PCDesktopClient); [MacStudioApp](https://clientsettingscdn.roblox.com/v2/settings/application/MacStudioApp); [PCStudioApp](https://clientsettingscdn.roblox.com/v2/settings/application/PCStudioApp)
- Searches of the DevForum and Creator Hub found no announcement, beta post or release-notes entry naming AudioRecorder. — [search context: DevForum AudioRecorder concept thread](https://devforum.roblox.com/t/audiorecorder-concept/4663189)
- In a June 1, 2026 community feature request ("AudioRecorder concept"), a non-staff user replied: "There's already something which appears to be nearly exactly like this that is apparently being worked on," and linked the docs page. There was no staff reply. — [DevForum: AudioRecorder concept](https://devforum.roblox.com/t/audiorecorder-concept/4663189)

### Inferences
- An FFlag that is missing from the served client settings runs at its compiled default. The engine returns "AudioRecorder is not enabled yet", so the default must be off. The block is in the engine itself, not in Studio's UI. A Studio Beta Feature checkbox, a Studio restart or a game setting will not help. Whatever the user "enabled" was something else (perhaps the Audio API or another audio beta).
- Developers cannot set FFlags such as `FFlagEnableAudioRecorder5` in published games. Local `ClientAppSettings.json` overrides are restricted by Roblox's FFlag allowlist, would affect only the developer's own machine, and are not a supported path. Recommendation: treat AudioRecorder as unavailable for production.
- `FFlagAllowAudioRecorderInRobloxScripts` suggests a staged rollout: Roblox's own CoreScripts first, then developer scripts. This is inferred from the flag name only.
- The 60-second cap would easily cover the requested ~1 second capture once the API ships. Temporary content would also be session-only.
- The audio engine does no processing on the server (see section 4). Even when enabled, recording on the server probably wouldn't capture anything useful, so client-side recording would be the realistic route. This is an inference; it is undocumented for AudioRecorder specifically.

### Gaps
- There is no official timeline or ETA. No staff post about AudioRecorder's rollout was found.
- The exact error text "AudioRecorder is not enabled yet" did not appear in any indexed web or DevForum page. No public thread was found reporting it or giving a fix.
- No Creator Hub release-notes entry mentioning AudioRecorder was found. The release notes are not in the creator-docs GitHub repo (`content/en-us/release-notes` returns 404), so they could not be grepped. When the class was first added to the API dump is also unconfirmed. The documentation was first written on 2025-05-15, which suggests the class existed internally by spring 2025.

## 2. DevForum threads hitting the "not enabled" error, and their resolutions

### Takeaway
No thread reporting this exact error or a fix was found. Where AudioRecorder comes up on the DevForum, developers only point to the docs page, and no one reports a working setup.

### Cited Findings
- "Record VC input & Save/Load for later" (Scripting Support, Oct 26, 2025):
  - One reply links AudioRecorder and notes "It says it doesn't work with device inputs."
  - It suggests routing the device input through other instances as an untested workaround ("probably").
  - No staff reply, and no confirmation that recording works. — [DevForum thread](https://devforum.roblox.com/t/record-vc-input-saveload-for-later/4026534)
- "AudioRecorder concept" (Engine Features, June 1–2, 2026): a feature request answered by pointing to the in-development class. The thread has no error reports and no staff reply. — [DevForum thread](https://devforum.roblox.com/t/audiorecorder-concept/4663189)

### Inferences
- The suggested "route the mic through effects" workaround would likely fail even after launch. The docs say `GetUnrecordableInstancesAsync` "Traverses the audio graph, starting from this recorder's inputs, to find unrecordable instances," which implies any upstream AudioDeviceInput blocks recording, whatever effects sit in between. — [AudioRecorder.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AudioRecorder.yaml)

### Gaps
- The DevForum is only partly indexed by search. A Bug Report about this error could exist that searches did not surface.

## 3. Is microphone (AudioDeviceInput) recording planned, or blocked for privacy/safety?

### Takeaway
It is blocked. Official docs say AudioDeviceInput "cannot be recorded" "at this time". The engine also blocks script access to mic audio data in related APIs: `GetSpectrum` returns empty whenever an input comes from an AudioDeviceInput. No official statement explaining the policy, or promising mic recording, was found.

### Cited Findings
- AudioRecorder docs: "At this time, AudioDeviceInput cannot be recorded." The `GetUnrecordableInstancesAsync` docs say: "Currently, AudioDeviceInput is not recordable." — [AudioRecorder.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AudioRecorder.yaml)
- AudioAnalyzer:GetSpectrum docs: "If any of the analyzer's inputs come from an AudioDeviceInput, or this method is used from a server script, it returns an empty array." — [AudioAnalyzer.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AudioAnalyzer.yaml)
- AudioDeviceInput is documented as producing "audio streams from physical devices, such as microphones." Its public members cover wiring, Player, Muted, Volume, AccessType and the allow/deny access lists. Processing controls are RobloxScriptSecurity (hidden from developers): `EchoCancellation`, `NoiseSuppression`, `GainControl`, `DictationEnabled` and `IsReady`. — [AudioDeviceInput.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AudioDeviceInput.yaml); [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
- In the 2022 community request "Record Mic Audio & Save/Load it in-experience", non-staff users raised privacy and moderation concerns ("There's a ton of privacy issues with come with that"; "moderation is the main issue here"). No Roblox response was posted, and the last post is dated Oct 26, 2022. — [DevForum thread](https://devforum.roblox.com/t/record-mic-audio-saveload-it-in-experience/2025622)

### Inferences
- The pattern is consistent: no recording, no spectrum, and no hidden processing controls for mic inputs. Raw voice data is deliberately kept out of developer scripts, most likely for privacy and voice-moderation reasons. This is an inference; Roblox has not stated the reason.
- AudioAnalyzer's `PeakLevel` and `RmsLevel` docs do not list an AudioDeviceInput exclusion. A mic loudness meter on the client may work, but it cannot capture or replay audio. Not verified here.

### Gaps
- No official staff statement on whether mic recording is planned or permanently disallowed.

## 4. Other official APIs for raw sample access, runtime audio creation, or capture/replay

### Takeaway
There is no `EditableAudio`, `AudioBuffer`, `AudioStreamWrapper` or any scripted sample read/write API in build 0.744. In May 2026 a Roblox staff member said editable audio is "on our radar" but still under feasibility study. Two related APIs do exist:
- Read-only analysis: `AudioAnalyzer` (`PeakLevel`, `RmsLevel`, `GetSpectrum`) and `AudioPlayer:GetWaveformAsync` / `AudioTextToSpeech:GetWaveformAsync`.
- Generated sources: `AudioTextToSpeech`, and `AudioWindSynthesizer` (NotBrowsable).

None of them can capture arbitrary audio and play it back. AudioRecorder is the only capture-and-replay API, and it is disabled.

### Cited Findings
- The full list of `Audio*` classes in the 0.744 API dump is: AudioAnalyzer, AudioChannelMixer, AudioChannelSplitter, AudioChorus, AudioCompressor, AudioDeviceInput, AudioDeviceOutput, AudioDistortion, AudioEcho, AudioEmitter, AudioEqualizer, AudioFader, AudioFilter, AudioFlanger, AudioFocusService, AudioGate, AudioLimiter, AudioListener, AudioPages, AudioPitchShifter, AudioPlayer, AudioRecorder (NotBrowsable), AudioReverb, AudioSearchParams, AudioSpeechToText, AudioTextToSpeech, AudioTremolo and AudioWindSynthesizer (NotBrowsable). — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
  - No `EditableAudio` class exists. `EditableService` and `AssetService` offer only `CreateEditableImage(Async)` and `CreateEditableMesh(Async)`; there is no audio equivalent.
  - The FFlag list has no `EditableAudio`, `AudioBuffer` or `AudioStream` flags. — [FVariables.txt](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/FVariables.txt)
- Staff on editable audio: ReallyLongArms (a Roblox audio engineer) posted on May 11, 2026 in the "Release Notes for 703" thread. — [DevForum post #221](https://devforum.roblox.com/t/release-notes-for-703/4232806/221)
  - The post says the team has "discussed editable audio a lot".
  - It describes two models: (a) generating an asset ahead of time, like EditableImage/EditableMesh; (b) streaming small uncompressed buffers into the mixer in real time (a "ring buffer approach"). The post prefers (b).
  - It says feasibility is still being assessed and "these features are definitely on our radar."
- `AudioPlayer:GetWaveformAsync(timeRange: NumberRange, samples: int)` (Yields) returns "A table of `samples` numbers ranging between -1 and 1 representing the sampled waveform, or an empty table if a waveform could not be read." — [AudioPlayer.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AudioPlayer.yaml)
  - It reads a loaded asset ahead of time, not a live stream, and the result is read-only.
  - `AudioTextToSpeech` has the same `GetWaveformAsync`. — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
- AudioAnalyzer exposes `PeakLevel`, `RmsLevel`, `SpectrumEnabled`, `WindowSize` and `GetSpectrum()`. — [AudioAnalyzer.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AudioAnalyzer.yaml)
  - `GetSpectrum()` returns RMS levels "evenly spaced from 0 hertz to 24,000 hertz".
  - The class docs say "all audio processing is disabled on the server … Properties and methods of AudioAnalyzer return empty or zero results when used from server scripts."
- Engine-level recording methods on SoundService exist but are `RobloxScriptSecurity` (CoreScript-only), so developers cannot call them: `BeginRecording`, `EndRecording`, `GetRecordingDevices` and `SetRecordingDevice`. — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)
- Runtime-generated audio sources available to developers:
  - `AudioTextToSpeech` (Text, VoiceId, Pitch, Speed, `LoadAsync`, `Play`).
  - `AudioWindSynthesizer` (NotBrowsable; Enabled, Profile, Volume).
  - `AudioSpeechToText` turns a stream into `Text`, not audio. — [API dump](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json)

### Inferences
- Possible official workarounds for a "capture ~1 s and replay" effect today:
  - Replay a known asset or TTS source. Store parameters rather than audio (which asset, `TimePosition`, `PlaybackSpeed`, `PitchShifter` and effect settings) and replay by re-triggering `AudioPlayer`s with the same values.
  - Fake an echo or delay with `AudioEcho` (a live delay effect, not stored audio).
  - Record loudness or spectrum envelopes from `AudioAnalyzer` on the client (not from the mic for spectrum) and drive a synthesized replay. A true sample-accurate replay is not possible.
- No official API gives a live delay/echo of the player's own mic that scripts can store. Effects such as `AudioEcho` on a voice chain only alter what listeners hear in real time; they do not save audio. Using them on voice-chat audio also falls under voice policy.

### Gaps
- No release date, beta or FFlag for EditableAudio or a streaming sample buffer was found.
- Not verified: whether `GetWaveformAsync` would work on AudioRecorder temporary content once recording ships.
- Not verified: whether `RmsLevel`/`PeakLevel` report mic levels from AudioDeviceInput on the client.

## 5. Release notes mentioning AudioRecorder (version, flags)

### Takeaway
No release-notes entry for AudioRecorder was found. The only dated official traces are the docs edits (written 2025-05-15; marked "in development and is not available yet" on 2025-10-14) and the flag names `FFlagEnableAudioRecorder5`, `FFlagAllowAudioRecorderInRobloxScripts` and `FFlagAudioRecorderScaleBitrateWithChannels` (the last is True in production).

### Cited Findings
- Docs edit history, as in section 1. — [GitHub commits for AudioRecorder.yaml](https://github.com/Roblox/creator-docs/commits/main/content/en-us/reference/engine/classes/AudioRecorder.yaml)
- Flag names. — [FVariables.txt](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/FVariables.txt)
- Production flag value `FFlagAudioRecorderScaleBitrateWithChannels True`. — [clientsettingscdn PCDesktopClient](https://clientsettingscdn.roblox.com/v2/settings/application/PCDesktopClient)
- A May 21, 2026 user reply in "Release Notes for 722" noted that a different audio API "GetMixerTime has been marked live again but still isn't enabled." Roblox audio APIs are sometimes marked live in notes before their flags actually turn on. — [DevForum: Release Notes for 722](https://devforum.roblox.com/t/release-notes-for-722/4647110)

### Inferences
- When AudioRecorder does launch, expect one or more of: a DevForum Announcements post from the audio team, a release note marking it live, and removal of "not available yet" from the docs YAML. Developers can watch the creator-docs file history and the client tracker's API dump for the `NotBrowsable` tag being dropped.

### Gaps
- The Creator Hub release-notes pages for builds 674–744 were not individually checked. A low-key "AudioRecorder added (not yet enabled)" line may exist in one of them.
