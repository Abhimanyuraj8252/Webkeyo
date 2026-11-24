<p align="center">
  <img src="https://raw.githubusercontent.com/Abhimanyuraj8252/Webkeyo/main/assets/readme/banner.png" alt="Webkeyo Banner" width="100%">
</p>

<h1 align="center">Webkeyo: Manga, Manhwa & PDFs → Cinematic Hindi Videos</h1>

<p align="center">
  <strong>Turn manga, manhwa, PDFs and documents — or just one line of an idea — into a cinematic narrated Hindi video, on your phone.</strong>
</p>

<p align="center">
  <a href="https://github.com/Abhimanyuraj8252/Webkeyo/releases"><img src="https://img.shields.io/badge/Download-APK-green?style=for-the-badge" alt="Download APK"></a>
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter">
  <img src="https://github.com/Abhimanyuraj8252/Webkeyo/actions/workflows/ci.yml/badge.svg" alt="CI">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge" alt="License">
</p>

<p align="center">
  <strong>Download the APK:</strong> <a href="https://github.com/Abhimanyuraj8252/Webkeyo/releases">GitHub Releases</a> — pick the APK for your device (<code>arm64-v8a</code> for most modern phones). No Play Store account needed.
</p>

---

## 💰 What it costs

A **2-hour Hindi story costs ~₹35 of voice** with Webkeyo — versus **₹10,000+ for studio dubbing**. And ₹0 inside the free tiers.

| Voice provider | Free tier (official pricing pages, 24 Nov 2026) | Paid rate |
|---|---|---|
| Google Cloud TTS WaveNet | 4M chars/month (~83 hrs) — billing/card must be enabled | ~₹17/hr |
| Amazon Polly Standard | 5M chars/month, first 12 months (~104 hrs) | ~₹17/hr |
| Speechify Simba | 500K chars/month (~10 hrs) | ~₹21/hr effective (Starter $10/mo = 2M chars) |
| Azure AI Speech | 0.5M neural chars/month (~10 hrs) — SwaraNeural has **real emotion styles** (cheerful, empathetic, newscast) | ~₹63/hr |
| Deepgram Flux TTS | $200 free credit, no card, no expiry | — |
| Sarvam Bulbul | Free trial credits, 80+ Hindi voices, emotion-rich | — |
| Gemini TTS | Free tier (Google AI Studio) — Google publishes no per-project request limits, so treat it as previews / short clips only | — |
| Edge TTS | Free, no key | — |

Math: ~800 characters per minute of speech = 48,000 characters per hour. ₹88 = $1.

> **Honest notes:** MiniMax T2A is **paid-only** (no free allowance published — never presented as free). OpenAI TTS (tts-1 / gpt-4o-mini-tts) **shut down 6 Jan 2027** — the app refuses it with a clear message instead of calling a dead API. Kokoro is cheap (~₹3/hr) but has **no emotion control** — it is not presented as emotional. Gemini's preview TTS model was replaced with `gemini-2.5-flash-tts` (the preview shuts down 18 Dec 2026).

## ✨ Features

### 🎙️ Voices — a cast, not one robot
- Every character automatically gets a distinct male/female voice matching the character, with real emotion; the narrator explains scenes with no dialogue.
- Providers (keys go in Settings only — never in code): Sarvam Bulbul, Gemini TTS, Deepgram Flux, Fish Audio, Google Cloud WaveNet, Amazon Polly (SigV4 built in), Speechify Simba (model picker: simba-3.5 for Hindi, simba-3.2 is English-only), Azure AI Speech (SwaraNeural emotion styles), ElevenLabs, Edge TTS (free, no key), Piper TTS (via your own server — the README's old "(Offline)" label was wrong for the current code), Flutter TTS.
- No gTTS anywhere (robotic — rejected). Silent audio is never presented as voiceover.

### 🎬 Prompt-to-Video
- **One line in, reel out — ₹0**: Home → **Prompt Video**. A prompt becomes a vertical (9:16) or horizontal (16:9) video with code-drawn motion graphics — 10 style presets, hook title, burned English subtitles, speaker/emotion chip, progress bar, narration + synthesised SFX (rain, thunder, wind, heartbeat, chime, whoosh — no downloads, no licence). No paid video API, no stock footage.
- **Karaoke captions**: word-by-word highlight captions (`.ass`, burn-in with FFmpeg) — toggle it on the Prompt Video screen.
- **Skills Library**: Home → **Skills** lists all 31 skills across 7 stages (Script, Voicing, Video, Editing, Thumbnail, Subtitles, Music/SFX) — what each does, what it costs, how to install it, whether it works on a phone. Same list in [SKILLS.md](SKILLS.md).
- **Samples**: Home → **Samples** has one ready prompt per genre — tap to render it.

### 🎨 One-tap reels & retention (new in v1.2.0)
- **One-tap reel templates**: the 10 styles as named templates — Haunted Night, Love Story, Revenge Comeback, Anime Premium, Cyber Hack, Motivation, Nature Tale, Royal Drama, Retro Nostalgia, Minimal Quote.
- **Trending this week**: a row driven by local JSON (`assets/data/trending.json`, updated per release — no server, no tracking).
- **Daily creation streak + achievements + creator levels**: streak flame, badges ("First reel", "10 reels", "7-day streak"), XP per export (Level 1 Newcomer → Level 5 Studio). All local.
- **Remix**: duplicate any project as a template and re-render it with a different voice or style.
- **One-tap share**: share sheet + caption + hashtags copied, ready to paste in YouTube / Instagram.
- **Daily reminder**: a local notification (no server) you turn on in Settings.

### 🧠 AI pipeline
- **Vision**: Google Gemini 2.5, Groq Vision, OpenRouter, OpenAI GPT-4o.
- **Context-aware scripting**: AI that understands character relationships, plot twists and visual nuances.
- **Auto-character detection**: face detection (one detector, reused, always closed) that identifies and describes characters to maintain narrative consistency.

### 🎬 Professional studio (rendering & editing)
- **FFmpeg cinematic engine**: high-performance rendering with audio-image sync. Renders show a progress notification and have a **Cancel** button — the in-flight session is cancelled and intermediate files are cleaned up.
- **YouTube-Fit cropping**: automatic cropping so the video looks right on any screen.
- **Interactive script editor**: real-time refinement with JSON validation and manual injection.
- **Source management**: native support for `.cbz`, `.zip`, `.pdf` and raw image directories.
- **Editing helpers** (FFmpeg, no paid editor): concat, fade in/out, crossfade, speed ramp, text overlays, end-screen card.
- **Thumbnails + subtitles**: a 1280×720 thumbnail is generated with every video; Hindi SRT re-timed for the longer Hindi audio (1.3×) plus an English SRT.

### 📱 Built for low-end phones
Reference device: ₹20–25k phone, 6 GB RAM, Dimensity 900-class. Images are decoded at display size (`cacheWidth`/`cacheHeight`), the home screen is split into small `const` widgets, the app shows a splash screen with startup timeouts (a hang never means a black screen), and lists show skeleton/shimmer loading states. APKs are split per ABI (`--split-per-abi`) — arm64-v8a first, target ~60–80 MB (the v1.1.0 fat APK was 266 MB).

### 🔒 Privacy
Your projects and API keys stay on your phone. Keys are sent only to the provider you chose. No account, no ads, no server. Crash reporting (Sentry, free tier) is off unless a DSN is passed at build time. See [PRIVACY.md](PRIVACY.md) and [TERMS.md](TERMS.md) — both are also linked in-app under Settings → About.

## 📸 Screenshots

The store screenshots in `store/screenshots/` are **placeholders** (labelled as such in the images) until real captures are taken — see `store/README.md` for the exact specs. The feature graphic (`store/feature-graphic.png`, 1024×500) is a real generated graphic.

## 🚀 Installation & Setup

### For users — install the APK
1. Open [GitHub Releases](https://github.com/Abhimanyuraj8252/Webkeyo/releases).
2. Download the APK for your device (`arm64-v8a` for most modern phones).
3. Install it (allow "Install unknown apps" for your browser if asked).
4. Open the app — the 3-step onboarding shows what it does, lets you pick a voice, and renders a short demo. No key needed to try it (Edge TTS is free).

### For developers — build from source
```bash
# Clone the repository
git clone https://github.com/Abhimanyuraj8252/Webkeyo.git

# Install dependencies
flutter pub get

# Run the app
flutter run --release

# Release build (per-ABI split APKs, arm64-v8a first, ~60-80 MB each)
flutter build apk --split-per-abi --release

# Optional: enable Sentry crash reporting (free tier)
flutter build apk --split-per-abi --release --dart-define=SENTRY_DSN=https://YOUR_DSN@o0.ingest.sentry.io/0
```

Prerequisites: Flutter SDK 3.22.0+, Android SDK with NDK 28, JDK 21. CI runs `flutter analyze` + `flutter test` on every push and pull request (`.github/workflows/ci.yml`).

## ⚙️ Configuration
1. Open the app and head to **Settings** → **AI Providers**.
2. Paste your API keys (Groq, Gemini, Sarvam, Google Cloud, Polly, Speechify, Azure…). Each provider tile shows its verified free tier and cost, and where to get the key.
3. Create a project, select your source file, and watch it render.

## 🗺️ Roadmap
- [x] v1.1.0 — 10 styles, 31 skills, Hindi-first voices, prompt-to-video
- [x] v1.2.0 — WaveNet / Polly / Speechify / Azure voices, onboarding, templates, trending, streaks, karaoke captions, one-tap share, per-ABI APKs, LICENSE + CI + privacy/terms
- [ ] Play Store listing (assets in `store/`, real screenshots pending)
- [ ] Cloud rendering for the lowest-end phones
- [ ] Template community (needs a backend — deferred by design; the app is local-first today)
- [ ] Paid tier (only after 1,000 weekly active creators; free tier stays free — usage is already counted locally so the allowance can be shown honestly)

## 🤝 Community & Support
- **Issues**: Found a bug? Open an issue on GitHub.
- **Discussions**: Want a new feature? Start a discussion!
- **Star the Repo**: If you love Webkeyo, give it a ⭐!

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Built with ❤️ by <a href="https://github.com/Abhimanyuraj8252">Abhimanyu Raj</a> (Trikrypta)<br>
  <i>Manga, manhwa & PDFs → cinematic Hindi videos.</i>
</p>
