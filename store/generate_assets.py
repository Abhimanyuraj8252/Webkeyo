"""Generate Webkeyo store assets (v1.2.0).

- store/feature-graphic.png — 1024x500, real generated graphic (dark
  cinematic, app name + tagline). This is a genuine graphic, not a
  screenshot.
- store/screenshots/01..06.png — 1080x1920 PLACEHOLDERS, clearly
  labelled "PLACEHOLDER — replace with a real screenshot" in the image
  itself. They are never to be presented as real screenshots; the
  store/README.md in the same folder documents the exact specs for
  replacing them with real captures from the app.
"""
from PIL import Image, ImageDraw, ImageFont

DARK = (10, 10, 26)
PURPLE = (124, 77, 255)
CYAN = (0, 229, 255)
WHITE = (255, 255, 255)
GREY = (160, 160, 180)
MID = (30, 30, 55)


def font(size, bold=False):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def centre(draw, y, text, f, fill, width):
    box = draw.textbbox((0, 0), text, font=f)
    draw.text(((width - (box[2] - box[0])) / 2, y), text, font=f, fill=fill)
    return y + (box[3] - box[1]) + 12


# --- Feature graphic 1024x500 ---
img = Image.new("RGB", (1024, 500), DARK)
d = ImageDraw.Draw(img)
for i in range(500):
    d.line([(0, i), (1024, i)], fill=(10 + i // 25, 10 + i // 30, 26 + i // 12))
d.ellipse([380, 60, 644, 324], outline=PURPLE, width=6)
d.ellipse([420, 100, 604, 284], outline=CYAN, width=3)
y = 150
y = centre(d, y, "WEBKEYO", font(96, True), WHITE, 1024)
y = centre(d, y, "Manga, manhwa & PDFs  ->  cinematic Hindi videos",
           font(30), CYAN, 1024)
y = centre(d, y, "Emotional multi-voice Hindi  |  Free to start",
           font(26), GREY, 1024)
img.save("/home/hatch/workspace/webkeyo/store/feature-graphic.png")
print("feature-graphic.png saved")

# --- Placeholder screenshots 1080x1920 ---
screens = [
    ("01-home.png", "Home", "Streak, templates, trending & projects"),
    ("02-prompt-video.png", "Prompt Video", "One line in, reel out"),
    ("03-voice-picker.png", "Pick a voice", "Onboarding — free providers first"),
    ("04-templates.png", "One-tap reels", "Haunted Night, Love Story, ..."),
    ("05-render.png", "Rendering", "Progress + cancel, notification"),
    ("06-share.png", "Share", "One tap to YouTube / Instagram"),
]
for fname, title, subtitle in screens:
    im = Image.new("RGB", (1080, 1920), MID)
    dr = ImageDraw.Draw(im)
    dr.rectangle([60, 60, 1020, 1860], outline=PURPLE, width=4)
    y = 700
    y = centre(dr, y, title, font(72, True), WHITE, 1080)
    y = centre(dr, y, subtitle, font(36), CYAN, 1080)
    y += 60
    y = centre(dr, y, "PLACEHOLDER", font(48, True), (255, 80, 80), 1080)
    y = centre(dr, y, "Replace with a real screenshot", font(32), GREY, 1080)
    y = centre(dr, y, "from the app (see store/README.md)", font(32), GREY, 1080)
    im.save(f"/home/hatch/workspace/webkeyo/store/screenshots/{fname}")
    print(fname, "saved")
print("done")
