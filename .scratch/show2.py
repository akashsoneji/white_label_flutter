with open('/Users/admin/Desktop/Project/white_label/app/white_label/lib/screens/home/brands/iquote/iquote_market_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()
print(f'Total lines: {len(lines)}')
for i, line in enumerate(lines, 1):
    if 310 <= i <= 470:
        print(f'{i:3d}: {line.rstrip()}')
