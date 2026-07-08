with open('/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart') as f:
    lines = f.readlines()
print('Total lines:', len(lines))
hits = []
for i, l in enumerate(lines, 1):
    if l.strip() == chr(37):
        hits.append(i)
print('Percent-only lines:', hits)
# Show context around each
for i in hits:
    print('Context around line', i)
    for j in range(max(0, i-2), min(len(lines), i+2)):
        marker = ' >> ' if j+1 == i else '    '
        print(marker + str(j+1) + ': ' + repr(lines[j]))
    print('---')