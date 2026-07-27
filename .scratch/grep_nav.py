with open('/Users/admin/Desktop/Project/white_label/app/white_label/lib/screens/home/brands/iquote/iquote_market_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines, 1):
    if 'onTap' in line or 'IQuoteChartScreen' in line or '_sym.setSymbol' in line or 'Get.to' in line:
        print(f'{i}: {line.rstrip()}')
