#!/usr/bin/env python3
"""Compute key diff between en.json and each other translation."""
import json
import os
from collections import OrderedDict

DIR = "/Users/admin/Desktop/Project/white_label/app/white_label/assets/translations"
EN = os.path.join(DIR, "en.json")
OTHERS = ["ar.json", "es.json", "hi.json", "tr.json"]

def load(p):
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=OrderedDict)

en = load(EN)
en_keys = list(en.keys())
en_set = set(en_keys)
print(f"en.json: {len(en_keys)} keys")

for other in OTHERS:
    p = os.path.join(DIR, other)
    d = load(p)
    keys = list(d.keys())
    s = set(keys)
    missing = [k for k in en_keys if k not in s]
    outliers = [k for k in keys if k not in en_set]
    dupes = [k for k in keys if keys.count(k) > 1]
    print(f"\n=== {other} ===")
    print(f"  total: {len(keys)}, unique: {len(s)}")
    print(f"  missing ({len(missing)}): {missing[:20]}{'...' if len(missing) > 20 else ''}")
    if len(missing) > 20:
        print(f"    ...all missing: {missing}")
    print(f"  outliers ({len(outliers)}): {outliers[:20]}{'...' if len(outliers) > 20 else ''}")
    if len(outliers) > 20:
        print(f"    ...all outliers: {outliers}")
    if dupes:
        print(f"  duplicates: {dupes}")
