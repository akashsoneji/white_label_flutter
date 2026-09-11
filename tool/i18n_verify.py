#!/usr/bin/env python3
"""Translation key integrity audit for the crm_app Flutter project.

Reports (and optionally fixes):
  (i)   keys referenced in lib/ but missing from en.json  -> render as raw keys
  (ii)  key-set differences between the six language files
  (iii) keys whose English value is empty / whitespace only
  (iv)  duplicate English values mapped to different keys (report only)

Usage:
    python3 tool/i18n_verify.py            # audit only
    python3 tool/i18n_verify.py --fix      # audit, then add/sync missing keys
"""

import collections
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')
TRANSLATIONS = os.path.join(ROOT, 'assets', 'translations')
LANGUAGES = ['en', 'ar', 'es', 'id', 'vi', 'zh']

# .tr('key') / .trArgs('key', ...) / .trf('key', ...) / .trp('key', ...)
# `re.S` so the argument may sit on the line after the opening paren.
KEY_CALL = re.compile(
    r"""\.(?:tr|trArgs|trf|trp)\(\s*(['"])([A-Za-z0-9_.\-]+)\1""", re.S
)


def load(lang):
    path = os.path.join(TRANSLATIONS, '%s.json' % lang)
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as fh:
        return json.load(fh, object_pairs_hook=collections.OrderedDict)


def save(lang, data):
    path = os.path.join(TRANSLATIONS, '%s.json' % lang)
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write('\n')


def referenced_keys():
    """Map key -> sorted list of 'relpath:line' where it is referenced."""
    refs = collections.defaultdict(set)
    for dirpath, dirnames, filenames in os.walk(LIB):
        dirnames[:] = [d for d in dirnames if not d.startswith('.')]
        for name in filenames:
            if not name.endswith('.dart'):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, ROOT)
            with open(full, encoding='utf-8', errors='replace') as fh:
                source = fh.read()
            for match in KEY_CALL.finditer(source):
                lineno = source.count('\n', 0, match.start()) + 1
                refs[match.group(2)].add('%s:%d' % (rel, lineno))
    return {k: sorted(v) for k, v in refs.items()}


def humanize(key):
    """Derive a readable English value from a snake_case key name."""
    parts = [p for p in key.replace('.', '_').replace('-', '_').split('_') if p]
    text = ' '.join(parts)
    return text[:1].upper() + text[1:] if text else key


def audit():
    refs = referenced_keys()
    data = {lang: load(lang) for lang in LANGUAGES}
    missing_langs = [l for l in LANGUAGES if data[l] is None]
    en = data['en'] or collections.OrderedDict()

    missing_in_en = sorted(k for k in refs if k not in en)

    key_sets = {l: set(data[l].keys()) for l in LANGUAGES if data[l] is not None}
    union = set().union(*key_sets.values()) if key_sets else set()
    diffs = {l: sorted(union - key_sets[l]) for l in key_sets}

    empty_values = sorted(
        k for k, v in en.items() if not isinstance(v, str) or not v.strip()
    )

    by_value = collections.defaultdict(list)
    for k, v in en.items():
        if isinstance(v, str) and v.strip():
            by_value[v.strip().lower()].append(k)
    duplicates = {v: ks for v, ks in by_value.items() if len(ks) > 1}

    return {
        'refs': refs,
        'data': data,
        'missing_lang_files': missing_langs,
        'missing_in_en': missing_in_en,
        'key_set_diffs': diffs,
        'empty_values': empty_values,
        'duplicates': duplicates,
        'union': union,
    }


def report(result, label):
    print('=== i18n audit (%s) ===' % label)
    if result['missing_lang_files']:
        print('MISSING LANGUAGE FILES: %s' % ', '.join(result['missing_lang_files']))
    print('referenced keys in lib/: %d' % len(result['refs']))
    print('en.json keys: %d' % len(result['data']['en'] or {}))
    print('(i)   referenced but MISSING from en.json: %d' % len(result['missing_in_en']))
    for k in result['missing_in_en'][:60]:
        print('        %s   <- %s' % (k, result['refs'][k][0]))
    if len(result['missing_in_en']) > 60:
        print('        ... and %d more' % (len(result['missing_in_en']) - 60))
    print('(ii)  key-set differences (keys absent from each file):')
    for lang in LANGUAGES:
        diff = result['key_set_diffs'].get(lang)
        if diff is None:
            continue
        print('        %s: %d missing' % (lang, len(diff)))
    print('(iii) empty/whitespace English values: %d' % len(result['empty_values']))
    for k in result['empty_values'][:30]:
        print('        %s' % k)
    print('(iv)  duplicate English values across keys: %d values, %d keys'
          % (len(result['duplicates']),
             sum(len(v) for v in result['duplicates'].values())))
    top = sorted(result['duplicates'].items(), key=lambda kv: -len(kv[1]))[:15]
    for value, keys in top:
        print('        %-40s x%d  %s' % (value[:40], len(keys), ', '.join(keys[:5])))


def apply_fixes(result):
    data = result['data']
    en = data['en']
    added_to_en = []
    for key in result['missing_in_en']:
        en[key] = humanize(key)
        added_to_en.append(key)
    save('en', en)

    synced = {}
    for lang in LANGUAGES:
        if lang == 'en' or data[lang] is None:
            continue
        target = data[lang]
        added = [k for k in en if k not in target]
        for key in added:
            target[key] = en[key]
        if added:
            save(lang, target)
        synced[lang] = len(added)
    return added_to_en, synced


def health(en, ar):
    total = len(en)
    same = sum(
        1 for k, v in en.items()
        if isinstance(v, str) and isinstance(ar.get(k), str) and v == ar[k]
    )
    prefixes = collections.Counter(k.split('_')[0] for k in en)
    return total, same, prefixes.most_common(10)


def main():
    do_fix = '--fix' in sys.argv
    result = audit()
    report(result, 'BEFORE' if do_fix else 'CURRENT')

    if do_fix:
        added, synced = apply_fixes(result)
        print('\n--- fixes applied ---')
        print('added to en.json: %d' % len(added))
        for k in added:
            print('    %s = %s' % (k, result['data']['en'][k]))
        for lang, count in synced.items():
            print('synced %s.json: +%d keys' % (lang, count))
        print()
        report(audit(), 'AFTER')

    final = audit()
    en = final['data']['en'] or {}
    ar = final['data']['ar'] or {}
    total, same, prefixes = health(en, ar)
    print('\n=== en.json health ===')
    print('total keys: %d' % total)
    print('identical en/ar values (untranslated): %d (%.1f%%)'
          % (same, 100.0 * same / total if total else 0))
    print('top 10 key prefixes:')
    for prefix, count in prefixes:
        print('    %-24s %d' % (prefix, count))


if __name__ == '__main__':
    main()
