import re

p = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart'
with open(p) as f:
    s = f.read()

# Remove stray % at start of file if present
s = s.lstrip()
if s.startswith('%'):
    s = s[1:]

# Find unbalanced braces
obrace = s.count('{')
cbrace = s.count('}')
print(f'Open: {obrace} Close: {cbrace}')
print(f'Length: {len(s)}')

# Try to find which class is unclosed. Looking at line numbers:
# Show structure of class definitions
lines = s.split('\n')
in_class = False
class_name = None
depth = 0
print('Classes & their first/last lines:')

classes = []
current_class = None
brace_depths = []
for i, line in enumerate(lines):
    m = re.match(r'^class\s+(\w+)', line)
    if m and depth == 0:
        if current_class:
            classes.append((current_class, current_start_line))
        current_class = m.group(1)
        current_start_line = i + 1
    obrace += line.count('{') if not current_class else 0
    brace_depths.append((i+1, line.count('{'), line.count('}')))

# Just show where classes start and end
print('Class locations:')
class_lines = []
for i, line in enumerate(lines, 1):
    if re.match(r'^class\s+(\w+)', line):
        print(f'  line {i}: {line[:80]}')

# Top-level declarations
for i, line in enumerate(lines, 1):
    depth_change = line.count('{') - line.count('}')
    # Track top-level depth (assume file starts at 0)
