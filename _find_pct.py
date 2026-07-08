with open('/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart') as f:
    lines = f.readlines()
print(f'Total lines: {len(lines)}')
for i, l in enumerate(lines, 1):
    if l.strip() == '%':
        print(f'FOUND Line {i}: {repr(l)}')
        for j in range(max(0, i-3), min(len(lines), i+3)):
            print(f'  {j+1}: {repr(lines[j])}')