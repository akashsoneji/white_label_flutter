import re
content = open('lib/brands/meta/meta_settings_screen.dart').read()
for m in re.finditer(r"(label|hintText):\s*'([^']+)'", content):
    line = content[:m.start()].count('\n')+1
    print(f"L{line}: {m.group(1)}: {m.group(2)}")
