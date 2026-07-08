"""Find horizontal dividers/cards by looking for sharp transitions."""
from PIL import Image
import os

base = '/Users/admin/Desktop/Project/white_label/app/white_label/_order_screenshots'

for fname in sorted(os.listdir(base)):
    if not fname.endswith('.jpeg'):
        continue
    path = os.path.join(base, fname)
    img = Image.open(path).convert('RGB')
    width, height = img.size
    print(f"\n=== {fname} ({width}x{height}) ===")

    # For each row, find the dominant background by sampling center pixels
    row_bg = []
    for y in range(height):
        center_x = width // 2
        r, g, b = img.getpixel((center_x, y))
        row_bg.append((r, g, b))

    # Find rows that are NOT white/light gray (they're card backgrounds or borders)
    # Look for rows that are darker than 240 in average
    print(f"  Center pixel scan (every 50 rows):")
    for y in range(0, height, 50):
        r, g, b = row_bg[y]
        print(f"    y={y:4d}: rgb=({r:3d},{g:3d},{b:3d})")