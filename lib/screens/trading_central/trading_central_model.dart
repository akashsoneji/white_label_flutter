/// One Trading Central page (Economic Calendar, Technical Views, ...).
class TradingCentralPage {
  final String key;
  final String label;
  final num minDeposit;
  final bool unlocked;
  final String url;

  const TradingCentralPage({
    required this.key,
    required this.label,
    required this.minDeposit,
    required this.unlocked,
    required this.url,
  });

  /// The backend sends an empty url for pages the user's deposits don't
  /// unlock yet, so both must hold before the page can be opened.
  bool get canOpen => unlocked && url.isNotEmpty;

  factory TradingCentralPage.fromJson(Map<String, dynamic> json) {
    return TradingCentralPage(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      minDeposit: _parseNum(json['min_deposit']),
      unlocked: _parseBool(json['unlocked']),
      url: json['url']?.toString() ?? '',
    );
  }
}

/// Response of `GET /api/user/trading-central`.
class TradingCentralSettings {
  final bool enabled;
  final bool canAccess;
  final bool depositRequired;
  final bool hasFirstDeposit;
  final String menuLabel;
  final num depositTotal;
  final List<TradingCentralPage> pages;

  const TradingCentralSettings({
    required this.enabled,
    required this.canAccess,
    required this.depositRequired,
    required this.hasFirstDeposit,
    required this.menuLabel,
    required this.depositTotal,
    required this.pages,
  });

  factory TradingCentralSettings.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'];
    return TradingCentralSettings(
      enabled: _parseBool(json['enabled']),
      canAccess: _parseBool(json['can_access']),
      depositRequired: _parseBool(json['deposit_required']),
      hasFirstDeposit: _parseBool(json['has_first_deposit']),
      menuLabel: json['menu_label']?.toString() ?? '',
      depositTotal: _parseNum(json['deposit_total']),
      pages: rawPages is List
          ? rawPages
              .whereType<Map>()
              .map((p) => TradingCentralPage.fromJson(
                    Map<String, dynamic>.from(p),
                  ))
              .toList()
          : const [],
    );
  }
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    return v == 'true' || v == '1';
  }
  return false;
}

num _parseNum(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}
