#!/usr/bin/env python3
"""Remove the unused _PasswordRulesWidget + _RuleRow classes from the end of the file."""
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    src = f.read()

marker = "\nclass _PasswordRulesWidget extends StatelessWidget {"
idx = src.find(marker)
if idx == -1:
    print("marker not found", file=sys.stderr)
    sys.exit(0)
new_src = src[:idx].rstrip() + "\n"
with open(path, "w", encoding="utf-8") as f:
    f.write(new_src)
print(f"removed {len(src) - len(new_src)} bytes")
