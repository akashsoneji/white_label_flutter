#!/usr/bin/env python3
"""
Translate 805 missing keys (same set missing from fr.json, id.json, zh.json)
from English into target languages using deep_translator GoogleTranslator.
Preserves {placeholder} tokens exactly.
"""
import json
import os
import re
import sys
import time
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

os.chdir('/Users/admin/Desktop/Project/white_label/app/white_label')

from deep_translator import GoogleTranslator

# Vantage UI multilingual rollout: translate new keys into all 7 non-English
# supported languages.  The first run in this project only covered fr/id/zh;
# the full set is ar/es/fr/hi/id/tr/zh.  Chinese needs the 'zh-CN' region
# qualifier so GoogleTranslator returns Simplified Chinese; all others are
# bare language codes.
TARGETS = {
    'ar': 'ar',
    'es': 'es',
    'fr': 'fr',
    'hi': 'hi',
    'id': 'id',
    'tr': 'tr',
    'zh': 'zh-CN',
}
WORKERS = 6
PLACEHOLDER_RE = re.compile(r'\{[^}]*\}')

# ---- load ---------------------------------------------------------------
with open('assets/translations/en.json', encoding='utf-8') as f:
    en = json.load(f)
print(f"en.json has {len(en)} keys")

existing = {}
for lang in TARGETS:
    with open(f'assets/translations/{lang}.json', encoding='utf-8') as f:
        existing[lang] = json.load(f)

missing = [k for k in en.keys() if k not in existing['fr']]
assert all(k not in existing['id'] for k in missing)
assert all(k not in existing['zh'] for k in missing)
print(f"Missing keys to translate: {len(missing)}")

# ---- helpers ------------------------------------------------------------
lock = threading.Lock()
cache = {lang: {} for lang in TARGETS}
errors = {lang: [] for lang in TARGETS}

def phs(text):
    return PLACEHOLDER_RE.findall(text)

def restore(translated, ph_list):
    """Put original placeholders back into the translated text."""
    if not ph_list:
        return translated
    out = translated
    matches = list(PLACEHOLDER_RE.finditer(out))
    if len(matches) == len(ph_list):
        for m, orig in reversed(list(zip(matches, ph_list))):
            out = out[:m.start()] + orig + out[m.end():]
        return out
    # translator ate placeholders — put the single placeholder back
    if len(matches) == 0 and len(ph_list) == 1:
        p = ph_list[0]
        for ending in ('.', '!', '?', '…', ':', ';', '。', '！', '？', ',', '）', ')', '」', '」', '"', "'"):
            if out.endswith(ending):
                return out[:-1] + p + ending
        return out + ' ' + p
    # multiple placeholders got lost — best effort
    if ph_list:
        out = out + ' ' + ' '.join(ph_list)
    return out

def translate(text, lang):
    """Thread-safe translation with retries."""
    cache_entry = cache[lang]
    if text in cache_entry:
        return cache_entry[text]
    if not text or not text.strip():
        return text
    if len(text.strip()) <= 2 and not PLACEHOLDER_RE.search(text):
        return text  # skip brand names / pure symbols
    chunk = text if len(text) <= 4500 else text[:4500]
    result = text
    for attempt in range(3):
        try:
            result = GoogleTranslator(source='en', target=TARGETS[lang]).translate(chunk)
            if not result:
                result = chunk
            break
        except Exception as e:
            if attempt < 2:
                time.sleep(1 + attempt * 2)
            else:
                with lock:
                    errors[lang].append((text, str(e)))
                result = chunk
    with lock:
        cache_entry[text] = result
    return result

# ---- translate per-language ---------------------------------------------
start = time.time()
final = {lang: {} for lang in TARGETS}

for lang in TARGETS:
    lang_start = time.time()
    # Deduplicate source strings
    src_to_keys = {}
    for k in missing:
        src_to_keys.setdefault(en[k], []).append(k)
    src_texts = list(src_to_keys.keys())
    print(f"\n  {lang}: {len(src_texts)} unique source strings -> target={TARGETS[lang]}")
    sys.stdout.flush()

    results = {}
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = {pool.submit(translate, src, lang): src for src in src_texts}
        done = 0
        for fut in as_completed(futures):
            src = futures[fut]
            try:
                tr = fut.result()
            except Exception as e:
                tr = src
            results[src] = tr
            done += 1
            if done % 100 == 0 or done == len(src_texts):
                elapsed = time.time() - start
                print(f"  [{lang}] {done}/{len(src_texts)} ({elapsed:.1f}s)")
                sys.stdout.flush()

    # fan-out back to all keys sharing a source
    for src_text, keys in src_to_keys.items():
        ph_list = phs(src_text)
        tr = results.get(src_text, src_text)
        tr_final = restore(tr, ph_list)
        for k in keys:
            final[lang][k] = tr_final

    lang_elapsed = time.time() - lang_start
    print(f"  {lang} done in {lang_elapsed:.1f}s (errors={len(errors[lang])})")
    sys.stdout.flush()

elapsed = time.time() - start
print(f"\nAll languages done in {elapsed:.1f}s")

# ---- merge and write ---------------------------------------------------
def merge(base_en, base_existing, new):
    out = {}
    for k in base_en.keys():
        out[k] = new.get(k, base_existing.get(k, base_en[k]))
    for k in base_existing:
        if k not in out:
            out[k] = base_existing[k]
    return out

for lang in TARGETS:
    merged = merge(en, existing[lang], final[lang])
    path = f'assets/translations/{lang}.json'
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)
        f.write('\n')
    extras = [k for k in merged if k not in en]
    print(f"Wrote {path}: {len(merged)} keys (en={len(en)} + extras={len(extras)})")

if errors:
    for lang in TARGETS:
        if errors[lang]:
            print(f"\nErrors in {lang}:")
            for src, e in errors[lang][:5]:
                print(f"  {src!r}: {e}")
print("\nDONE.")
