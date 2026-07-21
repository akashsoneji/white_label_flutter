"""Fix ALL languageService issues across meta + celestial files."""
import re, os

FILES = [
    'lib/brands/meta/meta_chart_screen.dart',
    'lib/brands/meta/meta_close_position_screen.dart',
    'lib/brands/meta/meta_history_screen.dart',
    'lib/brands/meta/meta_modify_position_screen.dart',
    'lib/brands/meta/meta_new_order_screen.dart',
    'lib/brands/meta/meta_trade_screen.dart',
    'lib/brands/meta/meta_watchlist_screen.dart',
    'lib/brands/meta/meta_theme.dart',
    'lib/brands/meta/meta_main_shell.dart',
    'lib/brands/meta/meta_settings_screen.dart',
    'lib/brands/meta/widgets/meta_native_chart.dart',
    'lib/brands/celestial/celestial_chart_screen.dart',
    'lib/brands/celestial/celestial_history_screen.dart',
    'lib/brands/celestial/celestial_trade_screen.dart',
    'lib/brands/celestial/celestial_watchlist_screen.dart',
    'lib/brands/celestial/celestial_main_shell.dart',
    'lib/brands/celestial/celestial_settings_screen.dart',
    'lib/brands/celestial/celestial_theme.dart',
]

def fix_file(filepath):
    content = open(filepath, encoding='utf-8').read()
    orig = content
    changes = 0

    # 1. Add language_service import if not present
    if "language_service.dart" not in content:
        # Find last ^import and add after it
        for m in re.finditer(r'^(import .+;)$', content, re.MULTILINE):
            last_imp = m.group(1)
        if 'last_imp' in dir():
            content = content.replace(last_imp, last_imp + "\nimport 'package:crm_app/services/language_service.dart';")
            changes += 1

    # 2. Remove 'const' from widgets that contain languageService.tr()
    # These cause "Invalid constant value" errors
    for m in re.finditer(r'\n\s*const\s+(.*?languageService\.tr\([^)]*\).*?)\n', content):
        old = m.group(0).strip()
        new = old.replace('const ', '')
        content = content.replace(old, new)
        changes += 1

    # 3. For StatelessWidget/StatefulWidget classes with languageService usage,
    #    add a getter. We add it after the first existing getter or after class declaration.
    if 'languageService' in content and 'languageService =>' not in content:
        # Find class with State< or StatelessWidget
        for m in re.finditer(r'class\s+(_?\w+)\s*(?:extends\s+State<\w+>|extends\s+StatelessWidget)', content):
            cls_start = m.start()
            cls_name = m.group(1)
            # Find the opening brace of this class
            brace_start = content.find('{', cls_start)
            if brace_start == -1:
                continue
            # Find first getter in this class
            first_getter = None
            for gm in re.finditer(rf'^\s+\w+ get \w+', content[brace_start:], re.MULTILINE):
                first_getter = brace_start + gm.start()
                break
            if first_getter:
                # Insert after the getter's line
                line_end = content.find('\n', first_getter)
                insert = content.find('\n', line_end + 1) + 1
                getter_code = f"  LanguageService get languageService => Get.find<LanguageService>();\n"
                if getter_code not in content:
                    content = content[:insert] + getter_code + content[insert:]
                    changes += 1
            break  # Only fix first class

    if content != orig:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✓ {filepath}: {changes} fixes")
    else:
        print(f"  - {filepath}: no changes")

for f in FILES:
    if os.path.exists(f):
        fix_file(f)
    else:
        print(f"  SKIP: {f}")
