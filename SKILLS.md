# Webkeyo Skills Library

Every stage of making a story video, in one place. **31 skills across 7 stages:**
Script (3), Voicing (10), Video (6), Editing (6), Thumbnail (1), Subtitles (3),
Music/SFX (2).

Each skill says what it does, what it costs, how to install it, whether it
works on a phone, when to use it, and what it does NOT do. Where a number is
not verified here, the entry says "check the provider's pricing page" — no
invented prices or star counts.

The same registry lives in code at `lib/services/skills_registry.dart` and is
shown in the app at Home → **Skills**.

Status: **In this app** = working code in this repo. **Starter** = exporter /
snippet, documented, not a full install. **Guide** = documented recipe only.

---

## Script (3)

### 1. Template script generator (`script_generator.dart`) — In this app
- **What:** One-line idea + genre → scene-by-scene script with dialogue, narrator lines, emotion tags, hook in scene 1 and a cliffhanger ending.
- **Cost:** ₹0 — local, no API call, no key.
- **Install:** None — part of this app.
- **Mobile:** Yes. Pure Dart, runs on the phone.
- **Use when:** First draft of any story, when you have an idea but no script yet.
- **Does NOT do:** Not a finished story — it is a template draft. Edit the lines; use the AI script path for natural spoken Hindi.

### 2. AI script generation (`api_service.dart`) — premium path — In this app
- **What:** Vision AI reads manga/manhwa pages or documents and writes a structured scene-by-scene script in Hindi/Hinglish, with character consistency.
- **Cost:** Provider API credit — you pay the text/vision provider per token (check the provider pricing page).
- **Install:** API key in Settings (AI Providers > Script/Text).
- **Mobile:** Yes. API call only — nothing heavy runs on the phone.
- **Use when:** The real script for a publishable video.
- **Does NOT do:** Not free, and not a translator — it writes for spoken Hindi.

### 3. Story structure (hook / 3-act / cliffhanger) — In this app
- **What:** Hook in the first 2 seconds, 3-act beats (Setup → Conflict → Payoff), cliffhanger ending. Implemented in `script_generator.dart` and documented in the AI prompt templates.
- **Cost:** ₹0.
- **Install:** None.
- **Mobile:** Yes. A writing rule, not software.
- **Use when:** Every story, before a single line is written.
- **Does NOT do:** Not a guarantee of virality — structure helps retention, it does not create it.

---

## Voicing (10)

### 4. Piper TTS (offline, built-in) — In this app
- **What:** Neural Hindi TTS via a local Piper server. Male/female voices. Emotion via pace.
- **Cost:** ₹0 — no key, local server.
- **Install:** Piper server URL in Settings (TTS > Piper TTS).
- **Mobile:** No — needs a reachable Piper server; heavy on a phone, works via a server URL.
- **Use when:** Offline voiceover when a Piper server is available.
- **Does NOT do:** Not Sarvam-level emotion — pace only.

### 5. Edge TTS (built-in, free) — In this app
- **What:** Microsoft Edge TTS, free, no key. Hindi voices hi-IN-SwaraNeural (female) / hi-IN-MadhurNeural (male).
- **Cost:** ₹0 — no key.
- **Install:** None — built in.
- **Mobile:** Yes. Needs internet; works where the Edge TTS service is reachable.
- **Use when:** Default free voice when no key is set.
- **Does NOT do:** Not guaranteed — it goes through a public proxy endpoint that can change.

### 6. Sarvam Bulbul (`voice_providers.dart`) — In this app
- **What:** 80+ Hindi voices, emotion-rich prosody, native Hinglish. Per-character voices + narrator voice, emotion via pace + voice style.
- **Cost:** ₹100 signup credits, then ₹20 / 10,000 chars (sarvam.ai, checked 24 Nov 2026).
- **Install:** Key needed: paste in Settings (AI Providers > TTS > Sarvam).
- **Mobile:** Yes. Cloud API — nothing runs on the phone.
- **Use when:** The publishable dubbing voice for a real video.
- **Does NOT do:** Not free forever — ₹100 covers ~50,000 chars (~40 min). A 2-hour video costs ~₹300.

### 7. Gemini TTS (`voice_providers.dart`) — In this app
- **What:** Gemini API TTS, 30 prebuilt voices, Hindi listed, `[laughs]`/`[whispers]` audio tags, style prompt carries the emotion.
- **Cost:** Free of charge on the free tier (Google AI Studio, checked 24 Nov 2026).
- **Install:** Key needed: paste in Settings (AI Providers > TTS > Gemini TTS).
- **Mobile:** Yes. Cloud API — nothing runs on the phone.
- **Use when:** Free emotional voice when Sarvam credits run out.
- **Does NOT do:** Not unlimited — free-tier rate limits are unpublished.

### 8. Deepgram Flux TTS (`voice_providers.dart`) — In this app
- **What:** Flux TTS Hindi voices (flux-arjun-hi, flux-anjali-hi, flux-divya-hi, …). REST: POST /v1/speak, Token auth. Aura-2 has NO Hindi — Flux only.
- **Cost:** Free $200 credit, no card, no expiry (deepgram.com/pricing, checked 24 Nov 2026). TTS billed per 1,000 chars.
- **Install:** Key needed: paste in Settings (AI Providers > TTS > Deepgram).
- **Mobile:** Yes. Cloud API — nothing runs on the phone.
- **Use when:** When you need real Hindi voices with a large free credit and no card.
- **Does NOT do:** NOT live-tested here (no key). No emotion parameter on the API. Commercial use: check Deepgram terms before monetised use.

### 9. Fish Audio S2.1 Pro (`voice_providers.dart`) — In this app
- **What:** S2.1 Pro TTS with inline direction tags (`[whispering]`, `[excited]`, `[laughing]`). Voice IDs are UUIDs from the Fish Audio voice library.
- **Cost:** Free Tier $0/mo: 8,000 credits/month (~7 min), 500 chars/generation (fish.audio/plan, checked 24 Nov 2026). S2.1 Pro Free API model free to call through 30 Nov 2026. Paid S2.1 Pro $15 / 1M UTF-8 bytes.
- **Install:** Key needed: paste in Settings (AI Providers > TTS > Fish Audio). Voice ID from the Fish Audio library.
- **Mobile:** Yes. Cloud API — nothing runs on the phone.
- **Use when:** When you want the most expressive free voice and can live with 500-char generations.
- **Does NOT do:** NOT live-tested here (no key). Free plan = personal, NON-COMMERCIAL use only. The free API model ends 30 Nov 2026.

### 10. MiniMax T2A — PAID ONLY, free NOT verified — In this app
- **What:** MiniMax speech-2.8-hd / speech-2.8-turbo TTS API (40 languages, 300+ system voices). Wired as a paid provider — it is NOT presented as free.
- **Cost:** NO free allowance published for speech synthesis on the official API pricing page (platform.minimax.io/docs/pricing/overview, checked 24 Nov 2026). speech-2.8-hd $100/M chars, speech-2.8-turbo $60/M chars.
- **Install:** Key needed: paste in Settings (AI Providers > TTS > MiniMax). Voice ID from the MiniMax console.
- **Mobile:** Yes. Cloud API — nothing runs on the phone.
- **Use when:** Only if you decide to pay for it — there is no free path on the API.
- **Does NOT do:** NOT free, NOT live-tested here. Do not present MiniMax as a free provider.

### 11. ElevenLabs (built-in) — quality test only — In this app
- **What:** Best raw voice quality, 1,000+ Hindi voices, emotion via voice_settings + audio tags.
- **Cost:** Free plan 10,000 credits/month (~10 min). Paid Starter from $6/mo (check the pricing page).
- **Install:** Key needed: paste in Settings (AI Providers > TTS > ElevenLabs). Voice IDs are UUIDs.
- **Mobile:** Yes. Cloud API.
- **Use when:** Judging voices / a short test — not a full video.
- **Does NOT do:** NO commercial licence on the Free plan — must not be used on a monetised video. ~10 min/month only.

### 12. Google Cloud TTS (built-in) — volume fallback — In this app
- **What:** 46 Hindi voices, emotion via SSML prosody (rate + pitch).
- **Cost:** 4M chars/month Standard/WaveNet, 1M Chirp 3 HD / Neural2 free — BUT billing must be enabled (check the pricing page).
- **Install:** Key needed + billing enabled on the Google Cloud project.
- **Mobile:** Yes. Cloud API.
- **Use when:** Only when the other providers are unavailable and billing is already on.
- **Does NOT do:** Never the default — it needs a card/billing enabled first.

### 13. Per-character voice pipeline (`character_voices.dart`) — In this app
- **What:** Every character keeps ONE voice per provider for the whole story; Narrator gets a separate voice; gender is recorded so a male character never gets a female voice. Scenes with no dialogue are explained by the narrator.
- **Cost:** ₹0 — a mapping, not a service.
- **Install:** None. Override voices in Settings.
- **Mobile:** Yes. Runs anywhere the pipeline runs.
- **Use when:** Every dubbing run.
- **Does NOT do:** Not a voice itself — it only picks which voice each provider uses.

---

## Video (6)

### 14. FFmpeg cinematic engine (`ffmpeg_service.dart`) — In this app
- **What:** The built-in renderer: Ken Burns zoom/pan on images, audio-image sync, scene concat, 720p-4K export. Every render ends in an FFmpegKit call.
- **Cost:** ₹0 — FFmpegKit ships inside the app.
- **Install:** None — bundled.
- **Mobile:** Yes. Runs on the phone; long videos take time and battery.
- **Use when:** Every video this app makes.
- **Does NOT do:** Not an editor UI and not a motion-graphics tool by itself — it assembles what the code draws.

### 15. Prompt-to-video (`prompt_video_service.dart`) — In this app
- **What:** Prompt in, reel/video out, ₹0. Code-drawn motion graphics (image package frames + FFmpeg zoompan/drawtext): 10 style presets, hook title, burned English subtitles, speaker/emotion chip, progress bar, narration + SFX mixed.
- **Cost:** ₹0 — no paid video API, no stock download.
- **Install:** None — built in. Voiceover uses the TTS provider set in Settings.
- **Mobile:** Yes. Renders on the phone; a 14s reel takes ~30s at 12 fps.
- **Use when:** Reels/Shorts from a one-line idea, without any source images.
- **Does NOT do:** Not real actors or AI-generated video clips — code-drawn motion graphics only.

### 16. HyperFrames (documented) — Guide
- **What:** HTML + CSS → MP4 with headless Chrome + FFmpeg. ~450 blocks, 10 templates. Composition only.
- **Cost:** ₹0 — Apache-2.0, open source (~70k GitHub stars).
- **Install:** `npx skills add heygen-com/hyperframes` (Node 22+). Not in this app.
- **Mobile:** No — needs Node + headless Chrome, not a phone tool.
- **Use when:** When you want a web-style composition rendered as video (desktop).
- **Does NOT do:** Does NOT generate images, video, or audio — composition only.

### 17. Remotion (documented) — Guide
- **What:** Video from React components, rendered locally.
- **Cost:** Free for individuals and for-profit companies up to 3 people; paid Company Licence for 4+ (check the Remotion licence page).
- **Install:** `npx create-video@latest` (Node 22+). Not in this app.
- **Mobile:** No — needs Node + local render, not a phone tool.
- **Use when:** Programmatic React-driven video on desktop.
- **Does NOT do:** Not installed here. Not free for a 4+ person company.

### 18. Manim Community (documented) — Guide
- **What:** Python animation engine for math / explainer videos (~42k GitHub stars, MIT).
- **Cost:** ₹0 — MIT, open source.
- **Install:** `pip install manim` (needs FFmpeg + OpenGL/LaTeX). Not in this app.
- **Mobile:** No — desktop render; LaTeX/OpenGL do not run on a phone.
- **Use when:** Explainer / educational animations, not story reels.
- **Does NOT do:** Not a story-video tool and not mobile.

### 19. Code-drawn frames (image package) — In this app
- **What:** Every prompt-to-video frame is drawn in Dart with the image package: gradients, text, particles, glow — the same idea as Pillow in the Python engine.
- **Cost:** ₹0 — image package is in pubspec.
- **Install:** None — bundled.
- **Mobile:** Yes. Pure Dart, runs on the phone.
- **Use when:** All code-drawn frames and thumbnails.
- **Does NOT do:** Not a video tool — it draws still frames; FFmpeg turns them into video.

---

## Editing (6)

### 20. Concat — join parts (`editing_service.dart`) — In this app
- **What:** Join MP4 parts in order, same codec/size, no re-encode (ffmpeg concat demuxer).
- **Cost:** ₹0.
- **Install:** None — bundled FFmpeg.
- **Mobile:** Yes. Runs on the phone.
- **Use when:** Assembling scene renders into one long video.
- **Does NOT do:** Not for clips of different sizes/codecs — re-encode first.

### 21. Fade in / out (`editing_service.dart`) — In this app
- **What:** Fade from black at the head and to black at the tail, video + audio.
- **Cost:** ₹0.
- **Install:** None — bundled FFmpeg.
- **Mobile:** Yes. Runs on the phone.
- **Use when:** Every finished video — clean open and close.
- **Does NOT do:** Not a crossfade between two clips — see crossfade.

### 22. Crossfade / transitions (`editing_service.dart`) — In this app
- **What:** Dissolve from clip A to clip B (xfade + acrossfade), 1s default.
- **Cost:** ₹0.
- **Install:** None — bundled FFmpeg.
- **Mobile:** Yes. Runs on the phone.
- **Use when:** Scene changes that should feel smooth, not a hard cut.
- **Does NOT do:** Not a fancy wipe — xfade transitions only.

### 23. Speed ramp (`editing_service.dart`) — In this app
- **What:** Change clip speed (setpts + atempo), 0.5x–100x.
- **Cost:** ₹0.
- **Install:** None — bundled FFmpeg.
- **Mobile:** Yes. Runs on the phone.
- **Use when:** Slow-mo drama or a fast montage.
- **Does NOT do:** Not frame-interpolated slow-mo — it duplicates/drops frames.

### 24. Text overlays (`editing_service.dart`) — In this app
- **What:** Burn one line of English text onto a video (drawtext).
- **Cost:** ₹0.
- **Install:** None — bundled FFmpeg.
- **Mobile:** Yes. Runs on the phone.
- **Use when:** Titles, hooks, and callouts burned into the video.
- **Does NOT do:** Not styled captions — for timed subtitles use the Subtitles skill.

### 25. End-screen card (`editing_service.dart`) — In this app
- **What:** Burns a "WATCH NEXT" + next-video title card onto the last 5 seconds. The end-screen rule in its simplest working form.
- **Cost:** ₹0.
- **Install:** None — bundled FFmpeg.
- **Mobile:** Yes. Runs on the phone.
- **Use when:** Every published video — the last seconds must send the viewer to the next part.
- **Does NOT do:** Not YouTube's clickable end-screen elements (set those in Studio too) — this is a burned-in card.

---

## Thumbnail (1)

### 26. Thumbnail generator (`thumbnail_service.dart`) — In this app
- **What:** 1280×720 YouTube thumbnail: big bold English text (≤5 words), accent colour per style, label chip, high-contrast outline, glow. One thumbnail per video.
- **Cost:** ₹0 — image package only.
- **Install:** None — bundled.
- **Mobile:** Yes. Runs on the phone.
- **Use when:** Every video — a thumbnail is made with the video, not after it.
- **Does NOT do:** Not a photo editor and not AI art — code-drawn gradient + text only. For a character face, add a real image on top in an editor.

---

## Subtitles (3)

### 27. SRT generation + re-timing (`subtitle_service.dart`) — In this app
- **What:** Hindi SRT re-timed for the longer Hindi audio (default factor 1.3×), plus an English SRT from the source text. Every sample ships its .srt.
- **Cost:** ₹0.
- **Install:** None — part of this app.
- **Mobile:** Yes. Plain text — works anywhere.
- **Use when:** Every video — subtitles are the accessibility + muted-viewing layer.
- **Does NOT do:** Not burned in by itself — see burn-in below.

### 28. Burned subtitles (`subtitle_service.dart` + ffmpeg) — In this app
- **What:** Subtitles drawn onto the frames (prompt-to-video burns the scene text) or via FFmpeg's subtitles filter from an .srt file. English on screen is the project rule.
- **Cost:** ₹0.
- **Install:** None — bundled FFmpeg.
- **Mobile:** Yes. Runs on the phone.
- **Use when:** Reels/Shorts — most viewers watch muted, so the text must be in the picture.
- **Does NOT do:** Not a caption file for YouTube upload — upload the .srt separately for that.

### 29. Hinglish vs English captions (documented rule) — Guide
- **What:** Default titles/descriptions are Hinglish (Hindi in English script) for Indian audiences, with the original English under the English translation; on-screen text and thumbnail text stay English.
- **Cost:** ₹0 — a rule, not software.
- **Install:** None.
- **Mobile:** Yes. A rule.
- **Use when:** Every publish pack (title, description, thumbnail, captions).
- **Does NOT do:** Not automatic — the writer picks the Hinglish wording per video.

---

## Music/SFX (2)

### 30. Synthesised SFX (`sfx_service.dart`) — In this app
- **What:** Rain, thunder, wind, heartbeat, chime, whoosh — synthesised by FFmpeg filters, no download, no licence, no cost. Picked from the prompt's mood. Add a new one by adding a branch in `sfxFilter`.
- **Cost:** ₹0 — bundled FFmpeg.
- **Install:** None — bundled.
- **Mobile:** Yes. Runs on the phone.
- **Use when:** Every video — SFX sit under the narration at low volume (-18 dB).
- **Does NOT do:** Not real recorded sound and not music — simple synthesised beds. For a real score, see the licensed-music note below.

### 31. Background music (honest note — no free magic here) — Guide
- **What:** Real background music still needs a licensed source: YouTube Audio Library (free, check the licence per track), or a paid library. There is no free, unlimited, commercial-use music generator in this app.
- **Cost:** ₹0 from the YouTube Audio Library (licence per track); paid libraries cost money.
- **Install:** Download the track yourself; mix it with FFmpeg (amix, low volume).
- **Mobile:** Yes. Mixing is FFmpeg — runs on the phone.
- **Use when:** When a video needs a real score, not just SFX.
- **Does NOT do:** Not included in this app, and not "free AI music" — do not use a random downloaded song on a monetised video.
