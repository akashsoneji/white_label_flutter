#!/usr/bin/env python3
"""Audit translation JSONs for placeholder/template bugs across all 5 locales.

Bug classes caught:
  1. PHP/Dart $-style interpolation left in JSON values ($var, ${expr})
  2. Mixed placeholder styles in one value (some {x} + some $var)
  3. Empty / whitespace-only values
  4. Suspicious $-identifier that is probably a template bug, not currency
  5. Mismatched braces (uneven { vs })
  6. Placeholders that look like Dart template literals leaking into JSON
     (e.g. ${snap.data!.version}, ${p.orderId}, ${_fmt(...)})
  7. Keys present in en but missing in other locales (so users see raw key text)
  8. Keys present in other locales but not in en (orphans)
"""
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRANS = os.path.join(ROOT, "assets", "translations")

DART_INTERPOLATION = re.compile(r"\$[a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*|\$_[a-zA-Z_]+")
DART_TEMPLATE = re.compile(r"\$\{[^}]*\}")
BRACE_PLACEHOLDER = re.compile(r"\{([a-zA-Z_][a-zA-Z0-9_]*)\}")


def looks_suspicious(v: str) -> bool:
    """Heuristic: not a real $-currency, probably a template bug."""
    return bool(re.search(r"\$[a-zA-Z_]", v))


def main() -> int:
    issues = 0
    langs = ["en", "ar", "es", "hi", "tr"]
    data: dict[str, dict[str, str]] = {}

    for lang in langs:
        path = os.path.join(TRANS, f"{lang}.json")
        try:
            data[lang] = json.load(open(path, encoding="utf-8"))
        except Exception as e:
            print(f"[{lang}] ERROR parsing JSON: {e}")
            issues += 1

    for lang, d in sorted(data.items()):
        for key, val in sorted(d.items()):
            if not isinstance(val, str):
                continue
            for m in DART_INTERPOLATION.finditer(val):
                print(f"[{lang}] {key!r}: $-interp ${m.group(0)[1:]}: {val!r}")
                issues += 1
            for m in DART_TEMPLATE.finditer(val):
                print(f"[{lang}] {key!r}: Dart template literal {m.group(0)}: {val!r}")
                issues += 1
            braces = set(BRACE_PLACEHOLDER.findall(val))
            dvars = DART_INTERPOLATION.findall(val)
            if braces and dvars:
                print(f"[{lang}] {key!r}: mixed style braces={sorted(braces)} + $-vars={dvars}: {val!r}")
                issues += 1
            if val.strip() == "":
                print(f"[{lang}] {key!r}: empty value")
                issues += 1
            if "$" in val and not braces and not dvars and looks_suspicious(val):
                print(f"[{lang}] {key!r}: suspicious $-identifier: {val!r}")
                issues += 1
            if val.count("{") != val.count("}"):
                print(f"[{lang}] {key!r}: unbalanced braces (open={val.count('{')}, close={val.count('}')}): {val!r}")
                issues += 1

    en_keys = set(data.get("en", {}).keys())
    for lang in ["ar", "es", "hi", "tr"]:
        other = set(data.get(lang, {}).keys())
        missing = sorted(en_keys - other)
        extra = sorted(other - en_keys)
        if missing:
            print(f"[{lang}] missing {len(missing)} keys (fallback to en, OK if intentional): {missing[:10]}{'…' if len(missing) > 10 else ''}")
        if extra:
            print(f"[{lang}] has {len(extra)} keys NOT in en (orphans): {extra[:10]}{'…' if len(extra) > 10 else ''}")

    print(f"\nTotal issues: {issues}")
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())