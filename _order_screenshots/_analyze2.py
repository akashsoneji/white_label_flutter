"""Better analysis: extract colored regions from each image.
For each row, count pixels that aren't white/gray (i.e., have strong color).
For each "colorful row", identify which colors are present and at what x positions.
"""
from PIL import Image
import os

base = '/Users/admin/Desktop/Project/white_label/app/white_label/_order_screenshots'

def classify(r, g, b):
    """Classify a pixel as red, green, blue, or neutral."""
    # Skip white/near-white
    if r > 230 and g > 230 and b > 230:
        return 'white'
    if abs(r - g) < 15 and abs(g - b) < 15 and abs(r - b) < 15:
        return 'gray'
    # Determine dominant
    mx = max(r, g, b)
    if mx == r and r > g + 40 and r > b + 40:
        return 'red'
    if mx == g and g > r + 40 and g > b + 40:
        return 'green'
    if mx == b and b > r + 40 and b > g + 40:
        return 'blue'
    if r > g + 20 and b > g + 20 and abs(r - b) < 50:
        return 'pink'
    if r > 200 and g > 100 and b < 100:
        return 'orange'
    return 'other'


for fname in sorted(os.listdir(base)):
    if not fname.endswith('.jpeg'):
        continue
    path = os.path.join(base, fname)
    img = Image.open(path).convert('RGB')
    width, height = img.size
    print(f"\n=== {fname} ({width}x{height}) ===")

    # Walk rows. For each row, count colors.
    row_info = []
    for y in range(height):
        c = {'red': 0, 'green': 0, 'blue': 0, 'pink': 0, 'white': 0, 'gray': 0, 'other': 0}
        for x in range(0, width, 3):
            r, g, b = img.getpixel((x, y))
            cat = classify(r, g, b)
            c[cat] += 1
        # Save only rows with color activity
        nonwhite = c['red'] + c['green'] + c['blue'] + c['pink'] + c['other']
        row_info.append((y, c, nonwhite))

    # Find ranges of consecutive colorful rows (form rows of the UI)
    bands = []
    in_band = False
    band_start = 0
    for y, c, nw in row_info:
        if nw > 5:  # significant color
            if not in_band:
                in_band = True
                band_start = y
        else:
            if in_band:
                bands.append((band_start, y - 1))
                in_band = False
    if in_band:
        bands.append((band_start, height - 1))

    # Print each band with dominant color
    for b_start, b_end in bands:
        if b_end - b_start < 5:
            continue
        # Sample middle
        mid_y = (b_start + b_end) // 2
        # Sample colors in this row
        row_cols = {}
        for x in range(0, width, 2):
            r, g, b = img.getpixel((x, mid_y))
            cat = classify(r, g, b)
            row_cols[cat] = row_cols.get(cat, 0) + 1
        # Find which color is most prevalent
        dominant = max(['red', 'green', 'blue', 'pink', 'other'], key=lambda k: row_cols.get(k, 0))
        if row_cols[dominant] > 5:
            # Also find x-range of dominant color
            xs = []
            for x in range(0, width, 2):
                r, g, b = img.getpixel((x, mid_y))
                cat = classify(r, g, b)
                if cat == dominant:
                    xs.append(x)
            if xs:
                x_start = min(xs)
                x_end = max(xs)
                width_in_band = b_end - b_start + 1
                pixels_of_color = row_cols[dominant]
                pct = 100 * pixels_of_color / sum(row_cols.values()) if row_cols else 0
                if width_in_band > 3 and pct > 5:
                    print(f"  y={b_start:4d}-{b_end:4d} ({width_in_band:4d}px): {dominant:6s}  x≈{x_start:4d}-{x_end:4d}  {pct:.0f}%")