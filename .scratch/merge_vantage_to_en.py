#!/usr/bin/env python3
"""Step 4: merge the curated vantage keys into en.json and report final stats."""
import json, os
from collections import OrderedDict

os.chdir('/Users/admin/Desktop/Project/white_label/app/white_label')

with open('/tmp/vantage_keys_final.json', encoding='utf-8') as f:
    new = json.load(f, object_pairs_hook=OrderedDict)

with open('assets/translations/en.json', encoding='utf-8') as f:
    en = json.load(f, object_pairs_hook=OrderedDict)

print(f"en.json before: {len(en)} keys")
print(f"vantage keys:   {len(new)} keys")

# Add new keys, dedup, sort alphabetically
merged = OrderedDict()
for k, v in en.items():
    merged[k] = v
# Track collisions
collisions = []
for k, v in new.items():
    if k in merged:
        collisions.append((k, merged[k], v['value']))
    merged[k] = v['value']

# Sort alphabetically
sorted_merged = OrderedDict(sorted(merged.items()))

with open('assets/translations/en.json', 'w', encoding='utf-8') as f:
    json.dump(sorted_merged, f, ensure_ascii=False, indent=2)
    f.write('\n')

print(f"en.json after:  {len(sorted_merged)} keys (+{len(new) - len([c for c in collisions if c[0] in new])} net)")
if collisions:
    print(f"Collisions: {len(collisions)}")
    for c in collisions[:10]:
        print(f"  {c[0]!r} -> existing={c[1]!r}  new={c[2]!r}")
else:
    print("Collisions: 0")
