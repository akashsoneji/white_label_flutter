import sys

path = "/Users/akash/Desktop/Soneji Infotech/xelthio/whitelabel/app/lib/screens/home/brands/iquote/view_models/iquote_chart_controller.dart"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()

# 1) Add isLoadingOlder flag next to isChartLoading declaration.
needle1 = "  final isChartLoading = false.obs;\n"
if needle1 not in src:
    print("ERR: isChartLoading anchor not found"); sys.exit(1)

src = src.replace(
    needle1,
    needle1 + "  final isLoadingOlder = false.obs;\n",
    1,
)

# 2) Add loadOlderHistory() method right after fetchHistoryData() closes.
#    find the closing of fetchHistoryData which is: "  }\n\n  // ── account helpers (typed) ──..."
anchor2 = "  // ── account helpers (typed) ────────────────────────────────────────────\n"
if anchor2 not in src:
    print("ERR: account helpers anchor not found"); sys.exit(1)

new_method = '''  // ── load older history on pan-to-start ────────────────────────────────
  Future<void> loadOlderHistory() async {
    if (isLoadingOlder.value) return;
    if (chartData.isEmpty) return;
    if (symbol.isEmpty) return;

    isLoadingOlder.value = true;
    try {
      int resVal = 1;
      int countVal = 500;
      final earliestMs = chartData.first.dateTime.millisecondsSinceEpoch;
      // For resolution=1 (1-minute), step back by `countVal * 60` seconds.
      // (Matches the multipliers used in fetchHistoryData.)
      final fromEpoch = (earliestMs ~/ 1000) - (countVal * 60);
      final toEpoch = (earliestMs ~/ 1000);

      final api = _api ?? ApiService.instance;
      final queryParams = <String, String>{
        'symbol': symbol,
        'resolution': resVal.toString(),
        'from': fromEpoch.toString(),
        'to': toEpoch.toString(),
      };

      final response = await api.get(
        ApiConstants.marketHistory,
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['s'] == 'ok') {
          final tList = data['t'] as List<dynamic>?;
          final oList = data['o'] as List<dynamic>?;
          final hList = data['h'] as List<dynamic>?;
          final lList = data['l'] as List<dynamic>?;
          final cList = data['c'] as List<dynamic>?;
          final vList = data['v'] as List<dynamic>?;

          if (tList != null && tList.isNotEmpty &&
              oList != null && hList != null && lList != null && cList != null) {
            final List<CandleData> older = [];
            for (var i = 0; i < tList.length; i++) {
              final int timestamp = (tList[i] as num).toInt();
              // Skip if not strictly older than our current earliest.
              if (timestamp * 1000 >= earliestMs) continue;
              older.add(CandleData(
                dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
                open: (oList[i] as num).toDouble(),
                high: (hList[i] as num).toDouble(),
                low: (lList[i] as num).toDouble(),
                close: (cList[i] as num).toDouble(),
                volume: (vList != null && i < vList.length)
                    ? (vList[i] as num).toDouble()
                    : 0.0,
              ));
            }
            if (older.isNotEmpty) {
              chartData.value = [...older, ...chartData];
              print('📈 iQuote Chart: Prepended ${older.length} older candles.');
            }
          }
        }
      }
    } catch (e) {
      print('📈 iQuote Chart Error loading older history: $e');
    } finally {
      isLoadingOlder.value = false;
    }
  }

'''

src = src.replace(anchor2, new_method + anchor2, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(src)

print("ok")