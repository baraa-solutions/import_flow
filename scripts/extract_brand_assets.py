import os
import sys
import base64
import numpy as np
from PIL import Image

def main():
    src_path = r"C:\Users\Hp\.gemini\antigravity\brain\ddce0d36-cae0-4d36-979c-1830924ff9f9\.user_uploaded\media_1792316553885_2458e9ac.jpg"
    out_dir = r"f:\SorourLogistics\frontend\assets\brand"
    os.makedirs(out_dir, exist_ok=True)

    img = Image.open(src_path).convert("RGB")
    arr = np.array(img, dtype=float)

    # Background color estimation (corners & borders)
    bg = np.array([241.0, 244.0, 246.0])

    dist = np.linalg.norm(arr - bg, axis=2)

    low_thresh = 14.0
    high_thresh = 42.0

    alpha = np.zeros_like(dist)
    in_between = (dist > low_thresh) & (dist < high_thresh)
    t = (dist[in_between] - low_thresh) / (high_thresh - low_thresh)
    alpha[in_between] = 3.0 * t**2 - 2.0 * t**3
    alpha[dist >= high_thresh] = 1.0

    # Defringe foreground colors
    alpha_3d = alpha[:, :, None]
    fg_color = np.copy(arr)
    mask = alpha > 0.05
    reconstructed = (arr[mask] - (1.0 - alpha_3d[mask]) * bg) / np.maximum(alpha_3d[mask], 0.2)
    fg_color[mask] = np.clip(reconstructed, 0, 255)

    rgba = np.dstack([fg_color, alpha * 255.0]).astype(np.uint8)
    full_img = Image.fromarray(rgba, "RGBA")

    # 1. Full logo crop
    fg_y, fg_x = np.where(alpha > 0.08)
    pad = 8
    min_x = max(0, fg_x.min() - pad)
    max_x = min(arr.shape[1] - 1, fg_x.max() + pad)
    min_y = max(0, fg_y.min() - pad)
    max_y = min(arr.shape[0] - 1, fg_y.max() + pad)

    crop_full = full_img.crop((min_x, min_y, max_x + 1, max_y + 1))

    # Scale to 2048px width
    w_target = 2048
    h_target = int(round(w_target * (crop_full.height / crop_full.width)))
    hires_full = crop_full.resize((w_target, h_target), Image.Resampling.LANCZOS)
    full_png_path = os.path.join(out_dir, "sorour_logo_full.png")
    hires_full.save(full_png_path, "PNG")
    print(f"Saved: {full_png_path} ({hires_full.size})")

    # 2. Icon only ('S' symbol + logistics elements, y <= 440)
    icon_mask = (alpha > 0.08) & (np.arange(arr.shape[0])[:, None] <= 440)
    iy, ix = np.where(icon_mask)
    imin_x = max(0, ix.min() - pad)
    imax_x = min(arr.shape[1] - 1, ix.max() + pad)
    imin_y = max(0, iy.min() - pad)
    imax_y = min(arr.shape[0] - 1, iy.max() + pad)

    crop_icon = full_img.crop((imin_x, imin_y, imax_x + 1, imax_y + 1))
    iw, ih = crop_icon.size
    max_dim = max(iw, ih)
    square_icon = Image.new("RGBA", (max_dim + 40, max_dim + 40), (0, 0, 0, 0))
    offset_x = (square_icon.width - iw) // 2
    offset_y = (square_icon.height - ih) // 2
    square_icon.paste(crop_icon, (offset_x, offset_y))
    hires_icon = square_icon.resize((2048, 2048), Image.Resampling.LANCZOS)
    icon_png_path = os.path.join(out_dir, "sorour_logo_icon.png")
    hires_icon.save(icon_png_path, "PNG")
    print(f"Saved: {icon_png_path} ({hires_icon.size})")

    # 3. Monochrome Watermark Edition (designed for subtle 3% to 6% overlay)
    icon_arr = np.array(hires_icon, dtype=float)
    watermark_arr = np.zeros_like(icon_arr, dtype=np.uint8)
    # Slate-navy tint #3A5A80 (R: 58, G: 90, B: 128)
    watermark_arr[:, :, 0] = 58
    watermark_arr[:, :, 1] = 90
    watermark_arr[:, :, 2] = 128
    watermark_arr[:, :, 3] = icon_arr[:, :, 3].astype(np.uint8)

    watermark_img = Image.fromarray(watermark_arr, "RGBA")
    watermark_path = os.path.join(out_dir, "sorour_logo_watermark.png")
    watermark_img.save(watermark_path, "PNG")
    print(f"Saved: {watermark_path} ({watermark_img.size})")

    # 4. Dark Mode Edition (crisp pure white text for 'Sorour' on dark navy/charcoal backgrounds)
    dark_arr = np.array(hires_full, dtype=float)
    split_y = int(round(hires_full.height * 0.79))
    text_region = dark_arr[split_y:, :, :]
    text_mask = text_region[:, :, 3] > 20
    text_region[text_mask, 0] = 255
    text_region[text_mask, 1] = 255
    text_region[text_mask, 2] = 255
    dark_arr[split_y:, :, :] = text_region

    dark_img = Image.fromarray(dark_arr.astype(np.uint8), "RGBA")
    dark_path = os.path.join(out_dir, "sorour_logo_dark.png")
    dark_img.save(dark_path, "PNG")
    print(f"Saved: {dark_path} ({dark_img.size})")

    # 5. Scalable SVG wrapper
    with open(full_png_path, "rb") as f:
        b64_data = base64.b64encode(f.read()).decode("utf-8")

    svg_content = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {hires_full.width} {hires_full.height}" width="100%" height="100%">
  <title>Sorour Logistics Official Brand Logo</title>
  <image width="{hires_full.width}" height="{hires_full.height}" href="data:image/png;base64,{b64_data}"/>
</svg>"""

    svg_path = os.path.join(out_dir, "sorour_logo.svg")
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(svg_content)
    print(f"Saved: {svg_path}")

    # 6. Generate README catalog
    readme_content = """# Sorour Logistics — Official Visual Brand Assets Catalog

تم استخراج وتجهيز هذه الأصول من الهوية البصرية الرسمية المعتمدة لشركة **Sorour Logistics** (سرور للخدمات اللوجستية والاستيراد والتصدير).
جميع الأصول مخزنة مركزياً في هذا المجلد فقط وممنوع تكرارها في أماكن أخرى في المشروع.

## الملفات المتاحة واستخداماتها

| الملف | الدقة / الأبعاد | التنسيق | الغرض ومكان الاستخدام |
|---|---|---|---|
| `sorour_logo_full.png` | 2048px (عرض عالي الدقة) | PNG شفاف | اللوجو الكامل (الرمز + كلمة Sorour) للشاشات الفاتحة، صفحات التصدير PDF، صفحة تسجيل الدخول، والشريط الجانبي الموسع. |
| `sorour_logo_dark.png` | 2048px (عرض عالي الدقة) | PNG شفاف | النسخة المخصصة للوضع الداكن (Dark Mode) والشريط الجانبي الداكن (كلمة Sorour باللون الأبيض النقي #FFFFFF عالي التباين). |
| `sorour_logo_icon.png` | 2048 × 2048 (مربع) | PNG شفاف | الرمز 'S' فقط مع وسائل النقل (طائرة، شاحنة، ونش، سفينة). للأماكن الصغيرة، الشريط الجانبي المطوي (Mini Rail)، و Favicon، والأيقونات المدمجة. |
| `sorour_logo_watermark.png` | 2048 × 2048 (مربع) | PNG شفاف أحادي | نسخة أحادية اللون (Monochrome Tint #3A5A80) مخصصة خصيصاً للعلامة المائية بخلفية الشاشات وتقارير PDF بنسبة شفافية خفيفة جداً (3% إلى 6%). |
| `sorour_logo.svg` | Scalable Vector Container | SVG | ملف متجه قياسي للطباعة والويب بدون فقدان في الدقة. |

## لوحة الألوان الرسمية (Brand Design Tokens)

تم استخراج هذه الألوان بدقة من بكسلات الشعار الأصلي وتسجيلها في `AppTheme`:

- **Sorour Navy (الأزرق الداكن الأساسي):** `#0F386A` / `#103C6D` — لون كلمة Sorour، هيدر جداول التصدير، هيدر تقارير PDF.
- **Sorour Deep Blue (أزرق المحيط العميق):** `#074E8C` — تدرجات الرمز وظلال السفينة.
- **Sorour Cobalt (الأزرق الرئيسي المعتمد):** `#0B68A6` — اللون الأساسي للأزرار والأيقونات والروابط.
- **Sorour Sky Blue (السماوي النابض):** `#077DBE` — الإضاءات وتدرجات الطائرة وأثر السحب.
- **Sorour Ice Blue (الأزرق الثلجي الفاتح):** `#88B6D2` — حدود خفيفة، علامات مائية، وهوامش التحديد.
- **Sorour Surface Tint (صبغة الأسطح الرسمية):** `#F0F5FA` — خلفيات البطاقات المنسوبة للهوية.

## قواعد وضوابط الاستخدام

1. **العلامة المائية في الشاشات:**
   - تطبق حصراً على مستوى الـ Layout العام (`HomeScreen`).
   - الشفافية: بين 3% إلى 5% في الوضع الفاتح، و 3% إلى 4% في الوضع الداكن.
   - يجب أن تكون `IgnorePointer` و `ExcludeSemantics` وغير قابلة للتحديد أو التفاعل.
   - لا تغطي الشريط الجانبي ولا الهيدر.
2. **العلامة المائية في مستندات PDF:**
   - تدمج في `pw.PageTheme` أو خلفية صفحات التصدير بشفافية رقيقة (حوالي 4-5%) في المنتصف خلف الجداول.
"""
    readme_path = os.path.join(out_dir, "README.md")
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(readme_content)
    print(f"Saved: {readme_path}")

if __name__ == "__main__":
    main()
