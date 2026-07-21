"""Find all remaining hardcoded UI strings in vantage_pending_order_content.dart
and print the exact lines so we can write precise edit_file blocks."""
import re, os
path = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/screens/home/brands/vantage/vantage_pending_order_content.dart'
content = open(path, encoding='utf-8').read()
# Look for `title: 'String',` and `label: 'String',` and `hintText: 'String',`
# inside the vantage tree only
candidates = [
    "'Processing...'",
    "title: 'Quantity'",
    "title: 'Trigger price'",
    "title: 'Risk management'",
    "label: 'Market execution'",
    "label: 'Take Profit'",
    "label: 'Stop Loss'",
    "title: 'Buy limit'",
    "title: 'Sell limit'",
    "hintText: 'Enter lots'",
    "title: 'Lots'",
    "label: 'Potential Profit at TP'",
    "label: 'Potential Loss at SL'",
    "title: 'pending_order_price'",
]
for c in candidates:
    # find first occurrence
    idx = content.find(c)
    if idx < 0:
        print(f"NOT FOUND: {c}")
        continue
    line = content[:idx].count('\n') + 1
    # show 1 line before, the match line, and 1 line after
    lines = content.splitlines()
    print(f"\n{line}: {c}")
    for i in range(max(0, line - 2), min(len(lines), line + 1)):
        marker = ">>" if i + 1 == line else "  "
        print(f"{marker} {i+1:4d}: {lines[i]}")
