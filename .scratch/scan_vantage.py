#!/usr/bin/env python3
"""
Sharper Vantage-only scanner.

Reads each .dart file in the Vantage tree, strips comments, then
detects user-facing string literals passed to:
  - Text(...)
  - Text.rich(...)
  - Get.defaultDialog(title:..., middleText:..., textConfirm:..., textCancel:...)
  - Get.snackbar(...)
  - Get.dialog(AlertDialog(...))
  - AlertDialog(title:..., content:...)
  - VantagePrimaryButton / VantageOutlinedButton / VantagePillTextField
    (these take a `text` / `hintText` named param)
  - AppBar(title:...)
  - title: ... / label: ... / hintText: ... / placeholder: ... / message: ... /
    content: ... (named args)
  - const String kX = '...';
  - 'const Text(...)' inline

Catches strings on lines AFTER the opening paren (the regex scanner
missed those because of the trailing style block).

The output: same files as `_scan_vantage_strings.py`.
"""

import json
import os
import re
import sys
from collections import OrderedDict

PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__))
EN_JSON = os.path.join(PROJECT_ROOT, "assets", "translations", "en.json")
OUT_NEW = "/tmp/vantage_new_keys.json"
OUT_RAW = "/tmp/vantage_strings.txt"

SCAN_DIRS = [
    os.path.join(PROJECT_ROOT, "lib", "screens", "auth", "presentation", "brands", "vantage"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "brands", "vantage"),
    os.path.join(PROJECT_ROOT, "lib", "widgets", "vantage"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "finance", "presentation", "brands", "vantage"),
]
SCAN_FILES = [
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "trading_main_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "instruments_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "trade_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "chart_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "pending_order_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "dashboard_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "widgets", "account_header_widget.dart"),
    os.path.join(PROJECT_ROOT, "lib", "widgets", "trading_bottom_navigation.dart"),
]

# ---------- File collection ----------
def _iter_dart_files():
    out = []
    for d in SCAN_DIRS:
        if not os.path.isdir(d):
            continue
        for root, _dirs, files in os.walk(d):
            for f in files:
                if f.endswith(".dart"):
                    out.append(os.path.join(root, f))
    for f in SCAN_FILES:
        if os.path.isfile(f) and f.endswith(".dart"):
            out.append(f)
    return sorted(set(out))


# ---------- Comment stripper ----------
def _strip_comments(src: str) -> str:
    # Strip block comments
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.DOTALL)
    # Strip line comments
    src = re.sub(r"//[^\n]*", "", src)
    return src


# ---------- String-literal parser ----------
# Walks the source character by character, tracking string state and
# brace depth.  Captures any string literal whose surrounding context
# (a) is inside a Text(...), or
# (b) is the value of a named param like title:/hintText:/label:/etc.

STRING_RE = re.compile(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\\\"])*\"")

# Named params that carry user-facing strings
NAMED_USER_PARAMS = (
    "title", "subtitle", "label", "text", "hintText", "labelText",
    "placeholder", "message", "errorText", "helperText", "tooltip",
    "middleText", "contentText", "content", "textConfirm", "textCancel",
    "header", "footer",
)


def _is_unescaped_letter(c):
    return c.isalnum() or c in "_@#"


def _unescape(s: str) -> str:
    return (
        s[1:-1]
        .replace("\\'", "'")
        .replace('\\"', '"')
        .replace("\\\\", "\\")
        .replace("\\n", "\n")
        .replace("\\t", "\t")
    )


# ---------- Skip filters ----------
SKIP_EXACT = {
    "", " ", "\t", "\n", "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD", "CNY",
    "en", "ar", "es", "fr", "hi", "id", "tr", "zh",
    "vantage", "pipze", "telifox", "kantara", "gtxprime", "baazex", "skyriss",
    "riyadex", "celestial", "meta", "tenax",
    "true", "false", "null", "LTR", "RTL", "Light", "Dark",
    "1", "2", "3", "4", "5", "0", "01", "02", "03",
    "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN",
    "🌐", "👋", "🎉",
}
NUMERIC_RE = re.compile(r"^[\d\s,.\-+*/%!=<>()[\]{}]+$")
CAMEL_CASE_RE = re.compile(r"^[A-Z][A-Za-z0-9_]+$")
INTERPOLATION_RE = re.compile(r"\$\{|\$\w+")
SINGLE_NONWORD_RE = re.compile(r"^[^a-zA-Z0-9]+$")
ASCII_KEYWORD_RE = re.compile(
    r"^(package|import|library|part|class|abstract|sealed|mixin|extends|"
    r"implements|with|on|return|if|else|for|while|do|switch|case|default|"
    r"break|continue|var|final|const|late|required|void|null|true|false|"
    r"this|super|static|async|await|yield|throw|try|catch|finally|rethrow|"
    r"new|typedef|enum|operator|get|set|rebuild)$"
)
SKIP_PREFIXES = (
    "Icons.", "IconData", "Colors.", "EdgeInsets",
    "SvgPicture", "AssetImage", "NetworkImage",
    "Image.asset", "Image.network", "MemoryImage",
    "https://", "http://", "asset:", "package:",
    "flutter/", "dart:", "assets/",
    "DateFormat", "NumberFormat",
)


def _should_skip(s: str) -> bool:
    if s in SKIP_EXACT:
        return True
    if any(s.startswith(p) for p in SKIP_PREFIXES):
        return True
    if INTERPOLATION_RE.search(s):
        return True
    if NUMERIC_RE.match(s):
        return True
    if CAMEL_CASE_RE.match(s) and len(s) <= 40:
        return True
    if SINGLE_NONWORD_RE.match(s):
        return True
    if ASCII_KEYWORD_RE.match(s):
        return True
    if len(s) > 240:
        return True
    if len(s) <= 1:
        return True
    return False


# ---------- Context tracker ----------
# For each string literal position, figure out:
#   - the nearest preceding kw token (named param)
#   - whether we're inside a `Text(` or `Text.rich(` call

KEYWORD_RE = re.compile(
    r"\b(" + "|".join(re.escape(p) for p in NAMED_USER_PARAMS) + r")\s*:\s*"
)
TEXT_CALL_RE = re.compile(r"\bText(?:\.rich)?\s*\(")


def _extract_from_file(path: str, existing_value_set: set, existing_key_set: set):
    """Return OrderedDict: raw_string -> (file, line)."""
    try:
        raw_src = open(path, "r", encoding="utf-8", errors="ignore").read()
    except Exception:
        return OrderedDict()
    src = _strip_comments(raw_src)
    found = OrderedDict()

    # Walk all string literals; for each, determine context.
    for m in STRING_RE.finditer(src):
        lit_start = m.start()
        lit_end = m.end()
        s = _unescape(m.group(0))
        if _should_skip(s):
            continue
        if s in existing_value_set or s in existing_key_set:
            continue

        # Look back ~200 chars to find the nearest user-facing context
        lookback = src[max(0, lit_start - 400): lit_start]
        # Reverse-search for the nearest of: (a) `Text(` or (b) `<named>:`
        is_text_call = bool(
            re.search(r"Text(?:\.rich)?\s*\(\s*$", lookback)
        )
        kw_match = None
        for km in re.finditer(
            r"\b(" + "|".join(re.escape(p) for p in NAMED_USER_PARAMS) + r")\s*:\s*$",
            lookback,
        ):
            kw_match = km.group(1)  # take the last (most recent) one
        # Only count if no intervening `(` `)` breaks the named-arg chain.
        # Heuristic: a string is "in the named-arg of X" if the most recent
        # unmatched `(` is AFTER the keyword.  Cheap check: count parens.
        paren_balance = lookback.count("(") - lookback.count(")")
        in_named_arg = bool(kw_match) and paren_balance > 0
        # Special case: const String kX = '...';   (no `(` context)
        is_const_string = bool(
            re.search(r"const\s+String\s+\w+\s*=\s*$", lookback)
        )

        if is_text_call or in_named_arg or is_const_string:
            if s not in found:
                # compute line number in ORIGINAL src
                line = raw_src[:lit_start].count("\n") + 1
                found[s] = (path, line)
    return found


def _suggest_key(raw: str, file_path: str, used: set) -> str:
    rel = os.path.relpath(file_path, PROJECT_ROOT)
    parts = rel.replace("\\", "/").split("/")
    # keep file basename only
    base = os.path.basename(file_path).replace(".dart", "")
    base = re.sub(r"([A-Z])", r"_\1", base).lower().strip("_")
    base = re.sub(r"_+", "_", base)
    short = base

    token = re.sub(r"[^a-z0-9]+", "_", raw.lower()).strip("_")
    token = re.sub(r"_+", "_", token)
    token_parts = [t for t in token.split("_") if len(t) > 1]
    token_short = "_".join(token_parts[:6])

    slug = f"{short}_{token_short}" if token_short else short
    slug = re.sub(r"_+", "_", slug).strip("_")[:120]

    if slug in used:
        i = 2
        while f"{slug}_{i}" in used:
            i += 1
        slug = f"{slug}_{i}"
    return slug


def main():
    if not os.path.exists(EN_JSON):
        print("ERROR: en.json not found at", EN_JSON)
        sys.exit(1)
    with open(EN_JSON, "r", encoding="utf-8") as f:
        existing = json.load(f)
    existing_key_set = set(existing.keys())
    existing_value_set = {str(v) for v in existing.values() if v is not None}

    files = _iter_dart_files()
    print(f"Scanning {len(files)} Vantage-tree .dart files (sharp mode)...")

    all_strings = OrderedDict()
    for path in files:
        for raw, loc in _extract_from_file(path, existing_value_set, existing_key_set).items():
            if raw not in all_strings:
                all_strings[raw] = loc

    print(f"  raw user-facing strings not in en.json: {len(all_strings)}")

    used_keys = set(existing_key_set)
    proposed = OrderedDict()
    for raw, (file_path, line) in all_strings.items():
        key = _suggest_key(raw, file_path, used_keys)
        used_keys.add(key)
        proposed[key] = {
            "value": raw,
            "first_file": os.path.relpath(file_path, PROJECT_ROOT),
            "first_line": line,
        }

    with open(OUT_NEW, "w", encoding="utf-8") as f:
        json.dump(proposed, f, indent=2, ensure_ascii=False)
        f.write("\n")
    with open(OUT_RAW, "w", encoding="utf-8") as f:
        for raw, (fp, line) in all_strings.items():
            f.write(f"{os.path.relpath(fp, PROJECT_ROOT)}:{line}\t{raw}\n")

    print(f"\n=== Scan complete ===")
    print(f"  files scanned                    : {len(files)}")
    print(f"  raw strings not in en.json      : {len(all_strings)}")
    print(f"  proposed new keys                : {len(proposed)}")
    print(f"  output new keys    -> {OUT_NEW}")
    print(f"  output raw strings -> {OUT_RAW}")
    print()
    for key, payload in list(proposed.items()):
        v = payload["value"]
        f = payload["first_file"]
        l = payload["first_line"]
        print(f"  {key:60s}  {f}:{l}")
        print(f"     -> {v!r}")


if __name__ == "__main__":
    main()
