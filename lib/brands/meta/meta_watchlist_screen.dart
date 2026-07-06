import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/models/search_instruments_model.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/search_instruments_controller.dart';
import 'meta_theme.dart';

/// Meta — WatchList screen (screenshot-faithful).
///
///  • Top bar: hamburger | "Quotes" | + | ✎
///  • ✎ → "Selected symbols" screen (edit / delete mode)
///  • +  → folder-tree "Add symbol" sheet
///  • Long-press a row → bottom sheet with:
///      New Order / Chart / Properties / Depth Of Market /
///      Market Statistics / Simple view mode
class MetaWatchlistScreen extends StatefulWidget {
  final ValueChanged<String>? onSymbolTap;
  const MetaWatchlistScreen({super.key, this.onSymbolTap});

  @override
  State<MetaWatchlistScreen> createState() => _MetaWatchlistScreenState();
}

class _MetaWatchlistScreenState extends State<MetaWatchlistScreen> {
  InstrumentsController get _c => Get.find<InstrumentsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.startWebSocket();
      if (!Get.isRegistered<SearchInstrumentsController>()) {
        Get.put(SearchInstrumentsController());
      }
    });
  }

  void _onSymbolTap(String symbol) {
    try {
      Get.find<ChartSocketController>().currentSymbol.value = symbol;
    } catch (_) {}
    widget.onSymbolTap?.call(symbol);
  }

  void _openAddSymbolSheet(BuildContext c) =>
      Navigator.of(c).push(_fadeRoute(_AddSymbolSheet(ic: _c)));

  void _openSelectedSymbols(BuildContext c) =>
      Navigator.of(c).push(_fadeRoute(_SelectedSymbolsScreen(ic: _c)));

  void _openRowMenu(BuildContext c, ListElement item) {
    showModalBottomSheet(
      context: c,
      backgroundColor: MetaTheme.bg(c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _RowActionSheet(symbol: item, onTap: _onSymbolTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaTheme.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Expanded(child: _favoritesBody(context)),
          ],
        ),
      ),
    );
  }

  // ── Header: hamburger | Quotes | + | ✎ ───────────────────────────────
  Widget _header(BuildContext c) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 4.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu,
                color: MetaTheme.mainText(c), size: 24.sp),
            onPressed: () {
              Scaffold.of(c).openDrawer();
            },
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              'Quotes',
              style: TextStyle(
                color: MetaTheme.headerText(c),
                fontSize: 22.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add,
                color: MetaTheme.mainText(c), size: 26.sp),
            onPressed: () => _openAddSymbolSheet(c),
          ),
          IconButton(
            icon: Icon(Icons.edit,
                color: MetaTheme.mainText(c), size: 22.sp),
            onPressed: () => _openSelectedSymbols(c),
          ),
        ],
      ),
    );
  }

  // ── Favorites body ────────────────────────────────────────────────────
  Widget _favoritesBody(BuildContext c) {
    return Obx(() {
      final items = _c.instruments.toList();
      if (items.isEmpty) return _empty(c);
      return _instrumentList(c, items);
    });
  }

  Widget _empty(BuildContext c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline_rounded,
              size: 52.sp, color: MetaTheme.subText(c)),
          SizedBox(height: 10.h),
          Text('No favorites yet',
              style: TextStyle(
                  color: MetaTheme.mainText(c),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 6.h),
          Text('Tap  +  to add symbols',
              style: TextStyle(
                  color: MetaTheme.subText(c), fontSize: 12.sp)),
        ],
      ),
    );
  }

  Widget _instrumentList(BuildContext c, List<ListElement> items) {
    return ListView.separated(
      padding: EdgeInsets.only(bottom: 8.h),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
          color: MetaTheme.divider(c), height: 1, thickness: 0.5),
      itemBuilder: (_, i) => _row(c, items[i]),
    );
  }

  Widget _row(BuildContext c, ListElement item) {
    return Obx(() {
      final price = _c.priceRx(item.symbol).value;
      final digits = price.digits > 0 ? price.digits : item.digits;

      final mid = (price.dayHigh + price.dayLow) / 2;
      final change = mid == 0 ? 0.0 : price.ask - mid;
      final pct = mid == 0 ? 0.0 : (change / mid) * 100;
      final changeColor = change > 0
          ? MetaTheme.buy(c)
          : change < 0
              ? MetaTheme.sell(c)
              : MetaTheme.mainText(c);

      return InkWell(
        onTap: () => _onSymbolTap(item.symbol),
        onLongPress: () => _openRowMenu(c, item),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%'
                      '  ${change >= 0 ? '+' : ''}${change.toStringAsFixed(digits)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: changeColor,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      item.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: MetaTheme.headerText(c),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      '11:06:26   ⌐⌐ 16',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: MetaTheme.subText(c), fontSize: 10.sp),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _fractionPrice(c, price.bid.toStringAsFixed(digits),
                        MetaTheme.sell(c)),
                    SizedBox(height: 1.h),
                    Text(
                      'L: ${price.dayLow.toStringAsFixed(digits)}',
                      style: TextStyle(
                          color: MetaTheme.subText(c), fontSize: 10.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _fractionPrice(c, price.ask.toStringAsFixed(digits),
                        MetaTheme.tpGreen),
                    SizedBox(height: 1.h),
                    Text(
                      'H: ${price.dayHigh.toStringAsFixed(digits)}',
                      style: TextStyle(
                          color: MetaTheme.subText(c), fontSize: 10.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _fractionPrice(BuildContext c, String value, Color color) {
    if (value.length < 3) {
      return Text(value,
          style: TextStyle(
              color: color, fontSize: 15.sp, fontWeight: FontWeight.w400));
    }
    final dotIdx = value.indexOf('.');
    if (dotIdx < 0 || dotIdx >= value.length - 2) {
      return Text(value,
          style: TextStyle(
              color: color, fontSize: 15.sp, fontWeight: FontWeight.w400));
    }
    final head = value.substring(0, value.length - 2);
    final tail = value.substring(value.length - 2);
    return RichText(
      text: TextSpan(children: [
        TextSpan(
            text: head,
            style: TextStyle(
                color: color, fontSize: 13.sp, fontWeight: FontWeight.w400)),
        TextSpan(
            text: tail,
            style: TextStyle(
                color: color, fontSize: 16.sp, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Helpers — fade-through route + shared folder icons
// ════════════════════════════════════════════════════════════════════════════

PageRouteBuilder<T> _fadeRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

Icon _folderIcon({double size = 22}) => Icon(
      Icons.folder,
      color: const Color(0xFFEAB308),
      size: size,
    );

Widget _homeIcon(double size) => Icon(
      Icons.home_outlined,
      size: size,
      color: const Color(0xFF65676B),
    );

Icon _chevron(double size, Color c) =>
    Icon(Icons.chevron_right, size: size, color: c);

// ════════════════════════════════════════════════════════════════════════════
// Add-symbol folder-tree sheet (screenshots #2 / #3 / #5)
// ════════════════════════════════════════════════════════════════════════════
class _AddSymbolSheet extends StatefulWidget {
  final InstrumentsController ic;
  const _AddSymbolSheet({required this.ic});

  @override
  State<_AddSymbolSheet> createState() => _AddSymbolSheetState();
}

class _AddSymbolSheetState extends State<_AddSymbolSheet> {
  final _ctrl = TextEditingController();
  SearchInstrumentsController get _sic =>
      Get.find<SearchInstrumentsController>();

  /// null → at the root folder list (Currency, Metals, Crypto, …)
  /// non-null → inside the named folder, with sub-folders shown
  String? _activeFolderId;
  String? _activeFolderLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _sic.searchInstruments(''));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: MetaTheme.bg(c),
      appBar: AppBar(
        backgroundColor: MetaTheme.bg(c),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: MetaTheme.mainText(c)),
          onPressed: () {
            if (_activeFolderId != null) {
              setState(() {
                _activeFolderId = null;
                _activeFolderLabel = null;
              });
            } else {
              Navigator.of(c).pop();
            }
          },
        ),
        title: Text(
          'Add symbol',
          style: TextStyle(color: MetaTheme.mainText(c), fontSize: 17.sp),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(c),
            _breadcrumb(c),
            Expanded(child: _body(c)),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext c) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      child: Row(
        children: [
          Icon(Icons.search, color: MetaTheme.subText(c), size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => _sic.searchInstruments(v),
              style: TextStyle(color: MetaTheme.mainText(c), fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'Find symbols',
                hintStyle: TextStyle(
                    color: MetaTheme.subText(c), fontSize: 14.sp),
                isDense: true,
                border: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE4E6EB)),
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE4E6EB)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF65676B)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Breadcrumb: Home > Currency > Crosses ────────────────────────────
  Widget _breadcrumb(BuildContext c) {
    if (_activeFolderId == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 16.w, 4.h),
        child: Row(
          children: [
            _homeIcon(18.sp),
            SizedBox(width: 6.w),
            _chevron(18, MetaTheme.subText(c)),
          ],
        ),
      );
    }
    final parts = (_activeFolderId ?? '').split('::');
    final visibleLabels = <String>[];
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      visibleLabels.add(_capitalize(parts[0]));
    }
    if (parts.length > 1 && parts[1].isNotEmpty) {
      visibleLabels.add(_capitalize(parts[1]));
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 16.w, 4.h),
      child: Row(
        children: [
          _homeIcon(18.sp),
          for (final label in visibleLabels) ...[
            SizedBox(width: 6.w),
            Text(label,
                style: TextStyle(
                    color: MetaTheme.subText(c),
                    fontSize: 14.sp,
                    decoration: TextDecoration.underline)),
            SizedBox(width: 6.w),
            _chevron(18, MetaTheme.subText(c)),
          ],
        ],
      ),
    );
  }

  Widget _body(BuildContext c) {
    return Obx(() {
      final loading = _sic.isLoading.value;
      final allSymbols = _sic.filteredSymbols;

      if (_ctrl.text.trim().isEmpty) {
        return _folderTree(c, allSymbols, loading);
      }

      if (loading && allSymbols.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (allSymbols.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.h),
            child: Text('No results',
                style: TextStyle(
                    color: MetaTheme.subText(c), fontSize: 13.sp)),
          ),
        );
      }
      return ListView.separated(
        padding: EdgeInsets.only(bottom: 16.h),
        itemCount: allSymbols.length,
        separatorBuilder: (_, __) => Divider(
            color: MetaTheme.divider(c), height: 1, thickness: 0.5),
        itemBuilder: (_, i) {
          final s = allSymbols[i];
          final symbol = s.displaySymbol;
          return _symbolRow(c, s, symbol);
        },
      );
    });
  }

  /// Build the folder tree from `SearchSymbol.categoryName` values,
  /// grouped by top-level category, with selected/total counts.
  Widget _folderTree(BuildContext c, List<SearchSymbol> all, bool loading) {
    final Map<String, _FolderGroup> groups = {};

    for (final s in all) {
      final raw = s.categoryName;
      final parts = raw.split('/');
      final root = parts[0].trim();
      final grp = groups.putIfAbsent(root, () => _FolderGroup(root));
      if (parts.length >= 2 && parts[1].trim().isNotEmpty) {
        grp.subFolders
            .putIfAbsent(parts[1].trim(), () => _FolderGroup(parts[1].trim()))
            .symbols
            .add(s);
      } else {
        grp.symbols.add(s);
      }
    }

    if (groups.isEmpty && loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => _sortFolders(a).compareTo(_sortFolders(b)));

    return ListView.separated(
      padding: EdgeInsets.only(bottom: 16.h),
      itemCount: sortedKeys.length,
      separatorBuilder: (_, __) => Divider(
          color: MetaTheme.divider(c), height: 1, thickness: 0.5),
      itemBuilder: (_, i) {
        final key = sortedKeys[i];
        final group = groups[key]!;
        return _folderGroupRow(c, group);
      },
    );
  }

  Widget _folderGroupRow(BuildContext c, _FolderGroup group) {
    final selectedCount = widget.ic.instruments.where((e) {
      return group.symbols.any((s) => s.displaySymbol == e.symbol);
    }).length;
    final totalCount = group.symbols.length;
    final hasSubfolders = group.subFolders.isNotEmpty;

    return InkWell(
      onTap: () {
        setState(() {
          _activeFolderId = group.label.toLowerCase();
          _activeFolderLabel = group.label;
        });
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            _folderIcon(size: 22.sp),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                group.label,
                style: TextStyle(
                    color: MetaTheme.mainText(c),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500),
              ),
            ),
            if (totalCount > 0 || selectedCount > 0)
              Text(
                '$selectedCount/$totalCount',
                style: TextStyle(
                    color: MetaTheme.subText(c), fontSize: 14.sp),
              ),
            if (hasSubfolders) ...[
              SizedBox(width: 6.w),
              _chevron(18, MetaTheme.subText(c)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _symbolRow(BuildContext c, SearchSymbol s, String symbol) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(c).pop();
        widget.ic.toggleFavorite(symbol,
            searchSymbol: s, hydrateAfterChange: true);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: MetaTheme.headerText(c),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500)),
                  SizedBox(height: 2.h),
                  Text(
                    s.datafeedSymbol.isNotEmpty
                        ? s.datafeedSymbol
                        : s.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: MetaTheme.subText(c), fontSize: 11.sp),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Obx(() {
              final isFav = widget.ic.isFavorite(symbol);
              if (isFav) {
                return Container(
                  width: 22.w,
                  height: 22.w,
                  decoration: const BoxDecoration(
                    color: MetaTheme.tpGreen,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.check, color: Colors.white, size: 14.sp),
                );
              }
              return Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MetaTheme.buyBlue, width: 1.5),
                ),
                child: Icon(Icons.add,
                    color: MetaTheme.buyBlue, size: 16.sp),
              );
            }),
          ],
        ),
      ),
    );
  }

  int _sortFolders(String name) {
    if (name.toLowerCase() == 'currency') return 0;
    return 100 + name.toLowerCase().codeUnitAt(0);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _FolderGroup {
  final String label;
  final List<SearchSymbol> symbols = [];
  final Map<String, _FolderGroup> subFolders = {};
  _FolderGroup(this.label);
}

// ════════════════════════════════════════════════════════════════════════════
// Selected Symbols screen (screenshots #4, #6)
// ════════════════════════════════════════════════════════════════════════════
class _SelectedSymbolsScreen extends StatefulWidget {
  final InstrumentsController ic;
  const _SelectedSymbolsScreen({required this.ic});

  @override
  State<_SelectedSymbolsScreen> createState() =>
      _SelectedSymbolsScreenState();
}

class _SelectedSymbolsScreenState extends State<_SelectedSymbolsScreen> {
  bool _deleteMode = false;
  final Set<String> _checked = <String>{};

  void _toggleDeleteMode() {
    setState(() {
      _deleteMode = !_deleteMode;
      _checked.clear();
    });
  }

  void _confirmDelete() {
    if (_checked.isEmpty) {
      setState(() => _deleteMode = false);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove symbols'),
        content:
            Text('Remove ${_checked.length} symbol(s) from your watchlist?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                final toRemove = _checked.toList();
                for (final s in toRemove) {
                  widget.ic.removeFromFavorites(s);
                }
                Navigator.pop(ctx);
                setState(() {
                  _checked.clear();
                  _deleteMode = false;
                });
              },
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: MetaTheme.bg(c),
      appBar: AppBar(
        backgroundColor: MetaTheme.bg(c),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: MetaTheme.mainText(c)),
          onPressed: () => Navigator.of(c).pop(),
        ),
        title: Text('Selected symbols',
            style: TextStyle(color: MetaTheme.mainText(c), fontSize: 17.sp)),
        actions: _deleteMode
            ? [
                // ✓ done | folder (select all) | trash
                IconButton(
                  icon: Icon(Icons.check,
                      color: MetaTheme.buyBlue, size: 24.sp),
                  tooltip: 'Done',
                  onPressed: _toggleDeleteMode,
                ),
                IconButton(
                  icon: Icon(Icons.folder_outlined,
                      color: MetaTheme.buyBlue, size: 22.sp),
                  tooltip: 'Select all',
                  onPressed: () {
                    setState(() {
                      if (_checked.length ==
                          widget.ic.instruments.length) {
                        _checked.clear();
                      } else {
                        _checked
                          ..clear()
                          ..addAll(widget.ic.instruments
                              .map((e) => e.symbol));
                      }
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: MetaTheme.buyBlue, size: 24.sp),
                  tooltip: 'Delete',
                  onPressed: _confirmDelete,
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.add,
                      color: MetaTheme.mainText(c), size: 26.sp),
                  tooltip: 'Add symbols',
                  onPressed: () {
                    Navigator.of(c).pop();
                    Navigator.of(c)
                        .push(_fadeRoute(_AddSymbolSheet(ic: widget.ic)));
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: MetaTheme.mainText(c), size: 24.sp),
                  tooltip: 'Remove symbols',
                  onPressed: _toggleDeleteMode,
                ),
              ],
      ),
      body: SafeArea(
        child: Obx(() {
          final items = widget.ic.instruments.toList();
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.h),
                child: Text('No symbols selected',
                    style: TextStyle(
                        color: MetaTheme.subText(c), fontSize: 14.sp)),
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.only(bottom: 16.h),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
                color: MetaTheme.divider(c), height: 1, thickness: 0.5),
            itemBuilder: (_, i) {
              final item = items[i];
              return _selectedRow(c, item);
            },
          );
        }),
      ),
    );
  }

  Widget _selectedRow(BuildContext c, ListElement item) {
    final isChecked = _checked.contains(item.symbol);

    return InkWell(
      onTap: _deleteMode
          ? () => setState(() {
                if (isChecked) {
                  _checked.remove(item.symbol);
                } else {
                  _checked.add(item.symbol);
                }
              })
          : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: MetaTheme.headerText(c),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500)),
                  SizedBox(height: 2.h),
                  Text(item.category ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: MetaTheme.subText(c), fontSize: 11.sp)),
                ],
              ),
            ),
            if (_deleteMode)
              SizedBox(
                width: 22.w,
                height: 22.w,
                child: isChecked
                    ? Container(
                        decoration: BoxDecoration(
                          color: MetaTheme.buyBlue,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child:
                            Icon(Icons.check, color: Colors.white, size: 16.sp),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: const Color(0xFFBFC7D4), width: 1.5),
                        ),
                      ),
              )
            else
              Icon(Icons.drag_indicator,
                  color: MetaTheme.subText(c), size: 22.sp),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Row bottom-action sheet (screenshot #7)
// ════════════════════════════════════════════════════════════════════════════
class _RowActionSheet extends StatelessWidget {
  final ListElement symbol;
  final ValueChanged<String> onTap;
  const _RowActionSheet({required this.symbol, required this.onTap});

  void _routeTo(BuildContext c, String key) {
    Navigator.of(c).pop();
    switch (key) {
      case 'new_order':
      case 'chart':
        onTap(symbol.symbol);
        break;
      case 'properties':
        _toast(c, 'Properties for ${symbol.symbol}');
        break;
      case 'dom':
        _toast(c, 'Depth Of Market for ${symbol.symbol}');
        break;
      case 'market_stats':
        _toast(c, 'Market Statistics for ${symbol.symbol}');
        break;
      case 'simple_view':
        _toast(c, 'Simple view mode toggled');
        break;
    }
  }

  void _toast(BuildContext c, String msg) {
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext c) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
              child: Text(
                '${symbol.symbol}: ${symbol.category}',
                style: TextStyle(
                    color: MetaTheme.headerText(c),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500),
              ),
            ),
            _menu(c, 'New Order', () => _routeTo(c, 'new_order')),
            _menu(c, 'Chart', () => _routeTo(c, 'chart')),
            _menu(c, 'Properties', () => _routeTo(c, 'properties')),
            _menu(c, 'Depth Of Market', () => _routeTo(c, 'dom')),
            _menu(c, 'Market Statistics', () => _routeTo(c, 'market_stats')),
            _menu(c, 'Simple view mode', () => _routeTo(c, 'simple_view')),
            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext c, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Text(
          label,
          style: TextStyle(
              color: MetaTheme.mainText(c), fontSize: 15.sp),
        ),
      ),
    );
  }
}