"""
Sorour Logistics ERP — Official Brand Icon & Windows App Icon Generator
========================================================================
Generates high-resolution multi-size Windows .ico files and Web favicons
using the official Sorour Logistics brand mark ('S' glyph with maritime,
air, and land transport elements).
"""
import os
from pathlib import Path
from PIL import Image, ImageDraw

ROOT_DIR = Path(__file__).resolve().parent
BRAND_ICON_SRC = ROOT_DIR / "frontend" / "assets" / "brand" / "sorour_logo_icon.png"

ICO_TARGETS = [
    ROOT_DIR / "frontend" / "windows" / "runner" / "resources" / "app_icon.ico",
    ROOT_DIR / "dist" / "app_icon.ico",
]

WEB_TARGETS = [
    (ROOT_DIR / "frontend" / "web" / "favicon.png", 48),
    (ROOT_DIR / "frontend" / "web" / "icons" / "Icon-192.png", 192),
    (ROOT_DIR / "frontend" / "web" / "icons" / "Icon-512.png", 512),
]

MASKABLE_TARGETS = [
    (ROOT_DIR / "frontend" / "web" / "icons" / "Icon-maskable-192.png", 192),
    (ROOT_DIR / "frontend" / "web" / "icons" / "Icon-maskable-512.png", 512),
]


def create_fallback_icon(size: int) -> Image.Image:
    """Fallback generator in case the brand asset is missing."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    radius = int(size * 0.22)
    margin = int(size * 0.04)

    # Sorour Navy #0F386A background
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius,
        fill=(15, 56, 106, 255),
        outline=(11, 104, 166, 255),
        width=max(1, int(size * 0.04)),
    )
    return img


def create_maskable_icon(base_img: Image.Image, size: int) -> Image.Image:
    """Creates a PWA maskable icon with safe zone padding and Sorour Navy background."""
    canvas = Image.new("RGBA", (size, size), (15, 56, 106, 255))  # Sorour Navy #0F386A
    # Safe zone: icon occupies 75% of canvas
    inner_size = int(size * 0.75)
    resized_icon = base_img.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
    offset = (size - inner_size) // 2
    canvas.paste(resized_icon, (offset, offset), resized_icon)
    return canvas


def generate_all_icons() -> None:
    if BRAND_ICON_SRC.exists():
        print(f"Loading official brand icon: {BRAND_ICON_SRC}")
        source_img = Image.open(BRAND_ICON_SRC).convert("RGBA")
    else:
        print("Warning: Official brand icon not found, generating fallback...")
        source_img = create_fallback_icon(2048)

    # 1. Multi-resolution Windows ICO (256, 128, 64, 48, 32, 16)
    ico_sizes = [256, 128, 64, 48, 32, 16]
    ico_images = [
        source_img.resize((s, s), Image.Resampling.LANCZOS) for s in ico_sizes
    ]

    for p in ICO_TARGETS:
        p.parent.mkdir(parents=True, exist_ok=True)
        ico_images[0].save(
            p,
            format="ICO",
            sizes=[(s, s) for s in ico_sizes],
            append_images=ico_images[1:],
        )
        print(f"  [OK] Saved Windows ICO ({len(ico_sizes)} sizes) -> {p}")

    # 2. Web Favicon and PWA icons
    for p, size in WEB_TARGETS:
        if p.parent.exists():
            thumb = source_img.resize((size, size), Image.Resampling.LANCZOS)
            thumb.save(p, format="PNG")
            print(f"  [OK] Saved Web Icon ({size}x{size}) -> {p}")

    # 3. Maskable PWA icons
    for p, size in MASKABLE_TARGETS:
        if p.parent.exists():
            maskable = create_maskable_icon(source_img, size)
            maskable.save(p, format="PNG")
            print(f"  [OK] Saved Maskable Web Icon ({size}x{size}) -> {p}")

    print("Brand icon generation complete.")


if __name__ == "__main__":
    generate_all_icons()
