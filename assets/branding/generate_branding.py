# Script written by Gemini to generate QR Jukebox branding assets

import math
from PIL import Image, ImageDraw

def draw_cd_qr_graphic(draw, center_x, center_y, size, is_monochrome=False):
    cx, cy = center_x, center_y
    r_outer = size * 0.38
    r_inner = size * 0.10
    r_ring1 = size * 0.28
    r_ring2 = size * 0.20

    if is_monochrome:
        disc_color = (255, 255, 255, 40)
        disc_outline = (255, 255, 255, 255)
        ring_color = (255, 255, 255, 60)
        center_ring_color = (255, 255, 255, 255)
        qr_accent = (255, 255, 255, 255)
        qr_sub_accent = (255, 255, 255, 255)
        hole_bg = (0, 0, 0, 0)
    else:
        disc_color = (28, 25, 42, 255)
        disc_outline = (168, 85, 247, 230) # #A855F7
        ring_color = (255, 255, 255, 35)
        center_ring_color = (168, 85, 247, 255)
        qr_accent = (168, 85, 247, 255)
        qr_sub_accent = (192, 132, 252, 255)
        hole_bg = (20, 18, 28, 255)

    # CD Disc Outer
    draw.ellipse(
        [cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer],
        fill=disc_color,
        outline=disc_outline,
        width=max(2, int(size * 0.010))
    )

    # CD Rings
    draw.ellipse(
        [cx - r_ring1, cy - r_ring1, cx + r_ring1, cy + r_ring1],
        outline=ring_color,
        width=max(1, int(size * 0.005))
    )
    draw.ellipse(
        [cx - r_ring2, cy - r_ring2, cx + r_ring2, cy + r_ring2],
        outline=ring_color,
        width=max(1, int(size * 0.004))
    )

    # CD Inner Hole
    draw.ellipse(
        [cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner],
        fill=hole_bg,
        outline=center_ring_color,
        width=max(2, int(size * 0.012))
    )

    # QR Finder Patterns
    def draw_qr_finder(x, y, box_size):
        stroke = box_size * 0.18
        r_out = box_size * 0.22
        r_in = box_size * 0.12
        draw.rounded_rectangle(
            [x, y, x + box_size, y + box_size],
            radius=r_out,
            outline=qr_accent,
            width=int(stroke)
        )
        inner_margin = stroke * 1.5
        draw.rounded_rectangle(
            [x + inner_margin, y + inner_margin, x + box_size - inner_margin, y + box_size - inner_margin],
            radius=r_in,
            fill=qr_accent
        )

    qr_size = size * 0.24
    draw_qr_finder(cx - size * 0.36, cy - size * 0.36, qr_size) # Top-Left
    draw_qr_finder(cx + size * 0.12, cy - size * 0.36, qr_size) # Top-Right
    draw_qr_finder(cx - size * 0.36, cy + size * 0.12, qr_size) # Bottom-Left

    # QR Module Dots
    dot_size = size * 0.045
    dot_r = dot_size * 0.35
    dots_pos = [
        (cx - size * 0.06, cy - size * 0.34),
        (cx + size * 0.02, cy - size * 0.34),
        (cx - size * 0.34, cy - size * 0.06),
        (cx - size * 0.34, cy + size * 0.02),
        (cx + size * 0.14, cy - size * 0.08),
        (cx + size * 0.22, cy - size * 0.08),
        (cx - size * 0.08, cy + size * 0.14),
        (cx - size * 0.08, cy + size * 0.22),
    ]

    for dx, dy in dots_pos:
        draw.rounded_rectangle(
            [dx, dy, dx + dot_size, dy + dot_size],
            radius=dot_r,
            fill=qr_sub_accent
        )

def generate_branding():
    canvas = 2048

    # 1. Main Legacy App Icon (1024x1024 full squircle)
    img_icon = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw_icon = ImageDraw.Draw(img_icon)
    bg_margin = canvas * 0.04
    bg_radius = canvas * 0.22
    bg_color = (20, 18, 28, 255)
    draw_icon.rounded_rectangle(
        [bg_margin, bg_margin, canvas - bg_margin, canvas - bg_margin],
        radius=bg_radius,
        fill=bg_color
    )
    draw_cd_qr_graphic(draw_icon, canvas / 2, canvas / 2, canvas * 0.9, is_monochrome=False)
    img_icon.resize((1024, 1024), Image.Resampling.LANCZOS).save("assets/branding/app_icon.png")

    # 2. Adaptive Foreground
    img_fg = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw_fg = ImageDraw.Draw(img_fg)
    draw_cd_qr_graphic(draw_fg, canvas / 2, canvas / 2, canvas * 0.55, is_monochrome=False)
    img_fg.resize((1024, 1024), Image.Resampling.LANCZOS).save("assets/branding/app_icon_foreground.png")

    # 3. Adaptive Monochrome
    img_mono = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw_mono = ImageDraw.Draw(img_mono)
    draw_cd_qr_graphic(draw_mono, canvas / 2, canvas / 2, canvas * 0.55, is_monochrome=True)
    img_mono.resize((1024, 1024), Image.Resampling.LANCZOS).save("assets/branding/app_icon_monochrome.png")

    # 4. Splash Light (Pure white background with the dark CD squircle icon centered)
    img_sl = Image.new("RGBA", (canvas, canvas), (255, 255, 255, 255))
    icon_splash = img_icon.resize((int(canvas * 0.45), int(canvas * 0.45)), Image.Resampling.LANCZOS)
    offset = int((canvas - canvas * 0.45) / 2)
    img_sl.paste(icon_splash, (offset, offset), icon_splash)
    img_sl.resize((1024, 1024), Image.Resampling.LANCZOS).save("assets/branding/splash_light.png")

    # 5. Splash Dark (OLED Black background with the dark CD squircle icon centered)
    img_sd = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 255))
    img_sd.paste(icon_splash, (offset, offset), icon_splash)
    img_sd.resize((1024, 1024), Image.Resampling.LANCZOS).save("assets/branding/splash_dark.png")

    print("✓ Successfully regenerated all branding assets!")

if __name__ == "__main__":
    generate_branding()
