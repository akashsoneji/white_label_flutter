import sys
path = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/screens/home/brands/iquote/iquote_chart_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
# Remove dart:math import
content = content.replace("import 'dart:math';\n", "")
# Remove const from constructor + remove unused 'd' variable in _buildBottomPanel
content = content.replace("const IQuoteChartScreen({super.key, required this.symbol});",
                          "IQuoteChartScreen({super.key, required this.symbol});")
# Save
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("OK")
