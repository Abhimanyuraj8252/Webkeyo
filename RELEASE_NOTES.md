# Webkeyo v1.2.0 — Release Notes

## What's new

### New voice providers (Settings → AI Providers → TTS)
- **Google Cloud TTS WaveNet** — completed. 4M chars/month free (Standard + WaveNet), then ~₹17/hr. Default voices hi-IN-Wavenet-A (F) / hi-IN-Wavenet-C (M). Billing/card must be enabled on the Google Cloud project even for free use.
- **Amazon Polly Standard** — 5M chars/month free, first 12 months only, then ~₹17/hr. AWS SigV4 signing built in (Access Key ID + Secret + region, default ap-south-1). Voices Aditi / Kajal (female); no male Hindi Standard voice verified.
- **Speechify Simba** — 500K chars/month free (~10 hrs/month); Starter $10/month = 2M chars (~₹21/hr effective). Model picker: simba-3.5 (48 languages incl. Hindi) / simba-3.2 (English-only — use 3.5 for Hindi).
- **Azure AI Speech** — 0.5M neural chars/month free (~10 hrs/month). SwaraNeural has REAL emotion styles (cheerful, empathetic, newscast) via SSML.
- **Gemini TTS** updated to `gemini-2.5-flash-tts` (the preview model shuts down 18 Dec 2026). Google publishes no per-project free-tier request limits — treat it as previews / short clips only; the app no longer claims hours for it.
- **OpenAI TTS removed**: tts-1 / gpt-4o-mini-tts shut down 6 Jan 2027. The app now refuses with a clear message instead of calling a dead API.

### Onboarding + first run
- 3-step onboarding: what it does → pick a voice → render a short demo (free, no key) or jump into a sample story (Haunted Night). Skippable, shown once.

### One-tap reels & retention
- One-tap reel templates (the 10 styles as named templates), "Trending this week" (local JSON per release), karaoke-style word-highlight captions (.ass), one-tap share to YouTube / Instagram (caption + hashtags copied), daily creation streak + achievements + creator levels (XP per export), remix/duplicate project as template, local daily reminder.

### Fundable must-haves
- MIT LICENSE, CHANGELOG.md, PRIVACY.md + TERMS.md (linked in-app under Settings → About), GitHub Actions CI (analyze + test), PITCH.md, rewritten README (cost table, roadmap, APK badge), store/ assets (feature graphic + Play Store descriptions; screenshots are labelled placeholders until real captures are taken), landing-page content (`docs/landing-page.md`), BillingService stub + Hive usage counter for a future paid tier (no charges today), Sentry crash reporting (free tier, off unless a DSN is passed at build time).

### Performance (reference device: ₹20–25k phone, 6 GB RAM, Dimensity 900)
- FFmpeg renders: progress notification + Cancel button (cancels the in-flight session, cleans up intermediates).
- `Image.file` decodes at display size in lists; home screen split into small widgets; FaceDetector created once and closed in `finally`; splash screen + startup timeouts (never a black screen); skeleton/shimmer loading for home lists.
- Per-ABI split APKs configured (`--split-per-abi`, arm64-v8a first, target ~60–80 MB — the v1.1.0 fat APK was 266 MB). **APK not rebuilt yet in this release cycle — see Notes.**

## Notes
- **APK rebuild is the next step (parent authorizes it):** `flutter build apk --split-per-abi --release`. The v1.1.0 APK (`build/app/outputs/flutter-apk/app-release.apk`, 266 MB, versionCode 2, debug-signed) is still the file on disk — do not ship it as v1.2.0.
- New provider clients (Polly, Speechify, Azure) are implemented but NOT live-tested here (no API key was used). They throw a clear error if the key/voice/region is missing — they never write silence as a voiceover.
- No gTTS anywhere in the app. No hardcoded API keys. No paid services, no server/backend.
- Template marketplace and cloud sync are deferred (they need a backend).

---

# Webkeyo v1.1.0 — Release Notes

## What's new

### Prompt-to-video (Home → Prompt Video)
One line in, reel/video out, ₹0. Code-drawn motion graphics — no paid video
API, no stock footage, no source images needed:
- 10 style presets (Cinematic Dark, Anime Premium, Neon Cyberpunk, Horror
  Night, Romantic Pink, Motivational Gold, Minimal Clean, Retro Film, Nature
  Green, Royal Purple)
- 6 genres (haunted, love, action, sad, motivational, mystery) with
  scene-by-scene scripts, hook in scene 1, cliffhanger ending
- Hook title, burned English subtitles, speaker/emotion chip, progress bar
- Narration + synthesised SFX mixed (rain, thunder, wind, heartbeat, chime,
  whoosh — no downloads, no licence)
- Vertical 9:16 (reels) or horizontal 16:9, 7–30 seconds
- A 1280×720 thumbnail and Hindi + English SRT ship with every video

### Hindi-first voices (Settings → AI Providers → TTS)
- **Sarvam Bulbul** — 80+ Hindi voices, emotion-rich; ₹100 signup credit,
  then ₹20 / 10,000 chars. The default Hindi voice.
- **Gemini TTS** — free tier, 30 voices, Hindi listed, `[laughs]`/`[whispers]`
  audio tags.
- **Deepgram Flux TTS** — $200 free credit, no card, no expiry; Hindi voices
  (flux-arjun-hi, flux-anjali-hi, …). Aura-2 has no Hindi — Flux only.
- **Fish Audio S2.1 Pro** — free tier 8,000 credits/month (~7 min), 500
  chars/generation; free plan is personal NON-COMMERCIAL use only; the free
  API model is free to call through 30 Nov 2026.
- **MiniMax T2A — PAID ONLY.** No free allowance is published on its official
  pricing page; it is wired as a paid provider and never presented as free.
- Per-character voices: every character keeps one voice per provider for the
  whole story; the narrator gets a separate voice; scenes with no dialogue
  are explained by the narrator. Keys come only from Settings — never
  hardcoded, never in the code.

### Skills library (Home → Skills) + Samples (Home → Samples)
- 31 skills across 7 stages (Script, Voicing, Video, Editing, Thumbnail,
  Subtitles, Music/SFX) — what each does, what it costs, how to install it,
  whether it works on a phone. Same list in `SKILLS.md`.
- One ready sample prompt per genre — tap to render it.

### Editing helpers (FFmpeg, no paid editor)
Concat, fade in/out, crossfade, speed ramp, text overlays, end-screen card.

## Fixes
- SFX filters for rain+thunder and the soft pad used invalid FFmpeg syntax
  (a second `sine` source chained mid-filter). Both are now single `aevalsrc`
  expressions, verified with system ffmpeg.
- Deepgram provider renamed from "Deepgram Aura" to "Deepgram Flux TTS"
  (Aura-2 has no Hindi voices). Existing installs are migrated on startup.

## Notes
- **APK (built and verified 24 Nov 2026):** `build/app/outputs/flutter-apk/app-release.apk` — 266.4 MB (268,431,684 bytes, 496 files), version 1.1.0 (versionCode 2), package `com.webkeyo.webkeyo`, minSdk 24, targetSdk 36. SHA-1: `7b6fdbb91aa803242294adfb1afaec02e43e0018`. Signed with the **debug key** (release uses the template's debug signing config) — it installs by sideloading, but it is NOT a Play-Store release signature; a proper release keystore is needed before Play Store upload. The size is large because FFmpeg native libraries + ML Kit + all ABIs ship in one fat APK; per-ABI split APKs would be smaller.
- **Build warning (non-blocking):** Flutter warns the app applies the Kotlin Gradle Plugin directly and 7 plugins still apply KGP (audio_session, ffmpeg_kit_flutter_new, flutter_tts, pdfx, share_plus, shared_preferences_android, video_player_android). Future Flutter versions will fail the build on this — the app and those plugins need migration to Built-in Kotlin before a future Flutter upgrade.
- Deepgram, Fish Audio and MiniMax clients are implemented but NOT live-tested
  here (no API key was used). They throw a clear error if the key or voice ID
  is missing — they never write silence as a voiceover.
- No gTTS anywhere in the app. No hardcoded API keys.
- Higgsfield is paid-only (free plan has 0 credits) and is documented as
  such — it is not in the free skills list.
