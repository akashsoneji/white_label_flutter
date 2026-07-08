p = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart'
with open(p) as f:
    lines = f.readlines()

for i, line in enumerate(lines, 1):
    if '%' in line:
        # Show context
        print(f'Line {i}: {repr(line)}')
        # Show 2 lines of context
        for j in range(max(0, i-3), min(len(lines), i+2)):
            print(f'  {j+1}: {repr(lines[j])}')
        print('---')