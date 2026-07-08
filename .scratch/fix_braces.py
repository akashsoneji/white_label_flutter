#!/usr/bin/env python3
"""Fix brace integrity issues in meta_new_order_screen.dart.

Two passes:
  1. Remove any line whose stripped content is exactly '%' (chr 37).
  2. Remove trailing '%' from any non-empty line.
"""
from pathlib import Path

TARGET = Path("/Users/admin/Desktop/Project/white_label/app/white_label/lib/brands/meta/meta_new_order_screen.dart")

text = TARGET.read_text()
original_lines = text.splitlines(keepends=True)

cleaned = []
removed_solo = 0
stripped_trailing = 0
for line in original_lines:
    stripped = line.strip()
    if stripped == "%":
        removed_solo += 1
        continue
    if line.strip() != "" and line.rstrip().endswith("%"):
        # Preserve line ending
        if line.endswith("\n"):
            body = line[:-1]
            nl = "\n"
        else:
            body = line
            nl = ""
        if body.endswith("%"):
            body = body[:-1]
            stripped_trailing += 1
        line = body + nl
    cleaned.append(line)

new_text = "".join(cleaned)
TARGET.write_text(new_text)
print(f"removed_solo_pct={removed_solo} stripped_trailing_pct={stripped_trailing}")