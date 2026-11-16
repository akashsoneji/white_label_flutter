/// One entry of the chart's symbol search (integration.md §6). Each distinct
/// [category] becomes a tab.
class TenaxInstrument {
  const TenaxInstrument({
    required this.name,
    this.displayName,
    this.category,
    this.digits,
  });

  final String name;
  final String? displayName;
  final String? category;

  /// Axis and pill price formatting; guessed from the ticker when null.
  final int? digits;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (displayName != null) 'displayName': displayName,
        if (category != null) 'category': category,
        if (digits != null) 'digits': digits,
      };
}
