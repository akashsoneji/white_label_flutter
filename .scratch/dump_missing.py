#!/usr/bin/env python3
"""
Dump the 805 missing keys and their English values for translation.
"""
import json
import os

os.chdir('/Users/admin/Desktop/Project/white_label/app/white_label')
with open('assets/translations/en.json') as f:
    en = json.load(f)

# Load fr, id, zh and find missing
missing = {}
for lang in ['fr', 'id', 'zh']:
    with open(f'assets/translations/{lang}.json') as f:
        data = json.load(f)
    missing[lang] = [k for k in en.keys() if k not in data]

# All three share the same set - verify
assert missing['fr'] == missing['id'] == missing['zh'], "Sets differ!"

print(f"Total missing: {len(missing['fr'])}")
print()

# Dump by prefix group for easier translation
groups = {}
for k in sorted(missing['fr']):
    parts = k.split('_')
    group = '_'.join(parts[:2]) if len(parts) >= 2 else k
    if group not in groups:
        groups[group] = []
    groups[group].append((k, en[k]))

for g in sorted(groups.keys()):
    print(f"\n=== {g} ({len(groups[g])} keys) ===")
    for k, v in groups[g]:
        print(f"  {k!r}: {v!r}")
