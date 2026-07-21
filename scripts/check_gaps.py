import json

for lang in ['fr', 'id', 'zh']:
    p = f'assets/translations/{lang}.json'
    d = json.load(open(p))
    empty = [k for k, v in d.items() if not v]
    missing = []
    en = json.load(open('assets/translations/en.json'))
    en_keys = set(en.keys())
    for k in en_keys:
        if k not in d:
            missing.append(k)
    print(f'{lang}: empty={len(empty)}, missing={len(missing)}, total={len(d)}')
    if missing:
        print(f'  first 5 missing: {missing[:5]}')
    if empty:
        print(f'  first 5 empty: {empty[:5]}')
