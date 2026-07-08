"""Find the unbalanced brace region."""
import re

p = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart'
with open(p) as f:
    lines = f.read().split('\n')

# Track brace depth at each line
depth = 0
depths = []
for i, line in enumerate(lines):
    # crude - count all { and } on this line
    d_before = depth
    depth += line.count('{') - line.count('}')
    depths.append((i+1, d_before, depth))

# Find places where depth goes negative or stays positive at end
print(f'Final depth: {depth}')

# Find where { is opened but never closed
# Show lines where depth is non-zero at end of line
print('Lines where depth opens:')
for ln, db, da in depths:
    if da > db:
        # opening line
        pass
    if db > 0 and da == 0:
        # closed back to lower depth
        pass

# Find the line where we should reach depth 0 but don't
# Walk from end backwards, find first line that brings us down to 0
last_depth_change = None
cur = depth
for ln, db, da in reversed(depths):
    cur = da - db  # this is wrong
print('Last 30 line depths:')
for ln, db, da in depths[-30:]:
    if db != da:
        print(f'  line {ln}: depth {db} -> {da}  | {lines[ln-1][:60]}')