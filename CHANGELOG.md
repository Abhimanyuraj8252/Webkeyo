# Changelog

All notable changes to Webkeyo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.3] - 2026-11-25

### Fixed
- Release signing: every release from v1.2.3 on is signed with one stable release keystore, so updates install over the old version normally. (v1.2.0–v1.2.2 were each signed with a different fresh debug key, so Android refused to install them over the old version — the old crashing build stayed on the phone.) No app-code change in this release; install it once after uninstalling the old version, and future updates will work without uninstalling.

## [1.2.2] - 2026-11-25

### Added
- Unlimited-duration prompt-to-video: pick any length — presets from 1 minute to 2 hours, or type any custom minutes (90, 180, 2h, …) with no upper cap. Scenes, script, narration, SFX, subtitles and karaoke all scale to the full requested duration; the plan card shows the planned length, scene and chapter counts, and an honest estimated render time before starting.
- Style picker with code-drawn previews: every one of the 10 styles shows a small preview image rendered in-app by the same motion-graphics engine, so what you see is what the video will look like. No network, no stock images.
- Purpose picker (Reel, Story, Lecture, Education, Information, Motivation): each purpose pre-configures pacing, narration tone, music mood and the karaoke default, and says plainly what it is best for.
- Character-design picker: anime, 3D-style and silhouette characters, all drawn in code and animated into every frame (or no character, the classic look).
- PDF lecture import: pick a lecture PDF and the app reads its pages and text, cuts one scene per page (long pages split further), generates the narration audio and matches audio to scenes automatically — audio, scene and captions stay in sync. Pages without a usable image fall back to a code-drawn scene.
- Scene-by-scene editor: trim a scene, reorder scenes (drag), change a scene's transition (cut/fade/zoom/slide), adjust a scene's timing, or edit its narration — audio, scene and captions re-sync automatically, then re-render with the edited scenes.
- Crash-free long renders: every long operation has per-step timeouts (90s per TTS line, 180s per FFmpeg step) and a Cancel button; a hung provider or a cancelled render shows a clear message with Retry instead of freezing or closing the app. The final mux now stream-copies instead of re-encoding, so a 2-hour video finishes in seconds instead of an hour.
- Regression tests for the new prompt-video flows (open the screen, pick style/purpose/character/duration, edit scenes and save), PDF-to-scenes planning, audio-scene sync math, and editor reorder/trim logic.

### Fixed
- Duration math: generated scenes used to round `est_seconds` to 1 decimal, making every scene 0.06s too long — a 2-hour video overshot by 54 seconds. Scenes now land on the requested duration.
- SFX loop decision now uses the requested length, so a video of exactly 2 minutes gets one 120s bed instead of looping on a float rounding artifact.

## [1.2.1] - 2026-11-25

### Fixed
- Crash on open (first run): the onboarding voice-picker page used `Expanded` inside a scroll view, which throws a layout error as soon as the app opens. The page now lays out correctly.
- Startup hardening: permission requests at launch are now guarded so a device-specific failure can't close the app; an uncaught async error no longer kills the app — it stays on its error screen instead.
- Daily-reminder notification icon fixed (`@mipmap/launcher_icon`, the app's real icon).
- Regression tests: onboarding page builds clean, and a boot failure shows the "could not start" screen with Retry.

## [1.2.0] - 2026-11-24

### Added
- New voice providers, all wired into Settings with their own API keys:
  - Google Cloud TTS WaveNet — 4M chars/month free (billing/card must be enabled), then ~₹17/hr
  - Amazon Polly Standard — 5M chars/month free for the first 12 months, then ~₹17/hr (AWS SigV4 signing built in)
  - Speechify Simba — 500K chars/month free (~10 hrs/month); Starter $10/month = 2M chars (~₹21/hr effective); model picker simba-3.5 (Hindi) / simba-3.2 (English-only)
  - Azure AI Speech — 0.5M neural chars/month free (~10 hrs/month); SwaraNeural with real emotion styles (cheerful, empathetic, newscast)
- Character voice maps for Polly, Azure and Speechify; Google Cloud voices moved to WaveNet (hi-IN-Wavenet-A/C/D)
- MIT LICENSE, CHANGELOG.md, PRIVACY.md, TERMS.md (linked in-app under Settings → About)
- GitHub Actions CI: `flutter analyze` + `flutter test` on every push and pull request
- 3-step onboarding (what it does → pick a voice → render a 15-sec demo) + one-tap "Try a sample story" on first run
- Sentry crash reporting (free tier, DSN optional — app runs fine without it)
- BillingService stub + Hive usage counter for a future paid tier (no charges today)
- One-tap reel templates (the 10 styles as named templates: "Haunted Night", "Love Story", …) and a "Trending this week" row driven by local JSON
- Karaoke-style auto-captions (word-highlight .ass sidecar, burn-in with FFmpeg)
- One-tap share to YouTube / Instagram (share sheet + caption + hashtags copy)
- Daily creation streak, achievements ("First reel", "10 reels", "7-day streak"), creator level / XP per export
- Remix / duplicate project as template; local daily reminder (no server)
- In-app showcase of rendered sample videos (local only)
- `store/` assets: feature graphic + short/full Play Store description
- PITCH.md and a rewritten README (cost table: ~₹35 for a 2-hour Hindi story vs ₹10,000+ studio dubbing)
- App label fixed: "webkeyo" → "Webkeyo" (Android + iOS)

### Changed
- Gemini TTS model updated to `gemini-2.5-flash-tts` (the preview model shuts down 18 Dec 2026); free-tier limits are NOT claimed in hours — Google publishes no per-project request limits
- FFmpeg renders now run with a progress notification and a Cancel button (no more silent background render)
- Home screen split into small widgets with `const` constructors; skeleton/shimmer loading for home and project lists
- `Image.file` calls now use `cacheWidth`/`cacheHeight` so lists don't decode full-resolution images
- FaceDetector is created once and reused, closed in a `finally` block

### Removed
- OpenAI TTS: tts-1 / gpt-4o-mini-tts shut down 6 Jan 2027 — the app now refuses with a clear message instead of calling a dead API. Pick Sarvam, Gemini, Google Cloud WaveNet, Azure, Speechify, Polly or Deepgram instead.

### Fixed
- Splash screen + startup timeouts: a slow provider registry or Hive open can no longer leave a black screen

## [1.1.0] - 2026-11-24

### Added
- 10 cinematic style presets (cinematic-dark, anime-premium, neon-cyberpunk, horror-night, romantic-pink, motivational-gold, minimal-clean, retro-film, nature-green, royal-purple)
- 31 skills across 7 pipeline stages (SKILLS.md)
- Voice providers: Sarvam Bulbul, Gemini TTS, Deepgram Flux, Fish Audio, MiniMax (paid-only), Google Cloud TTS, Edge TTS (free), Piper, ElevenLabs, Flutter TTS
- Per-character voices with emotion + narrator scene explanation
- Prompt-to-video: code-drawn motion graphics (Pillow-style frames in Dart/FFmpeg), SFX, subtitles, thumbnails
- Script/story generator, editing, thumbnail, subtitles, SFX screens
- SKILLS.md, RELEASE_NOTES.md, 36 unit tests

### Fixed
- No gTTS anywhere (robotic — rejected). Silent audio is never presented as voiceover.
