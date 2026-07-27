path = '/Users/admin/Desktop/Project/white_label/app/white_label/lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the problematic listen block: event is! Map is always false since stream is typed
old = """    _priceSub = ctrl.priceStream.listen((event) {
      if (event is! Map) return;
      final Map<dynamic, dynamic> raw = event as Map<dynamic, dynamic>;
      final sym = raw['symbol'];"""
new = """    _priceSub = ctrl.priceStream.listen((Map<String, dynamic> raw) {
      final sym = raw['symbol'];"""
assert old in content, "old listen block not found"
content = content.replace(old, new)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("OK")
