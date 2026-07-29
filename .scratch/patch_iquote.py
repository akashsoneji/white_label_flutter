import sys, os

path = "/Users/akash/Desktop/Soneji Infotech/xelthio/whitelabel/app/lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()

replacements = [
    ("          case '1M':\n",  "          case '1m':\n"),
    ("          case '5M':\n",  "          case '5m':\n"),
    ("          case '15M':\n", "          case '15m':\n"),
    ("          case '30M':\n", "          case '30m':\n"),
]

for old, new in replacements:
    if old not in src:
        print(f"NOT FOUND: {old!r}")
        sys.exit(1)
    src = src.replace(old, new, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(src)

print("ok")