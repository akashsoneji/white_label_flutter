"""Rewrite the meta_new_order_screen.dart to match the MetaTrader mobile UI."""
p = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart'
with open(p) as f:
    s = f.read()

# Find the build method start (just after "// Build" comment marker)
# We'll replace the entire build method and all sub-builders.

# Read whole file as is, identify sections to replace by markers.
# Each section starts with a comment like:
#   // ──────────────────────────────────────────────────────────────────────
#   // Section name

# Locate each marker and capture (start, end) for replacement.
import re

markers = [
    ('// ──', 'Top bar'),
    ('// ──', 'Linear chart'),
    ('// ──', 'Ask / Bid row'),
    ('// ──', 'Volume selector'),
    ('// ──', 'Stop loss'),
    ('// ──', 'Compact symbol info'),
    ('// ──', 'Buy/Sell picker'),
    ('// ──', 'Bottom action bar'),
]

# Strategy: replace from "// ──\n  // Top bar" to "// Custom paint sparkline"
# (everything except the painter class and helpers).

start_marker = '// Build\n\n  @override\n  Widget build('
end_marker = "// Custom paint sparkline."

start_idx = s.index(start_marker)
end_idx = s.index(end_marker)

print(f"build() method starts at {start_idx}")
print(f"sparkline painter starts at {end_idx}")
print(f"length to replace: {end_idx - start_idx}")