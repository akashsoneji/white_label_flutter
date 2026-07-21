
"""
Scan lib/screens/, lib/widgets/, lib/brands/ for unique hardcoded user-facing strings.
Output:
  - /tmp/new_keys_to_add.json        (keys + proposed values, sorted)
  - /tmp/current_en_keys.txt         (existing keys in en.json, one per line)
  - /tmp/en_stats.json               (counts)
Usage:
  python3 _scan_hardcoded_strings.py [--dry-run]
"""

import json, re, sys, os
from collections import OrderedDict

# This script lives at <project>/_scan_hardcoded_strings.py, i.e. inside the project root itself.
PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__))
EN_JSON = os.path.join(PROJECT_ROOT, "assets", "translations", "en.json")
OUT_NEW = "/tmp/new_keys_to_add.json"
OUT_CUR = "/tmp/current_en_keys.txt"
OUT_STATS = "/tmp/en_stats.json"

# Vantage UI tree — auth + home layouts + shared shell files with Vantage branches.
# Covers the Vantage parent + 7 children (pipze, telifox, kantara, gtxprime,
# baazex, skyriss, riyadex).  Celestial and Meta are separate parents and are
# out of scope for this scan.
SCOPE_FULL_DIRS = [
    os.path.join(PROJECT_ROOT, "lib", "screens"),
    os.path.join(PROJECT_ROOT, "lib", "widgets"),
    os.path.join(PROJECT_ROOT, "lib", "brands"),
]
SCAN_DIRS = [
    os.path.join(PROJECT_ROOT, "lib", "screens", "auth", "presentation", "brands", "vantage"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "brands", "vantage"),
    os.path.join(PROJECT_ROOT, "lib", "widgets", "vantage"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "finance", "presentation", "brands", "vantage"),
    # Shared shell files that branch on FlavorConfig.isVantage() / usesVantageUi():
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "trading_main_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "instruments_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "trade_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "chart_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "pending_order_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "screens", "home", "dashboard_screen.dart"),
    os.path.join(PROJECT_ROOT, "lib", "widgets", "account_header_widget.dart"),
    os.path.join(PROJECT_ROOT, "lib", "widgets", "trading_bottom_navigation.dart"),
]

# Patterns: each tuple is (label, regex-with-group-1-capturing-content).
# The regex should match a literal Dart string (single or double-quoted).
PATTERNS = [
    # Title widgets in AppBars etc.
    ("TextSingle",     r"Text\(\s*'([^'\\]*(?:\\.[^'\\]*)*)'\s*[,)]"),
    ("TextDouble",     r'Text\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*[,)]'),
    ("TextTriple",     r"Text\(\s*'''([^']*)'''\s*[,)]"),
    ("TextTripleD",    r'Text\(\s*"""([^"]*)"""\s*[,)]'),
    # Child of buttons
    ("TextChildSingle", r"child:\s*Text\(\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("TextChildDouble", r'child:\s*Text\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # ElevatedButton(text: '...')
    ("ElevatedSingle", r"ElevatedButton\(\s*text:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("ElevatedDouble", r'ElevatedButton\(\s*text:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # TextButton(text: '...')
    ("TextBtnSingle",  r"TextButton\(\s*text:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("TextBtnDouble",  r'TextButton\(\s*text:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # title: '...'
    ("TitleSingle",    r"\btitle:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("TitleDouble",    r'\btitle:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # subtitle: '...'
    ("SubtitleSingle", r"\bsubtitle:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("SubtitleDouble", r'\bsubtitle:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # hintText: '...'
    ("HintSingle",     r"\bhintText:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("HintDouble",     r'\bhintText:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # labelText: '...'
    ("LabelSingle",    r"\blabelText:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("LabelDouble",    r'\blabelText:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # placeholder: '...'
    ("PlaceholderS",   r"\bplaceholder:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("PlaceholderD",   r'\bplaceholder:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # contentText: '...'
    ("ContentSingle",  r"\bcontentText:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("ContentDouble",  r'\bcontentText:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # message: '...'
    ("MessageSingle",  r"\bmessage:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("MessageDouble",  r'\bmessage:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # errorText: '...'
    ("ErrorSingle",    r"\berrorText:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("ErrorDouble",    r'\berrorText:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # helperText: '...'
    ("HelperSingle",   r"\bhelperText:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("HelperDouble",   r'\bhelperText:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # tooltip: '...'
    ("TooltipSingle",  r"\btooltip:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("TooltipDouble",  r'\btooltip:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # ScaffoldMessenger.showSnackBar / Get.snackbar message arg
    ("SnackSingle",    r"showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("SnackDouble",    r'showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    ("GetSnackSingle", r"Get\.snackbar\(\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("GetSnackDouble", r'Get\.snackbar\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # Get.defaultDialog(title: '...', content/ middleText / text: ...)
    ("GetDlgTitleSingle", r"Get\.defaultDialog\(\s*title:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("GetDlgTitleDouble", r'Get\.defaultDialog\(\s*title:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # Get.dialog AlertDialog title content / middleText
    ("GetDlgContentSingle", r"Get\.dialog\(\s*AlertDialog\(\s*content:\s*Text\(\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("GetDlgContentDouble", r'Get\.dialog\(\s*AlertDialog\(\s*content:\s*Text\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    ("GetDlgMiddleSingle", r"Get\.dialog\(\s*AlertDialog\(\s*middleText:\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("GetDlgMiddleDouble", r'Get\.dialog\(\s*AlertDialog\(\s*middleText:\s*Text\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
    # AppBar title built from const Text('...')
    ("AppBarTitleSingle", r"title:\s*const\s+Text\(\s*'([^'\\]*(?:\\.[^'\\]*)*)'"),
    ("AppBarTitleDouble", r'title:\s*const\s+Text\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'),
]

# Filters — strings to skip
SKIP_PREFIXES = (
    "Icons.", "IconData", "Colors.", "EdgeInsets",
    "RouteSettings", "MaterialPageRoute", "Theme.of",
    "ThemeData", "SvgPicture", "AssetImage", "NetworkImage",
    "Image.asset", "Image.network", "MemoryImage",
    "https://", "http://", "asset:", "package:",
    "flutter/", "dart:", "assets/",
    "DateFormat", "NumberFormat",
    "Locale(", "DateTime(", "TimeOfDay(",
    "MainAxisAlignment.", "CrossAxisAlignment.",
    "TextAlign.", "FontWeight.", "FontStyle.",
    "MainAxisSize.", "VerticalDirection.", "HorizontalDirection.",
    "BoxFit.", "ImageRepeat.", "BlendMode.",
    "Clip.", "BorderRadius.", "BorderSide",
    "BoxShadow", "LinearGradient", "RadialGradient",
    "SweepGradient", "Alignment.", "TextDirection.",
    "TextOverflow.", "MaxLines", "SoftWrap",
    "TextCapitalization.", "LocaleName",
    "debugPrint", "print(", "debugDumpApp",
    "Colors.primaries", "Theme.of(context)",
    "kToolbarHeight", "kMinInteractiveDimension",
    "kMinFlingVelocity", "kMaxFlingVelocity",
    "BottomNavigationBarItem", "Tab(",
    "Navigator.", "Get.toNamed", "Get.off",
    "Get.offAllNamed", "Get.back", "Get.snackbar",
    "tr(", "tr(", "LanguageService", "languageService",
    "Intl.message", "Intl.plural",
    "AppLocalizations.of", "Localizations.of",
    # Empty or whitespace-only
)
SKIP_EXACT = {
    "", " ", "\t", "\n",
}
# Skip obvious variable/type names that appear inside single-quoted things
SKIP_REGEX = re.compile(
    r'^(\.\w+|[A-Z][a-zA-Z0-9_]*$|'
    r'Theme(Data)?\.of|'
    r'Get\.(find|put|putAsync|create|delete|update|isRegistered|isAwake|isSnackbarOpen|isDialogOpen|isBottomSheetOpen|isLoading)|'
    r'const\s+Text|'
    r'GetX|Obx|Rx|'
    r'\$\{|\$\w+|\w+\.toString|'
    r'^\d+$|'
    r'^[\d\s,.\-+*/%!=<>()[\]{}]+$)'  # pure math/operators
)


def iter_dart_files(dirs):
    out = []
    for d in dirs:
        if not os.path.isdir(d):
            continue
        for root, _dirs, files in os.walk(d):
            for f in files:
                if f.endswith(".dart"):
                    out.append(os.path.join(root, f))
    return sorted(out)


def extract_strings_from_file(path):
    found = []
    try:
        content = open(path, "r", encoding="utf-8", errors="ignore").read()
    except Exception:
        return found
    for _label, pat in PATTERNS:
        for m in re.finditer(pat, content):
            raw = m.group(1)
            # Unescape common Dart escapes
            raw = raw.replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\").replace("\\n", "\n").replace("\\t", "\t")
            # Strip leading/trailing whitespace that's accidental in source
            raw = raw.strip()
            if raw in SKIP_EXACT:
                continue
            # Skip code that accidentally matched (variable refs etc.)
            if SKIP_REGEX.match(raw):
                continue
            if any(raw.startswith(p) for p in SKIP_PREFIXES):
                continue
            # Skip pure numbers (e.g. "100" as a literal input hint kept as int)
            if re.fullmatch(r"\d+(\.\d+)?", raw):
                continue
            # Skip strings that look like Dart code (contain unresolved $identifier or ${expression})
            if "${" in raw:
                # user-facing strings with ${} need careful review; keep the literal here
                # and let the human review the output JSON. Don't auto-add.
                continue
            if re.search(r"\$\w+", raw):
                # 'Price: $price' etc. — code interpolation, not a static UI string
                continue
            # Skip very long single-line "code" strings (e.g. multi-line docs)
            if len(raw) > 240:
                continue
            # Skip strings that look like Dart class names (CamelCase identifiers)
            if re.fullmatch(r"[A-Z][A-Za-z0-9_]+", raw) and len(raw) <= 40:
                continue
            # Skip string that begins with a single non-letter/word char
            if len(raw) <= 2 and not raw.isalpha():
                continue
            found.append(raw)
    return found


def suggest_key(raw, file_path):
    """Return a '<section>_<field>_<purpose>' key for the string."""
    # Derive a screen/feature name from the relative path
    rel = os.path.relpath(file_path, PROJECT_ROOT)
    # e.g. lib/screens/home/dashboard_screen.dart -> parts = ['lib','screens','home','dashboard_screen.dart']
    parts = rel.replace("\\", "/").split("/")
    # Use the last 2-3 meaningful parts
    meaningful = [p for p in parts if p not in ("lib", "screens", "widgets", "brands", "presentation", "pages", "brands")]
    # Strip .dart
    base = meaningful[-1].replace(".dart", "") if meaningful else "unknown"
    # CamelCase -> snake, drop leading underscores
    base = re.sub(r'([A-Z])', r'_\1', base).lower().strip("_")
    # Collapse
    base = re.sub(r"_+", "_", base)
    # Truncate to first N words
    words = base.split("_")
    short = "_".join(words[:4])

    # Try to detect what the string is for
    lraw = raw.lower()
    if any(k in lraw for k in ("buy", "sell")) and "buy" in lraw:
        purpose = "buy"
    elif any(k in lraw for k in ("buy", "sell")) and "sell" in lraw:
        purpose = "sell"
    else:
        # generic
        purpose = None

    # Heuristic: look at pattern label via the call site is not available here,
    # so fall back to deriving from the content.
    token = re.sub(r"[^a-z0-9]+", "_", raw.lower()).strip("_")
    token = re.sub(r"_+", "_", token)
    token_parts = [t for t in token.split("_") if t and len(t) > 1]
    token_short = "_".join(token_parts[:6])

    # Pick the shorter slug that disambiguates
    if purpose:
        slug = f"{short}_{purpose}"
    elif token_short:
        slug = f"{short}_{token_short}"
    else:
        slug = short
    # Bound length
    slug = slug[:120]
    return slug


def main():
    dry_run = "--dry-run" in sys.argv

    # 1. Load existing keys
    if not os.path.exists(EN_JSON):
        print("ERROR: en.json not found at", EN_JSON)
        sys.exit(1)
    with open(EN_JSON, "r", encoding="utf-8") as f:
        existing = json.load(f)
    existing_keys = set(existing.keys())
    # also build value -> key map so we don't add duplicate VALUES under new keys
    existing_value_set = set(existing.values())

    # 2. Scan .dart files
    files = iter_dart_files(SCAN_DIRS)
    print(f"Scanning {len(files)} .dart files under {', '.join(SCAN_DIRS)} ...")

    seen = OrderedDict()
    for path in files:
        for raw in extract_strings_from_file(path):
            if raw in seen:
                continue
            if raw in existing_keys or raw in existing_value_set:
                # already present as a key or as the value of some existing key
                continue
            key = suggest_key(raw, path)
            # de-dup keys
            if key in seen.values():
                # disambiguate with a counter
                c = 2
                while f"{key}_{c}" in seen.values():
                    c += 1
                key = f"{key}_{c}"
            seen[raw] = key

    # 3. Write outputs
    new_entries = {v: k for k, v in seen.items()}  # key -> value (the string)
    # Actually we want key: value mapping (key -> string)
    new_entries = {v: k for k, v in seen.items()}  # inverts: string -> key
    # Wait — let me redo:
    new_entries = OrderedDict()
    for string_val, key in seen.items():
        new_entries[key] = string_val

    with open(OUT_NEW, "w", encoding="utf-8") as f:
        json.dump(new_entries, f, indent=2, ensure_ascii=False)
        f.write("\n")

    with open(OUT_CUR, "w", encoding="utf-8") as f:
        for k in sorted(existing_keys):
            f.write(k + "\n")

    stats = {
        "total_dart_files_scanned": len(files),
        "existing_keys_in_en_json": len(existing_keys),
        "unique_new_strings_found": len(seen),
        "new_keys_written": len(new_entries),
        "output_new_keys_json": OUT_NEW,
        "output_current_keys_txt": OUT_CUR,
    }
    with open(OUT_STATS, "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)

    # 4. Report
    print(f"\n=== Scan complete ===")
    print(f"  .dart files scanned        : {stats['total_dart_files_scanned']}")
    print(f"  existing keys in en.json   : {stats['existing_keys_in_en_json']}")
    print(f"  new unique strings found   : {stats['unique_new_strings_found']}")
    print(f"  proposed new keys          : {stats['new_keys_written']}")
    print(f"  written → {OUT_NEW}")
    print(f"  current keys  → {OUT_CUR}")
    print(f"  stats       → {OUT_STATS}")

    if dry_run:
        print("\n[DRY RUN] en.json NOT modified. Preview (first 30 new entries):")
        for i, (k, v) in enumerate(list(new_entries.items())[:30]):
            print(f"  {k}: {v!r}")
    else:
        # 5. Merge into en.json
        merged = dict(existing)
        merged.update(new_entries)
        # Stable pretty print
        with open(EN_JSON, "w", encoding="utf-8") as f:
            json.dump(merged, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"\nMerged into {EN_JSON}: {len(existing)} → {len(merged)} keys (+{len(new_entries)})")


if __name__ == "__main__":
    main()
