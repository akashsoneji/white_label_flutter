"""Detailed scan of the chart area (top of screen) for image 01."""
from PIL import Image
img = Image.open('/Users/admin/Desktop/Project/white_label/app/white_label/_order_screenshots/01.jpeg').convert('RGB')
width, height = img.size

# Detailed scan of y=270-420 to see chart area
print("Image 01 - chart area (y=270-420):")
for y in range(270, 420, 5):
    row = []
    for x in range(0, width, 10):
        r, g, b = img.getpixel((x, y))
        # Just show the dominant
        if r > 230 and g > 230 and b > 230:
            row.append('.')
        elif b > r and b > g:
            row.append('B')
        elif r > g and r > b:
            row.append('R')
        elif abs(r - g) < 15 and abs(g - b) < 15:
            row.append('-')
        else:
            row.append('?')
    print(f"  y={y:4d}: {''.join(row)}")

print("\nImage 01 - middle area (y=600-900):")
for y in range(600, 900, 5):
    row = []
    for x in range(0, width, 10):
        r, g, b = img.getpixel((x, y))
        if r > 230 and g > 230 and b > 230:
            row.append('.')
        elif b > r and b > g:
            row.append('B')
        elif r > g and r > b:
            row.append('R')
        elif abs(r - g) < 15 and abs(g - b) < 15:
            row.append('-')
        else:
            row.append('?')
    print(f"  y={y:4d}: {''.join(row)}")