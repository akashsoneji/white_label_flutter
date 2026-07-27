with open('/Users/admin/Desktop/Project/white_label/app/white_label/lib/screens/home/brands/iquote/iquote_chart_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines[:25], 1):
    print(f"{i:3d}: {line.rstrip()}")
