import json, sys
d = json.load(open('/tmp/b2.json'))
en = json.load(open('assets/translations/en.json'))
rev = {}
for k, v in en.items():
    if isinstance(v, str):
        rev.setdefault(v.strip().lower(), k)
skip = ('more/copytrading/', 'more/pmam/')
files = sys.argv[1:] if len(sys.argv) > 1 else None
for f, items in sorted(d.items()):
    if any(s in f for s in skip):
        continue
    if files and not any(x in f for x in files):
        continue
    print('=== ' + f + '  (' + str(len(items)) + ')')
    for i in items:
        r = rev.get(i['value'].strip().lower())
        print('  L%s | %s | REUSE:%s' % (i['line'], i['value'], r))
