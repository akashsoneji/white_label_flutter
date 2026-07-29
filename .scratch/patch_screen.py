import sys, re

path = "/Users/akash/Desktop/Soneji Infotech/xelthio/whitelabel/app/lib/screens/home/brands/iquote/iquote_chart_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()

# ── 1) Add state vars ──────────────────────────────────────────────────────
needle1 = """  ChartSeriesController? _seriesController;
  String? _lastPeriod;"""
repl1 = """  ChartSeriesController? _seriesController;
  String? _lastPeriod;
  bool _didInitialRange = false;"""
if needle1 not in src:
    print("ERR: needle1 not found"); sys.exit(1)
src = src.replace(needle1, repl1, 1)

# ── 2) Reset _didInitialRange on period change ────────────────────────────
needle2 = """      final bool periodChanged = _lastPeriod != widget.ctrl.period.value;
      if (periodChanged) {
        _lastPeriod = widget.ctrl.period.value;
      }"""
repl2 = """      final bool periodChanged = _lastPeriod != widget.ctrl.period.value;
      if (periodChanged) {
        _lastPeriod = widget.ctrl.period.value;
        _didInitialRange = false;
      }"""
if needle2 not in src:
    print("ERR: needle2 not found"); sys.exit(1)
src = src.replace(needle2, repl2, 1)

# ── 3) Default visible window = 1 candle (1 minute for 1m res) ─────────────
needle3_min = """          initialVisibleMinimum:
              periodChanged && widget.ctrl.chartData.length > 50
                  ? widget
                      .ctrl
                      .chartData[widget.ctrl.chartData.length - 50]
                      .dateTime
                  : null,"""
repl3_min = """          // Default window: 1 candle (= 1 minute for 1m res).
          // Start zoomed to the newest bar; panned further back triggers loadOlderHistory.
          initialVisibleMinimum: periodChanged && widget.ctrl.chartData.length > 1
              ? widget.ctrl.chartData[widget.ctrl.chartData.length - 1].dateTime
              : null,"""
if needle3_min not in src:
    print("ERR: needle3_min not found"); sys.exit(1)
src = src.replace(needle3_min, repl3_min, 1)

# 4) Keep initialVisibleMaximum unchanged (still last candle).

# ── 5) Add onActualRangeChanged to primaryXAxis ───────────────────────────
needle5 = """          initialVisibleMinimum: periodChanged && widget.ctrl.chartData.length > 1
              ? widget.ctrl.chartData[widget.ctrl.chartData.length - 1].dateTime
              : null,
          initialVisibleMaximum:
              periodChanged && widget.ctrl.chartData.isNotEmpty
                  ? widget.ctrl.chartData.last.dateTime
                  : null,
        ),"""
repl5 = """          initialVisibleMinimum: periodChanged && widget.ctrl.chartData.length > 1
              ? widget.ctrl.chartData[widget.ctrl.chartData.length - 1].dateTime
              : null,
          initialVisibleMaximum:
              periodChanged && widget.ctrl.chartData.isNotEmpty
                  ? widget.ctrl.chartData.last.dateTime
                  : null,
          onActualRangeChanged: (args) {
            // Ignore the first fire (the initial zoom animation); after that,
            // if the user has panned to the left edge, pull older candles.
            if (_didInitialRange) {
              final ctrl = widget.ctrl;
              if (!ctrl.isLoadingOlder.value && ctrl.chartData.isNotEmpty) {
                // visibleMinimum for DateTime axes is DateTime (fallback via epoch).
                final Object? rawMin = args.visibleMinimum;
                final DateTime? visibleMin = rawMin is DateTime
                    ? rawMin
                    : rawMin != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            (rawMin as num).toInt(),
                          )
                        : null;
                if (visibleMin != null) {
                  final oldestLoaded = ctrl.chartData.first.dateTime;
                  // Trigger if the user has panned within 2 candles of the left edge.
                  final edge = oldestLoaded.add(
                    Duration(minutes: ctrl.resolution.value * 2),
                  );
                  if (visibleMin.isBefore(edge)) {
                    ctrl.loadOlderHistory();
                  }
                }
              }
            } else {
              _didInitialRange = true;
            }
          },
        ),"""
if needle5 not in src:
    print("ERR: needle5 not found"); sys.exit(1)
src = src.replace(needle5, repl5, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(src)

print("ok")
