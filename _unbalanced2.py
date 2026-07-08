"""Find unbalanced brace by line, considering string literals."""
import re

p = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart'
with open(p) as f:
    s = f.read()

# Remove all string literals (single-line only - this is a heuristic)
# Replace them with empty strings
s2 = re.sub(r'"[^"\n]*"', '""', s)
s2 = re.sub(r"'[^'\n]*'", "''", s2)
# Remove comments
s2 = re.sub(r'//[^\n]*', '', s2)
# Now count braces
print('Open:', s2.count('{'), 'Close:', s2.count('}'))
# Find where depth is non-zero at end
depth = 0
unclosed = []
for i, c in enumerate(s2):
    if c == '{':
        depth += 1
        unclosed.append(i)
    elif c == '}':
        depth -= 1
        if unclosed:
            unclosed.pop()
        else:
            print(f'Extra }} at offset {i}')

print(f'Final depth: {depth}, unclosed count: {len(unclosed)}')
# Show last 5 unclosed positions
print('Last 5 unclosed:')
for off in unclosed[-5:]:
    line = s[:off].count('\n') + 1
    # Find next 80 chars
    snippet = s[off:off+80].replace('\n', '\\n')
    print(f'  line {line} (offset {off}): {snippet[:80]}')