# Changelog

All notable changes to Webkeyo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
