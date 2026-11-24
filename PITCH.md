# Webkeyo — Pitch

> **A 2-hour Hindi story costs ~₹35 of voice with Webkeyo. Studio dubbing costs ₹10,000+.**

## Problem

Hindi is spoken by 300M+ people, and Hindi story / manhwa YouTube is exploding — but making a good Hindi story video still needs a studio: a voice artist for every character, an editor, a thumbnail designer, and days of work. A single 2-hour story costs ₹10,000+ to dub. Small creators — the ones with the stories — cannot afford it, so they post still images with robotic text-to-speech, and viewers leave.

## Solution

Webkeyo is a mobile app that turns manga, manhwa, PDFs and documents — or just one line of an idea — into a cinematic narrated Hindi video in minutes:

1. **Upload** a manga / manhwa / PDF / folder of images, or type one line.
2. **Pick a voice.** Every character automatically gets a distinct male/female voice matching the character, with real emotion. The narrator explains scenes with no dialogue.
3. **Render.** Code-drawn motion graphics (no stock footage, no flat stills), sound effects, subtitles, karaoke captions and a thumbnail — on the phone.

## Why now

- Hindi story YouTube is growing fast, and no incumbent is Hindi-first *and* mobile-first.
- Voice AI just got cheap enough: Google Cloud WaveNet gives 4M characters/month free (~83 hours), Amazon Polly 5M/month free for a year, Speechify 500K/month free, Azure SwaraNeural 0.5M/month free with real acted emotion styles. The economics flipped in 2025–26 — the voice for a 2-hour story is now ~₹35.
- Phones are the studio: a ₹20–25k phone with 6 GB RAM can now render a full video locally with FFmpeg.

## The disruptive edge

- **Mobile-first, Hindi-first.** Desktop tools and English-first apps do not serve the creator who shoots, edits and uploads from one phone.
- **Emotional multi-voice Hindi at near-zero cost.** Not one robotic voice — a cast, with acted emotion (Azure SwaraNeural styles, Sarvam, Deepgram Flux Hindi voices).
- **Code-drawn motion graphics.** Every frame is drawn in code — characters, phones, text, particles — so videos are premium, unique and hard to copy. No stock footage, no licence fees, no flat stills.
- **Free to start.** Edge TTS needs no key at all; the other providers have real free tiers. A creator can publish their first video without paying anything.

## Business model

- **Free tier:** everything today — all 10 styles, all templates, all free-tier voices, unlimited local renders.
- **Paid tier (planned):** a fair monthly plan for heavy creators (more cloud-voice minutes, premium voices, priority rendering). Usage is already counted locally (BillingService) so the free allowance can be shown honestly before anyone pays.
- **No ads, no selling data.** There is no server and no data to sell — projects and keys stay on the phone.

## Market

- 300M+ Hindi speakers; Hindi YouTube story channels routinely reach millions of views per video.
- Adjacent markets: manhwa/manga recap channels (English, Spanish, Portuguese), study explainers, audiobook-style narration.
- The wedge is Hindi story creators on YouTube — the fastest-growing, worst-served segment.

## Traction plan

1. Ship v1.2.0 (this release): onboarding, templates, trending, streaks, one-tap share — the retention loop that makes creators come back daily.
2. Publish the APK on GitHub Releases + Play Store listing (assets in `store/`).
3. Dogfood: render the AIN - KAGEWEB Hindi story pipeline with it; publish the results.
4. Creator outreach: 10 Hindi story YouTubers render one video each with Webkeyo; measure watch time vs their current workflow.
5. Paid tier only after 1,000 weekly active creators — the free tier must prove retention first.

## What we need

- Feedback from Hindi story creators (the app is free — try it, break it, tell us).
- Distribution: Play Store featuring, creator partnerships.
- Later: funding to add cloud rendering for low-end phones and a template community (both deferred — they need a backend, and the app is local-first by design today).

## The team

Abhimanyu Raj (Trikrypta) — full-stack developer, 3 years building for the web, runs the Hindi story-video channel AIN - KAGEWEB. He builds the tool he needs himself, every day.

## Numbers that matter (verified 24 Nov 2026, official pricing pages)

| Provider | Free tier | Paid rate |
|---|---|---|
| Google Cloud TTS WaveNet | 4M chars/month (~83 hrs) | ~₹17/hr |
| Amazon Polly Standard | 5M chars/month, first 12 months (~104 hrs) | ~₹17/hr |
| Speechify Simba | 500K chars/month (~10 hrs) | ~₹21/hr effective (Starter $10/mo) |
| Azure AI Speech (SwaraNeural, real emotion) | 0.5M neural chars/month (~10 hrs) | ~₹63/hr |
| Deepgram Flux TTS | $200 free credit, no card | — |
| Edge TTS | Free, no key | — |

Math: ~800 characters per minute of speech = 48,000 characters per hour. ₹88 = $1.
A 2-hour story ≈ 96,000 characters ≈ ₹35 on WaveNet paid rate — and ₹0 inside the free tier.
