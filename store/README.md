# Webkeyo — store assets

## What is here

- `feature-graphic.png` — 1024×500, real generated graphic (app name +
  tagline). Safe to use as the Play Store feature graphic.
- `screenshots/01..06.png` — 1080×1920 **PLACEHOLDERS**. Each image says
  "PLACEHOLDER — replace with a real screenshot" on it. They exist so
  the folder structure and the README links are complete; **do not
  upload them to the Play Store as if they were real screenshots**.
- `short-description.txt` — 80 characters max (Play Store short
  description).
- `full-description.txt` — Play Store full description.
- `generate_assets.py` — the script that made the graphic + placeholders
  (Pillow). Re-run it after editing.

## How to replace the placeholders with real screenshots

1. Install the release APK on a phone (1080×1920 or higher).
2. Capture each screen in the app:
   - `01-home.png` — Home: streak header, templates row, trending row,
     project list.
   - `02-prompt-video.png` — Prompt Video screen with a prompt typed in.
   - `03-voice-picker.png` — Onboarding step 2, "Pick your voice".
   - `04-templates.png` — One-tap reels row (Haunted Night, Love Story…).
   - `05-render.png` — Pipeline progress screen mid-render (progress +
     Cancel button visible).
   - `06-share.png` — Prompt Video result screen with the Share button.
3. Crop/resize to exactly **1080×1920** (portrait).
4. Overwrite the files in `screenshots/` with the same names.
5. Update the README screenshot section to point at the real captures.

## Play Store checklist (before first listing)

- [ ] Real screenshots (6–8) as above
- [ ] Feature graphic (done)
- [ ] App icon 512×512 (use `assets/logo.png` as the source)
- [ ] Privacy Policy URL — host PRIVACY.md (e.g. on the landing page)
- [ ] Content rating questionnaire
- [ ] Release APK signed with the release key (the repo builds
      debug-signed by default — see README "Release build")
