class EnabledModulesModel {
  final bool pmam;
  final bool copytrading;
  final bool scratchcard;
  final bool tradewin;

  const EnabledModulesModel({
    this.pmam = false,
    this.copytrading = false,
    this.scratchcard = false,
    this.tradewin = false,
  });

  factory EnabledModulesModel.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final v = value.toLowerCase();
        return v == 'true' || v == '1';
      }
      return false;
    }

    return EnabledModulesModel(
      pmam: parseBool(json['pmam']),
      copytrading: parseBool(json['copytrading']),
      scratchcard: parseBool(json['scratchcard']),
      tradewin: parseBool(json['tradewin']),
    );
  }

  static const EnabledModulesModel empty = EnabledModulesModel();
}
