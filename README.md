<p align="center">
  <img src="https://raw.githubusercontent.com/Abhimanyuraj8252/Webkeyo/main/assets/readme/banner.png" alt="Webkeyo Banner" width="100%">
</p>

<h1 align="center">🚀 Webkeyo: The Ultimate AI Content Studio</h1>

<p align="center">
  <strong>The world's most powerful AI-driven pipeline to transform Manga, Manhwa, and Documents into Cinematic Narrated Videos.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/AI-Powered-FF6F61?style=for-the-badge" alt="AI Powered">
  <img src="https://img.shields.io/badge/Status-Production--Ready-green?style=for-the-badge" alt="Production Ready">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge" alt="License">
</p>

---

## 🌟 Overview

**Webkeyo** is a high-performance content creation engine that automates the entire lifecycle of video recap production. By combining **Advanced Vision AI**, **Neural TTS**, and **FFmpeg Rendering**, Webkeyo turns static assets into immersive storytelling experiences with zero manual effort.

## ✨ Features That Empower You

### 🧠 Intellectual Core (AI Pipeline)
- **Universal Vision Support**: Seamlessly switch between **Google Gemini 1.5**, **Groq Vision**, **OpenRouter**, and **OpenAI GPT-4o**.
- **Context-Aware Scripting**: AI that understands character relationships, plot twists, and visual nuances.
- **Auto-Character Detection**: Sophisticated analysis that identifies and describes characters to maintain narrative consistency.

### 🎙️ The Voice of Content (Advanced TTS)
- **Microsoft Edge TTS**: Access high-fidelity, natural-sounding neural voices for free.
- **Piper TTS (Offline)**: Blazing fast, local speech synthesis for privacy and speed.
- **Premium Integration**: Out-of-the-box support for **ElevenLabs**, **OpenAI TTS**, and **Google Cloud**.
- **New in v1.1.0 — Hindi-first voices**: **Sarvam Bulbul** (₹100 signup credit, 80+ Hindi voices, emotion-rich — the default Hindi voice), **Gemini TTS** (free tier, 30 voices, Hindi listed), **Deepgram Flux TTS** ($200 free credit, no card — Hindi voices like `flux-arjun-hi`; Aura-2 has no Hindi), **Fish Audio S2.1 Pro** (free tier 8,000 credits/month, personal non-commercial use only), and **MiniMax T2A — PAID ONLY** (no free allowance published; never presented as free). Every character keeps one voice per provider for the whole story; the narrator gets a separate voice; scenes with no dialogue are explained by the narrator. Keys go in Settings only — never in code.
- **Multi-Language Mastery**: Full support for Hindi (Devanagari), English, Japanese, and 15+ other languages.

### 🎬 Prompt-to-Video (new in v1.1.0)
- **One line in, reel out — ₹0**: Home → **Prompt Video**. A prompt becomes a vertical (9:16) or horizontal (16:9) video with code-drawn motion graphics — 10 style presets, hook title, burned English subtitles, speaker/emotion chip, progress bar, narration + synthesised SFX (rain, thunder, wind, heartbeat, chime, whoosh — no downloads, no licence). No paid video API, no stock footage.
- **Skills Library**: Home → **Skills** lists all 31 skills across 7 stages (Script, Voicing, Video, Editing, Thumbnail, Subtitles, Music/SFX) — what each does, what it costs, how to install it, whether it works on a phone. Same list in [SKILLS.md](SKILLS.md).
- **Samples**: Home → **Samples** has one ready prompt per genre — tap to render it.
- **Editing helpers** (FFmpeg, no paid editor): concat, fade in/out, crossfade, speed ramp, text overlays, end-screen card.
- **Thumbnails + subtitles**: a 1280×720 thumbnail is generated with every video; Hindi SRT re-timed for the longer Hindi audio (1.3×) plus an English SRT.

### 🎬 Professional Studio (Rendering & Editing)
- **FFmpeg Cinematic Engine**: High-performance rendering with perfect audio-image synchronization.
- **Intelligent Cropping**: Automatic "YouTube-Fit" logic to ensure your content looks great on any screen.
- **Interactive Script Editor**: Real-time script refinement with JSON validation and manual injection.
- **Source Management**: Native support for `.cbz`, `.zip`, `.pdf`, and raw image directories.

---

## 🏗️ Technical Architecture

```mermaid
graph TD
    A[Source: CBZ/PDF/Images] -- Extract --> B[Asset Library]
    B -- Vision Analysis --> C[AI Pipeline: Groq/Gemini/OpenRouter]
    C -- Script Gen --> D[JSON Script Engine]
    D -- Narration --> E[TTS Engine: Edge/Piper/Premium]
    E -- Audio Sync --> F[FFmpeg Rendering Core]
    B -- Image Sync --> F
    F -- Export --> G[4K Cinematic Video]
```

---

## 🚀 Installation & Setup

### Prerequisites
- **Flutter SDK**: 3.22.0+
- **FFmpeg**: Must be available in system PATH or bundled with the binary.
- **Hardware**: Android 10+ or iOS 15+ recommended for optimal rendering.

### Quick Start
```bash
# Clone the repository
git clone https://github.com/Abhimanyuraj8252/Webkeyo.git

# Install dependencies
flutter pub get

# Run the app
flutter run --release
```

## ⚙️ Configuration
1. Open the app and head to **Settings** -> **AI Providers**.
2. Configure your API keys for **Groq** (Fastest), **Gemini** (Highest Accuracy), or **OpenRouter**.
3. Create a new project, select your source file, and watch the magic happen.

---

## 🤝 Community & Support
- **Issues**: Found a bug? Open an issue on GitHub.
- **Discussions**: Want a new feature? Start a discussion!
- **Star the Repo**: If you love Webkeyo, give it a ⭐!

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Built with ❤️ by <a href="https://github.com/Abhimanyuraj8252">Abhimanyu Raj</a><br>
  <i>Empowering creators with AI-driven automation.</i>
</p>
