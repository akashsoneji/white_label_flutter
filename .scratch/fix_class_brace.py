"""Fix the structural integrity of meta_new_order_screen.dart.

The _MetaNewOrderScreenState class is missing its closing brace
before 'class _SparklinePainter'. We need to add one extra }.

Strategy: find the unique line `class _SparklinePainter extends CustomPainter {`
and insert a single `}` right before it.
"""
p = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart'
with open(p) as f:
    s = f.read()

# Mark every top-level class definition for context.
target = '\nclass _SparklinePainter extends CustomPainter {'
if target not in s:
    print('WARN: pattern not found exactly. Trying looser match.')
    # Try without leading newline
    target = 'class _SparklinePainter extends CustomPainter {'

idx = s.find(target)
print(f'Found SparklinePainter at offset {idx}')
# Print context
print('Context before:')
print(repr(s[idx-200:idx]))
print('---')
# Insert a closing } right before the class
fixed = s[:idx] + '\n}\n\n' + s[idx:]
with open(p, 'w') as f:
    f.write(fixed)
print(f'New length: {len(fixed)}, open: {fixed.count("{")}, close: {fixed.count("}")}')