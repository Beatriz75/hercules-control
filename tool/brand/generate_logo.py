"""Generates the Hércules Control logo (SVG + PNG icons) from one geometry.

Run from the repo root:  python tool/brand/generate_logo.py
Outputs: assets/brand/*.svg, assets/brand/logo_512.png, web/favicon.png, web/icons/*.png
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]

NAVY = "#0E2A47"
NAVY_DEEP = "#081B30"
GOLD = "#C9A227"
GOLD_LIGHT = "#E3C15A"
WHITE = "#FFFFFF"

# Geometry on a 512 x 512 canvas.
SHIELD = [(96, 72), (416, 72), (416, 250)]  # then curves down to (256, 456) and back up
COLUMNS = [
    # (shaft x0, x1) — capital and base stick out 12 px each side
    (168, 212),
    (300, 344),
]
SHAFT_TOP, SHAFT_BOTTOM = 172, 356
CAPITAL = (148, 172)  # y range of the capital (top block)
BASE = (356, 380)  # y range of the base (bottom block)
LINTEL = (212, 300, 246, 280)  # x0, x1, y0, y1 — the bar joining both columns


def _cubic(p0, p1, p2, p3, steps=40):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1 - t
        x = mt**3 * p0[0] + 3 * mt**2 * t * p1[0] + 3 * mt * t**2 * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt**2 * t * p1[1] + 3 * mt * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def shield_points(inset=0.0):
    left, right, top = 96 + inset, 416 - inset, 72 + inset
    bottom = 456 - inset * 1.25
    side = 250
    pts = [(left, top), (right, top), (right, side)]
    pts += _cubic((right, side), (right, 352 - inset * 0.5), (344 - inset * 0.6, 420 - inset), (256, bottom))[1:]
    pts += _cubic((256, bottom), (168 + inset * 0.6, 420 - inset), (left, 352 - inset * 0.5), (left, side))[1:]
    return pts


def h_rects():
    rects = []
    for x0, x1 in COLUMNS:
        rects.append((x0, SHAFT_TOP, x1, SHAFT_BOTTOM))  # shaft
        rects.append((x0 - 12, CAPITAL[0], x1 + 12, CAPITAL[1]))  # capital
        rects.append((x0 - 12, BASE[0], x1 + 12, BASE[1]))  # base
    x0, x1, y0, y1 = LINTEL
    rects.append((x0, y0, x1, y1))
    return rects


def flutes():
    # Two grooves per shaft, drawn in navy over the gold column.
    lines = []
    for x0, x1 in COLUMNS:
        third = (x1 - x0) / 3
        for k in (1, 2):
            x = x0 + third * k
            lines.append((x - 2.5, SHAFT_TOP + 10, x + 2.5, SHAFT_BOTTOM - 10))
    return lines


# ---------- SVG ----------

def _path(points):
    head, *rest = points
    return f"M{head[0]:.1f} {head[1]:.1f} " + " ".join(f"L{x:.1f} {y:.1f}" for x, y in rest) + " Z"


def svg_mark(size=512, background=None):
    bg = f'<rect width="512" height="512" fill="{background}"/>' if background else ""
    rects = "".join(
        f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}" rx="3"/>' for x0, y0, x1, y1 in h_rects()
    )
    grooves = "".join(
        f'<rect x="{x0:.1f}" y="{y0}" width="{x1 - x0:.1f}" height="{y1 - y0}" rx="2.5"/>' for x0, y0, x1, y1 in flutes()
    )
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="{size}" height="{size}" role="img" aria-label="Hércules Control">
  {bg}
  <path d="{_path(shield_points())}" fill="{NAVY}"/>
  <path d="{_path(shield_points(14))}" fill="none" stroke="{GOLD}" stroke-width="6"/>
  <g fill="{GOLD}">{rects}</g>
  <g fill="{NAVY}">{grooves}</g>
</svg>
'''


def svg_wordmark():
    mark = svg_mark().split("\n", 1)[1].rsplit("</svg>", 1)[0]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1500 512" width="1500" height="512" role="img" aria-label="Hércules Control">
  <g>{mark}</g>
  <text x="560" y="270" font-family="Montserrat, 'Segoe UI', Arial, sans-serif" font-size="150" font-weight="800" fill="{NAVY}" letter-spacing="4">HÉRCULES</text>
  <text x="566" y="390" font-family="Montserrat, 'Segoe UI', Arial, sans-serif" font-size="92" font-weight="600" fill="{GOLD}" letter-spacing="38">CONTROL</text>
</svg>
'''


# ---------- PNG ----------

def png_mark(size, background=None, padding=0.0):
    scale = 4  # supersampling for smooth edges
    canvas = size * scale
    img = Image.new("RGBA", (canvas, canvas), background or (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    usable = canvas * (1 - 2 * padding)
    k = usable / 512
    off = canvas * padding

    def tr(points):
        return [(off + x * k, off + y * k) for x, y in points]

    draw.polygon(tr(shield_points()), fill=NAVY)
    draw.line(tr(shield_points(14)) + tr(shield_points(14))[:1], fill=GOLD, width=max(1, round(6 * k)), joint="curve")
    for x0, y0, x1, y1 in h_rects():
        (a, b), (c, d) = tr([(x0, y0), (x1, y1)])
        draw.rounded_rectangle((a, b, c, d), radius=3 * k, fill=GOLD)
    for x0, y0, x1, y1 in flutes():
        (a, b), (c, d) = tr([(x0, y0), (x1, y1)])
        draw.rounded_rectangle((a, b, c, d), radius=2.5 * k, fill=NAVY)
    return img.resize((size, size), Image.LANCZOS)


def main():
    brand = ROOT / "assets" / "brand"
    brand.mkdir(parents=True, exist_ok=True)
    (brand / "logo_mark.svg").write_text(svg_mark(), encoding="utf-8")
    (brand / "logo_wordmark.svg").write_text(svg_wordmark(), encoding="utf-8")
    png_mark(512).save(brand / "logo_512.png")

    web = ROOT / "web"
    (web / "favicon.svg").write_text(svg_mark(), encoding="utf-8")
    png_mark(64).save(web / "favicon.png")
    icons = web / "icons"
    png_mark(192, background=WHITE, padding=0.06).save(icons / "Icon-192.png")
    png_mark(512, background=WHITE, padding=0.06).save(icons / "Icon-512.png")
    # Maskable icons: keep the mark inside the 80% safe zone on a navy field.
    png_mark(192, background=NAVY_DEEP, padding=0.16).save(icons / "Icon-maskable-192.png")
    png_mark(512, background=NAVY_DEEP, padding=0.16).save(icons / "Icon-maskable-512.png")
    print("logo generado en", brand, "y", web)


if __name__ == "__main__":
    main()
