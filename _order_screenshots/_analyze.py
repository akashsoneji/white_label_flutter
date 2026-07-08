"""Analyze the screenshot JPEG images to understand the UI layout.
We'll extract pixel data and try to identify text positions, colors, etc.
"""
from PIL import Image
import os

base = '/Users/admin/Desktop/Project/white_label/app/white_label/_order_screenshots'

for fname in sorted(os.listdir(base)):
    if not fname.endswith('.jpeg'):
        continue
    path = os.path.join(base, fname)
    img = Image.open(path)
    print(f"\n=== {fname} ===")
    print(f"Size: {img.size}, Mode: {img.mode}")

    # Convert to RGB
    img_rgb = img.convert('RGB')

    # Sample colors at different rows to understand layout
    width, height = img_rgb.size
    print(f"Sampling {height} rows for color analysis...")

    # Look at unique color buckets per row
    color_buckets = {}  # row -> list of (x_start, x_end, color_hex)
    for y in range(0, height, 30):
        # Sample pixels in this row
        row_colors = []
        prev_color = None
        run_start = 0
        for x in range(0, width, 5):
            r, g, b = img_rgb.getpixel((x, y))
            # Bucket the color
            hex_col = f"#{r:02x}{g:02x}{b:02x}"
            # Group similar
            if hex_col != prev_color:
                if prev_color is not None:
                    row_colors.append((run_start, x, prev_color))
                prev_color = hex_col
                run_start = x
        row_colors.append((run_start, width, prev_color))
        # Only print rows with significant color changes
        if 3 < len(row_colors) < 30:
            colors_str = ', '.join([f"{c[2]}" for c in row_colors[:8]])
            print(f"  y={y}: {colors_str}")