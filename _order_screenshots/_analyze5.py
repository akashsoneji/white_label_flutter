"""Look at the very left edge of image 03 to see what's there."""
from PIL import Image
img = Image.open('/Users/admin/Desktop/Project/white_label/app/white_label/_order_screenshots/03.jpeg').convert('RGB')
width, height = img.size

print("Image 03 - left edge (x=0-150):")
for y in range(0, height, 5):
    row = []
    for x in range(0, 150, 5):
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
    line = ''.join(row)
    if line.count('.') < 28:
        print(f"  y={y:4d}: {line}")