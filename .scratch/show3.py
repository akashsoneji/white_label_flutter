with open('/Users/admin/Desktop/Project/white_label/app/white_label/lib/screens/home/brands/iquote/iquote_market_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines, 1):
    if 470 <= i <= 788:
        if 'GestureDetector' in line or 'InkWell' in line or 'onTap' in line or 'Material' in line or 'ButtonStyle' in line:
            print(f'{i:3d}: {line.rstrip()}')
