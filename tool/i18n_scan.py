#!/usr/bin/env python3
"""Find hardcoded user-visible strings in Dart sources.

Line-oriented greps miss the common case where the widget call and its string
literal sit on different lines, so this walks every string literal in the file
instead and filters out the ones that are not UI copy.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

# A Dart string literal: '...' or "..." with escapes, no raw/triple handling
# needed for this codebase.
STRING_RE = re.compile(r"""(?<![\w'"])(r?)('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")""")

# Lines we never care about.
SKIP_LINE_RE = re.compile(
    r"""^\s*(//|///|import\s|export\s|part\s|library\s|@)"""
)

# A literal that is clearly not user-facing copy.
SKIP_VALUE_RE = re.compile(
    r"""^(
          \s*$                              # empty / whitespace
        | [^a-zA-Z]*$                       # no letters at all
        | .{0,2}                            # 1-2 chars ("", " ", "-", "%")
        | (assets|lib|http|https|www)[:/].* # asset paths / urls
        | .*\.(svg|png|jpg|jpeg|gif|json|ttf|otf|html|js|css|dart)$
        | [a-z0-9_]+                        # snake_case identifier / map key
        | [A-Z0-9_]+                        # SCREAMING_CASE constant
        | [a-z]+([A-Z][a-z0-9]*)+           # camelCase identifier
        | \#?[0-9a-fA-F]{6,8}               # colour literal
        | (GET|POST|PUT|PATCH|DELETE)
        | application/.*|multipart/.*|text/.*|image/.*
        | \d{4}-\d{2}-\d{2}.*               # date formats
        | [yMdHmsa/:. \-]+                  # DateFormat patterns
    )$""",
    re.VERBOSE,
)

# Call sites whose string argument is never shown to a user.
SKIP_CONTEXT_RE = re.compile(
    r"""(
          \.tr\(|TranslationUtils|languageService|LanguageService
        | AppLogger|debugPrint|print\(|log\(|throw\s|Exception\(
        | Get\.(toNamed|offNamed|offAllNamed|offAndToNamed|put|find|isRegistered)
        | Routes?\.|AppPages\.|routeName
        | SecureStorage|prefs\.|storage\.|read\(|write\(
        | json\[|data\[|response\[|\[['"]|map\[
        | Uri\.|endpoint|ApiConst|apiConst
        | fontFamily|package:|assetName
        | Key\(|ValueKey\(|GlobalKey
    )""",
    re.VERBOSE,
)


def scan_file(path):
    hits = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        lines = fh.readlines()

    for idx, line in enumerate(lines, start=1):
        if SKIP_LINE_RE.match(line):
            continue
        if SKIP_CONTEXT_RE.search(line):
            continue
        for raw_prefix, literal in STRING_RE.findall(line):
            if raw_prefix:
                continue
            value = literal[1:-1]
            if SKIP_VALUE_RE.match(value):
                continue
            # Needs at least one real word to be worth translating.
            if not re.search(r"[A-Za-z]{3,}", value):
                continue
            hits.append((idx, value.strip(), line.strip()))
    return hits


def main():
    targets = sys.argv[1:] or [LIB]
    results = {}
    for target in targets:
        target = target if os.path.isabs(target) else os.path.join(ROOT, target)
        if os.path.isfile(target):
            files = [target]
        else:
            files = [
                os.path.join(dirpath, name)
                for dirpath, _, names in os.walk(target)
                for name in names
                if name.endswith(".dart") and not name.endswith((".g.dart", ".freezed.dart"))
            ]
        for path in sorted(files):
            hits = scan_file(path)
            if hits:
                results[os.path.relpath(path, ROOT)] = hits

    total = sum(len(v) for v in results.values())
    print(f"{len(results)} files, {total} candidate strings\n")
    for path, hits in sorted(results.items(), key=lambda kv: -len(kv[1])):
        print(f"{len(hits):4d}  {path}")

    with open(os.path.join(ROOT, ".tenaxcode", "i18n_candidates.json"), "w") as fh:
        json.dump(
            {p: [{"line": l, "value": v} for l, v, _ in h] for p, h in results.items()},
            fh,
            ensure_ascii=False,
            indent=2,
        )


if __name__ == "__main__":
    main()
