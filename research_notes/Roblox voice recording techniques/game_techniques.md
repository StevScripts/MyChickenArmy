# How Roblox games record and replay voice or in-game audio, and which workarounds work (as of October 20, 2026)

## Which games appear to record and replay voice, and how do they do it? Does any game truly store a clip and replay it later on demand?

### Takeaway
I found no public evidence that any Roblox experience stores a player's mic audio and replays it later on demand. The documented "replay your voice" experiences are live delay effects, capped at 5 seconds, which matches the AudioEcho DelayTime maximum. The viral "parrot" voice-chat trolling of 2026 is a player prank. No source shows it is an in-game recorder, and most likely it uses external clip and soundboard tools. Voice changers ("Talking Ben"-style pitch) are live AudioPitchShifter chains.

### Cited Findings
- **"Test Your Mic With Delay" (creator @PimentChaud).** The game page describes it as a place where you "play back your own voice and hear how you sound like on roblox voice chat." Its sliders set delay time and mic volume, and it states the "Delay is capped at 5 seconds and sound volume at x3 because of roblox' own limitations." The x3 cap matches AudioDeviceInput.Volume's 0–3 range, and the 5 s cap matches AudioEcho.DelayTime's 0.001–5 range (both covered below). The page shows no visit count or dates. — [Roblox game page](https://www.roblox.com/games/75627323306561)
- A search summary of the same page says it lets you choose to hear yourself "directly or through the radio as if it were someone else's POV," and covers your soundboard too. — [Roblox game page](https://www.roblox.com/games/75627323306561)
- **MIC UP.** A developer wrote on October 26, 2025 that MIC UP "seemingly had the feature to 'delay' VC input and replay it after a few seconds" and attached a video. The only reply pointed to AudioRecorder and suggested routing the device input "through other instances" to get past the ban on recording device input. No code was posted, and nobody confirmed it works. — [DevForum: Record VC input & Save/Load for later (Oct 26, 2025)](https://devforum.roblox.com/t/record-vc-input-saveload-for-later/4026534)
- I found no developer post or other source explaining how MIC UP's delay works. — (search gap; same thread above is the only source)
- **"Talking Ben"-style games.** On October 26, 2024, a developer noted that some games play back a user's voice "at a different pitch when a mic signal is heard." The reply suggested the new Audio API allows real-time alteration such as pitch, and raised a concern about recording, storing and processing voices. No staff replied. — [DevForum: Does the new audio api allow for voice playback (Oct 26, 2024)](https://devforum.roblox.com/t/does-the-new-audio-api-allow-for-voice-playback/3228890)
- **Voice changers in practice.** The documented pattern puts an AudioPitchShifter between the player's AudioDeviceInput and the character's AudioEmitter. — [DevForum: Adding voice filters to a player](https://devforum.roblox.com/t/adding-voice-filters-to-a-player/2859292)
- Another developer reports pitching down VC input with AudioPitchShifter successfully. — [DevForum: Is it possible to change the pitch of an user's VoiceChat audio?](https://devforum.roblox.com/t/is-it-possible-to-change-the-pitch-of-an-users-voicechat-audio/3598514)
- A bug report says setting AudioPitchShifter.Pitch above 1 from a script has no effect. Values from 0.5 to 1.0 work, and the Studio slider works. Check the thread for whether it has been fixed. — [DevForum bug: Cannot set AudioPitchShifter > 1 from script](https://devforum.roblox.com/t/cannot-set-value-for-audiopitchshifter-or-pitchshiftsoundeffect-greater-than-1-from-script/3864461)
- **Parrot voice-chat trolling (2026).** YouTuber nobrainjames uploaded "TROLLING as PARROTS on ROBLOX VOICE CHAT" on January 20, 2026. He "clips audio from players using the voice chat feature in Roblox" and plays it back. It spawned the "I just get so nervy" meme (TikTok clips from Jan 22 to Feb 12, 2026). The page names no experience and does not explain the playback method. — [Know Your Meme: I Just Get So Nervy](https://knowyourmeme.com/memes/i-just-get-so-nervy)
- TikTok has many "parrot repeats my voice" and "how to do the parrot prank" clips. They describe it as a prank, not a named game. — [TikTok: Parrot Repeats My Love in Roblox Voice Chat](https://www.tiktok.com/@the.craig.memes/video/7597176817585376526); [TikTok discover: parrot prank](https://www.tiktok.com/discover/how-do-people-do-the-parrot-prank-on-roblox)
- **Developers' own statement (Feb 27, 2024).** The developer of *Clip It* wrote that "recording and saving voice chat clips is currently impossible" and asked for a feature. Commenters asked for ScreenshotHud-style consent. No staff replied. — [DevForum feature request: record and upload voice chat clips](https://devforum.roblox.com/t/allow-developers-to-record-and-upload-voice-chat-clips-to-the-platform-as-audio/2857845)
- **Roblox staff (Dec 2, 2024).** Asked about spectrum analysis of voice input, staff replied that "Getting direct access to voice spectra isn't on the roadmap." — [DevForum: New Audio API Features: Directional Audio, AudioLimiter and More](https://devforum.roblox.com/t/new-audio-api-features-directional-audio-audiolimiter-and-more/3282100)

### Inferences
- Every named in-game "replay" feature I found (Test Your Mic With Delay, the reported MIC UP feature) behaves like a fixed live delay with a maximum of about 5 s. That points to AudioEcho, with the dry signal off and the wet signal only, set to the chosen DelayTime. With that design the replay always happens N seconds after you speak. Nothing can be played back later on demand.
- The parrot trolls replay other players' speech at arbitrary times. In-game, that would need a recorder that does not exist for mic input, so it is most likely done off-platform. The creator would capture Roblox's output with a desktop recorder and play clips back into the mic through a soundboard or virtual audio cable (for example Voicemod). No source confirms nobrainjames's exact setup. That kind of replay is also outside the game's control and is not a technique a developer can ship.
- "Talking pet" or "Talking Ben"-style games on Roblox are almost certainly live pitch-shift chains (AudioDeviceInput → AudioPitchShifter → AudioEmitter), possibly combined with a short AudioEcho delay. That gives a "repeat after me" feel, not true storage.

### Gaps
- I could not find a public script or developer explanation for MIC UP's delay feature, or for any named "repeat after me" or "parrot" game.
- I could not confirm the tooling behind the nobrainjames parrot videos.
- I found no Roblox experience that genuinely stores mic audio and plays it back later on a button.

## What is the maximum AudioEcho DelayTime, and can a delay effect be "frozen" or looped to replay a captured one-second buffer?

### Takeaway
AudioEcho.DelayTime ranges from 0.001 to 5 seconds. Feedback ranges from 0 to 1, and the docs say that at 1 "old echoes never fully disappear," so in principle a one-second clip could circulate indefinitely in the echo line. I found no DevForum experiment confirming that a "freeze" (Feedback = 1, input cut, dry off) is clean, stable or controllable. Any button-triggered replay built on it would start at an arbitrary point in the loop unless timed to the loop boundary.

### Cited Findings
- **AudioEcho properties (from the docs).**
  - DelayTime: float, 0.001–5 s, "the gap between echoes."
  - Feedback: float, 0–1. At 0 you hear one echo; at 1, "old echoes never fully disappear."
  - DryLevel and WetLevel: −80 to +10 dB.
  - RampTime: 0–60000 s, interpolates DelayTime changes, smoothing them or producing a pitch-bend effect.
  - The docs list no defaults. — [Roblox docs: AudioEcho (markdown)](https://create.roblox.com/docs/reference/engine/classes/AudioEcho.md); [AudioEcho class page](https://create.roblox.com/docs/reference/engine/classes/AudioEcho)
- **AudioEcho as an interpolating delay line (Dec 2, 2024).** "AudioEcho is now an *interpolating* delay line." With RampTime above 0, changes to DelayTime and Feedback glide, so "adjusting `DelayTime` will temporarily and cleanly alter pitch," with doppler "for free." The sample updates DelayTime every frame from distance ÷ speed of sound. — [DevForum: New Audio API Features (Dec 2, 2024)](https://devforum.roblox.com/t/new-audio-api-features-directional-audio-audiolimiter-and-more/3282100)
- **Performance problems.**
  - Many AudioEcho instances (10–20 siren emitters in a full server, Feedback 0.15) made all client audio stutter. Setting Bypass fixed it.
  - According to a search-result summary of the thread (not read directly), a staff reply said RampTime was disabled on the client for now.
  - A separate report notes that AudioEcho RAM usage increased.
  - Sources: [DevForum bug: AudioEcho causes all Roblox audio to violently stutter](https://devforum.roblox.com/t/audioecho-causes-all-roblox-audio-to-violently-stutter/3656212); [DevForum bug: Increased AudioEcho RAM usage](https://devforum.roblox.com/t/increased-audioecho-ram-usage/3271123)
- **Delay limit in practice.** The "Test Your Mic With Delay" game caps its delay at 5 s "because of roblox' own limitations," which matches the documented DelayTime maximum. — [Roblox game page](https://www.roblox.com/games/75627323306561)
- **Other delay-capable effects.** The legacy EchoSoundEffect (for Sound objects) has a Delay property: "how long the effect will wait to play the echoed sound." It applies to Sound instances, not to the new-API voice chain. — [robloxapi ref: EchoSoundEffect](https://robloxapi.github.io/ref-temp/class/EchoSoundEffect.html)
- **No freeze experiment found.** Searches for AudioEcho Feedback = 1 loopers or freezes on the DevForum returned nothing relevant. — (search gap)

### Inferences
- **Live delayed replay of your own voice (works today).** Wire `AudioDeviceInput → AudioEcho (DelayTime = 1, Feedback = 0, DryLevel = −80, WetLevel = 0) → AudioEmitter/AudioListener path` and you hear yourself exactly 1 s later, once. This is a delay, not a recording: the clip cannot be held and played back when a button is pressed.
- **"Freeze" looper (experimental, untested in sources).** Steps, in order:
  1. Put an AudioFader before the echo (or toggle AudioDeviceInput.Muted).
  2. Set DelayTime = 1, Feedback = 1 and DryLevel = −80.
  3. Let the player speak for 1 s.
  4. Cut the input (fader volume 0 or Muted = true).
  5. The last ~1 s keeps recirculating, repeating every second.
  6. Put a second AudioFader after the echo at 0 and open it for 1 s to "play" on a button press.
- **Risks of the freeze looper.**
  - Feedback = 1 may slowly decay, or grow or saturate, depending on the implementation; an AudioLimiter after it would guard against clipping.
  - Playback starts at an arbitrary loop phase unless the button press is quantized to the loop boundary (tracked with os.clock from the moment input was cut).
  - Changing DelayTime while it runs would pitch-bend the clip.
  - The docs give only "never fully disappear" as evidence; whether the loop is sample-exact is unverified.
- With the 5 s DelayTime maximum, the longest loop held in a single AudioEcho is about 5 s. A 1 s clip fits easily.
- Chaining several echoes could stretch the total delay, but each extra effect adds CPU cost and the stutter risk above.

### Gaps
- No documented default values, and no statement on whether Feedback = 1 is truly lossless or stable.
- No DevForum experiments with Feedback = 1 as a sampler or looper, or with muting input while the echo keeps ringing.
- Not established whether a mic-sourced echo loop survives AudioDeviceInput being muted (whether the device stream stops feeding silence or the graph tears down), or whether RampTime still being disabled on the client affects this.

## DevForum threads and code on record voice, replay voice, voice recorders, echo mic, voice delay and voice changers

### Takeaway
AudioRecorder is the official recording API. Its docs say it is "in development and is not available yet," it caps recordings at 60 s, and "At this time, AudioDeviceInput cannot be recorded." This matches the "AudioRecorder is not enabled yet" error in Studio 0.744. The working community code is all live-chain wiring (device input → effect → emitter). For a waveform display of mic audio, AudioAnalyzer.GetSpectrum returns an empty array when its inputs come from an AudioDeviceInput, which leaves only PeakLevel and RmsLevel polling.

### Cited Findings
- **AudioRecorder docs.**
  - Status and limits: "This API is in development and is not available yet." Recordings are capped at 60 seconds, and "At this time, AudioDeviceInput cannot be recorded."
  - Methods and properties:
    - RecordAsync() yields and raises an error if recording can't start.
    - Stop() and Clear().
    - CanRecordAsync() returns false at the time limit.
    - GetTemporaryContent() returns a session-only Content for an AudioPlayer.
    - GetUnrecordableInstancesAsync() traverses the graph from the recorder's input and lists unrecordable instances.
    - IsRecording; TimeLength; a single "Input" pin.
  - The sample records an AudioPlayer and notes leading silence, because there is "no exact way to sync" with the audio buffer.
  - Source: [Roblox docs: AudioRecorder](https://create.roblox.com/docs/reference/engine/classes/AudioRecorder.md)
- **Recorder status in June 2026.** A June 1, 2026 feature request ("AudioRecorder concept") proposed session-only, filtered recordings of 5 s to 1 h, including from AudioDeviceInput, for voicemail, answering machines and mic delay. A reply said something "nearly identical" is apparently in development and linked the AudioRecorder docs. No staff replied, and no enablement date was given. — [DevForum: AudioRecorder concept (Jun 1, 2026)](https://devforum.roblox.com/t/audiorecorder-concept/4663189)
- **Proposed workaround, unverified.** One reply suggested routing AudioDeviceInput through other instances so AudioRecorder can record it. — [DevForum: Record VC input (Oct 26, 2025)](https://devforum.roblox.com/t/record-vc-input-saveload-for-later/4026534)
- The docs' GetUnrecordableInstancesAsync traverses the whole upstream graph, which suggests an intermediate effect would not hide the device input. — [Roblox docs: AudioRecorder](https://create.roblox.com/docs/reference/engine/classes/AudioRecorder.md)
- **Wiring template (Indigo, Sep 13, 2024).**
  - A `connectDevices(src, target)` helper creates a Wire with SourceInstance/TargetInstance.
  - On PlayerAdded, an AudioDeviceInput is created with Player set and Muted = false.
  - On CharacterAdded, an AudioEmitter is created and wired to it.
  - Effects are inserted between them; the example uses AudioReverb.
  - Source: [DevForum: Roblox's New Audio API: A Somewhat Deep Dive](https://devforum.roblox.com/t/robloxs-new-audio-api-a-somewhat-deep-dive/3156011)
- **AudioDeviceInput docs.**
  - Active is "only set by Roblox core scripts"; Muted is publicly scriptable.
  - Player should be set on the server to replicate. Locally it generally works only for LocalPlayer.
  - AccessType plus SetUserIdAccessList gives allow and deny lists.
  - Volume ranges 0–3.
  - Source: [Roblox docs: AudioDeviceInput](https://create.roblox.com/docs/reference/engine/classes/AudioDeviceInput.md)
- **AudioAnalyzer.**
  - PeakLevel and RmsLevel give the loudest and average level of the last buffer, updating faster than the frame rate.
  - GetSpectrum returns RMS levels from 0–24 kHz, but returns an empty array "if the inputs come from an AudioDeviceInput," on the server, or when SpectrumEnabled is false.
  - Everything is zero on the server. No raw sample access.
  - Source: [Roblox docs: AudioAnalyzer](https://create.roblox.com/docs/reference/engine/classes/AudioAnalyzer.md)
- **Waveform for assets.** AudioPlayer:GetWaveformAsync(timeRange: NumberRange, samples: int) returns `samples` values in −1..1 for an asset before playback. It is a waveform preview for uploaded audio, not for mic audio. — [Roblox docs: AudioPlayer](https://create.roblox.com/docs/reference/engine/classes/AudioPlayer.md)
- **Wiring pitfalls.**
  - Other players could not hear an AudioEmitter wired from an AudioDeviceInput. — [DevForum: Other players cannot hear AudioEmitter wired from AudioDeviceInput](https://devforum.roblox.com/t/other-players-cannot-hear-audioemitter-thats-wired-from-audiodeviceinput/3414543)
  - Enabling VoiceChatService.UseAudioApi fixed missing device audio in one case. — [DevForum: Help with VoiceChatService](https://devforum.roblox.com/t/help-with-voicechatservice/3381318)
  - Testing a mic in Studio is a known pain point. A feature request asks for local-mic testing when UseAudioApi is on, and an October 2026-era bug thread asks where the default AudioDeviceInput is during playtest. — [DevForum: Give us the ability to better test Voice Chat API](https://devforum.roblox.com/t/give-us-the-ability-to-better-test-voice-chat-api/3176821); [DevForum: Where is the default AudioDeviceInput when play testing?](https://devforum.roblox.com/t/studio-where-is-the-default-audiodeviceinput-when-play-testing/4710252)
  - A Team Test session with voice enabled in Communications settings is reported to work for testing. — [DevForum: Test voice chat in Studio](https://devforum.roblox.com/t/test-voice-chat-in-studio/2441552/4)

### Inferences
- **"Signal wave" display for the mic.** Poll AudioAnalyzer.RmsLevel (or PeakLevel) each RenderStepped on a client-side AudioAnalyzer wired from the local AudioDeviceInput. Push each value into a ring buffer of bars to draw a scrolling amplitude envelope, which is the usual "voice wave" look. A true waveform or spectrum of voice is blocked by design (GetSpectrum is empty for device input, and staff said voice spectra are not on the roadmap). The docs do not say whether PeakLevel/RmsLevel are also blocked for device input. Test that first.
- **Fake replay waveform.** For the "replay" visual, store the ~60 RMS values captured during the 1 s of speech and redraw that same array while the echo or loop plays. That makes the replay waveform look like the recording, even though the audio itself is a delay effect.
- Wrapping AudioDeviceInput in effects before an AudioRecorder is unlikely to bypass the restriction, because GetUnrecordableInstancesAsync walks the upstream graph. A bypass would also likely be treated as a policy violation (see the policy section).

### Gaps
- No released AudioRecorder date. As of October 2026 it is still documented as unavailable, and nothing indicates device input will ever be allowed.
- No confirmation of whether AudioAnalyzer.PeakLevel/RmsLevel return non-zero values for AudioDeviceInput sources (only GetSpectrum is documented as blocked).

## Policy: Roblox voice-chat rules on modifying, replaying or recording players' voices

### Takeaway
I found no official Roblox policy text that addresses experiences delaying, pitch-shifting or replaying voice. Roblox's own APIs block recording and spectrum analysis of mic input, and community members expect enforcement against workarounds that defeat voice-safety systems such as age groups. Live effects on the speaker's own voice (pitch, echo, reverb) are an explicitly supported use of the API. A self-only delayed monitor is the most conservative design, though no explicit official approval was found.

### Cited Findings
- Roblox's privacy policy says Roblox itself monitors, collects and stores voice audio to enable voice chat and detect abuse, and uses recordings for training only with consent. It does not address developer-side recording. — [Roblox Privacy and Cookie Policy](https://en.help.roblox.com/hc/en-us/articles/115004630823-Roblox-Privacy-and-Cookie-Policy)
- Voice chat requires players aged 13+ who verify by phone or government ID, depending on country. — [Roblox docs: Add voice chat](https://create.roblox.com/docs/tutorials/use-case-tutorials/audio/add-voice-chat)
- The official Audio API beta announcement frames the API as creator control over "sound and voice," and the Audio API guides show effects inserted into voice chains. — [DevForum: New Audio API [Beta] (Feb 28, 2024)](https://devforum.roblox.com/t/new-audio-api-beta-elevate-sound-and-voice-in-your-experiences/2848873)
- **Age-group bypass thread.** On March 5, 2026, a developer reported that rerouting a player's AudioDeviceInput through effects into a custom AudioEmitter seemed to make voice audible to players outside the voice age group, as if it were game audio. They filed it as a bug. Commenters said Roblox "would likely take action" and that it "would result in a ban." No staff replied. — [DevForum: There's a way to bypass roblox's age group through voice chat (Mar 5, 2026)](https://devforum.roblox.com/t/theres-a-way-to-bypass-robloxs-age-group-through-voice-chat/4474549)
- **Community concerns.** Developers raised the "consequences of allowing users voice's to be recorded in-game, stored then processed." — [DevForum: Does the new audio api allow for voice playback](https://devforum.roblox.com/t/does-the-new-audio-api-allow-for-voice-playback/3228890)
- Consent prompts similar to ScreenshotHud were proposed as a requirement for any voice-clip feature. — [DevForum feature request](https://devforum.roblox.com/t/allow-developers-to-record-and-upload-voice-chat-clips-to-the-platform-as-audio/2857845)
- **Engine-level restrictions.**
  - AudioDeviceInput cannot be recorded. — [AudioRecorder docs](https://create.roblox.com/docs/reference/engine/classes/AudioRecorder.md)
  - GetSpectrum is empty for device input. — [AudioAnalyzer docs](https://create.roblox.com/docs/reference/engine/classes/AudioAnalyzer.md)
  - Staff said voice spectra access "isn't on the roadmap." — [DevForum Dec 2, 2024](https://devforum.roblox.com/t/new-audio-api-features-directional-audio-audiolimiter-and-more/3282100)

### Inferences
- **Safest design for the user's feature.** Keep everything on the client. Wire only the local player's own AudioDeviceInput into a local AudioListener/output path that only that player hears, with no AudioEmitter, so other players never hear the delayed copy. Don't route it to players outside the voice cohort, and don't persist anything.
- Replaying other players' voices to third parties (the parrot-style use) is where the moderation and harassment risk lies. Technically it also requires off-platform tools.
- A visible label such as "Hear yourself back (only you can hear this)" would match the consent spirit of community proposals. This is a design inference, not a stated rule.

### Gaps
- No official Roblox Community Standards or Terms text found that explicitly allows or bans delaying or replaying the local player's own voice to themselves, or pitch-shifting voice heard by others.
- No staff statement on the March 2026 age-group bypass report.

## Capturing and replaying a non-mic source (AudioPlayer)

### Takeaway
Non-mic sources are the case AudioRecorder was designed for: the docs sample records an AudioPlayer and plays it back via GetTemporaryContent. The API is still unavailable, though. Until it is enabled, replaying non-mic audio means replaying the asset itself: re-seek and loop it with TimePosition, PlaybackRegion and LoopRegion, and draw its real waveform with GetWaveformAsync.

### Cited Findings
- The AudioRecorder docs sample wires an AudioPlayer into an AudioRecorder, records for a set time, and loads the result into a new AudioPlayer through GetTemporaryContent(), which is valid only for the session. The page says the recording includes some leading silence and that the API "is not available yet." — [Roblox docs: AudioRecorder](https://create.roblox.com/docs/reference/engine/classes/AudioRecorder.md)
- **AudioPlayer replay controls.**
  - TimePosition is read/write.
  - PlaybackRegion and LoopRegion are NumberRanges in seconds.
  - Looping fires the Looped event on each loop.
  - GetWaveformAsync(NumberRange, samples) returns −1..1 samples ahead of playback.
  - Source: [Roblox docs: AudioPlayer](https://create.roblox.com/docs/reference/engine/classes/AudioPlayer.md)
- Community feature requests asked for a general "record any audio locally and play it back through an AudioPlayer" capability (Feb 28, 2024 reply), which shows it did not exist at the time. — [DevForum feature request](https://devforum.roblox.com/t/allow-developers-to-record-and-upload-voice-chat-clips-to-the-platform-as-audio/2857845)

### Inferences
- **Game sounds (soundboard, chicken clucks).** For in-game sounds, "record ~1 s and play it back" can be faked exactly. Remember which asset and TimePosition window were playing during the "recording" second. On the button press, set PlaybackRegion to that window on a fresh AudioPlayer and play it. Draw the waveform from GetWaveformAsync over the same window. Unlike the mic, this gives a true on-demand replay and a real waveform.
- **AudioEcho with non-mic sources.** An AudioEcho on an AudioPlayer chain behaves the same as with the mic: a 5 s maximum delay, and the experimental Feedback = 1 freeze. It is unnecessary here, because the asset can simply be re-seeked.
- **When AudioRecorder ships.** If AudioRecorder ships for non-device sources, it becomes the clean path for AudioPlayer, AudioPlayer-plus-effects, or mixed game-audio capture up to 60 s per recording.

### Gaps
- No date for AudioRecorder enablement. I couldn't confirm whether GetTemporaryContent output works with GetWaveformAsync once available.
