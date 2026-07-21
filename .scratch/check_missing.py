#!/usr/bin/env python3
import json
import sys
import os

os.chdir('/Users/admin/Desktop/Project/white_label/app/white_label')

with open('assets/translations/en.json') as f:
    en = json.load(f)
print(f'EN top-level keys: {len(en)}')

for lang in ['fr', 'id', 'zh', 'es', 'hi', 'tr', 'ar']:
    with open(f'assets/translations/{lang}.json') as f:
        data = json.load(f)
    missing = [k for k in en.keys() if k not in data]
    print(f'{lang}: {len(data)} keys, missing {len(missing)}')

# Show the missing keys for fr
print()
print("--- Missing in fr.json ---")
with open('assets/translations/fr.json') as f:
    fr = json.load(f)
missing_fr = [k for k in en.keys() if k not in fr]
print(f'Total missing: {len(missing_fr)}')
print('First 20 missing:')
for k in missing_fr[:20]:
    print(f'  {k!r}: {en[k]!r}')
