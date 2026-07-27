path = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
old = "    final res = await Get.find<ApiService>().get("
new = "    final res = await ApiService.get("
assert old in content, f"Not found: {old!r}"
content = content.replace(old, new)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
