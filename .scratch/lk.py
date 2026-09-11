import json, sys
en = json.load(open('assets/translations/en.json'))
rev = {}
for k, v in en.items():
    if isinstance(v, str):
        rev.setdefault(v.strip().lower(), k)
for s in sys.argv[1:]:
    print(repr(s), '->', rev.get(s.strip().lower()))
