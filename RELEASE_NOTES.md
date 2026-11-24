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
