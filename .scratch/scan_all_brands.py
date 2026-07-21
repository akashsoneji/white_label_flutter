"""Scan all of lib/ for hardcoded UI strings (excluding vantage tree which is done)."""
import re, os, json

en = json.load(open('assets/translations/en.json'))

patterns = [
    r"Text\(\s*'([^'\n]{2,80})'\s*[,)]",
    r"Text\(\s*\"([^\"\n]{2,80})\"\s*[,)]",
    r"hintText:\s*'([^'\n]{2,80})'",
    r"labelText:\s*'([^'\n]{2,80})'",
    r"title:\s*'([^'\n]{2,80})'",
    r"label:\s*'([^'\n]{2,80})'",
    r"text:\s*'([^'\n]{2,80})'",
    r"tooltip:\s*'([^'\n]{2,80})'",
]

skip_contains = [
    'tr(', 'Routes.', 'AppPages.', 'Icons.', 'Colors.',
    'http', 'EdgeInsets', 'BorderRadius', 'Duration(',
    'kReleaseMode', 'print(', 'debugPrint(', 'format(',
    'AssetImage', 'localhost', '.rounded', '.sharp',
    'currencyCode', 'replace', 'context.', '.toString()',
    'languageService', 'LanguageService',
    'description:', 'value:', 'key:', 'name:',
    'assert(', 'required', 'super.',
]

all_hits = {}
for root, _, fnames in os.walk('lib'):
    for fn in fnames:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(root, fn)
        if 'brands/vantage' in p:
            continue
        if 'generated' in p or 'l10n' in p:
            continue
        content = open(p, encoding='utf-8').read()
        hits = []
        for pat in patterns:
            for m in re.finditer(pat, content):
                s = m.group(1)
                if any(x in s for x in skip_contains):
                    continue
                if not s or len(s) < 2:
                    continue
                if re.match(r'^[A-Z_]+$', s):
                    continue
                if not re.search(r'[a-zA-Z]', s):
                    continue
                line = content[:m.start()].count('\n') + 1
                if not any(h[0] == line for h in hits):
                    hits.append((line, s))
        if hits:
            all_hits[p] = hits

for p in sorted(all_hits):
    brand = 'meta' if '/brands/meta' in p else 'celestial' if '/brands/celestial' in p else 'shared'
    hits = all_hits[p]
    print(f'\n{brand}|{p}|{len(hits)}')
    for line, s in hits:
        print(f'  L{line}: {s[:80]}')
