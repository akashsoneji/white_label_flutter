p = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart'
with open(p) as f:
    s = f.read()

# Remove stray % from any line
lines = s.split('\n')
cleaned = []
for line in lines:
    if line.strip() == '%':
        continue
    if line.endswith('%'):
        line = line.rstrip()[:-1].rstrip()
    cleaned.append(line)

s2 = '\n'.join(cleaned).rstrip()

with open(p, 'w') as f:
    f.write(s2)

print(f'New length: {len(s2)}, open: {s2.count("{")}, close: {s2.count("}")}')
print(f'Last char: {repr(s2[-5:])}')