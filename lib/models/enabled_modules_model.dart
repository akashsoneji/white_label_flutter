class EnabledModulesModel {
  final bool pmam;
  final bool copytrading;
  final bool scratchcard;
  final bool tradewin;
  final bool ibmReports;
  final bool traderTransfer;

  // Features the app showed unconditionally before this flag existed: a
  // missing key keeps them on, only an explicit `false` hides them.
  final bool priceAlert;
  final bool platform;
  final bool ib;
  final bool helpdesk;

  final bool democontest;
  final bool pageBanner;
  final bool propfirm;
  final bool tradingCentral;
  final bool externalCopyTrading;

  const EnabledModulesModel({
    this.pmam = false,
    this.copytrading = false,
    this.scratchcard = false,
    this.tradewin = false,
    this.ibmReports = false,
    this.traderTransfer = false,
    this.priceAlert = true,
    this.platform = true,
    this.ib = true,
    this.helpdesk = true,
    this.democontest = false,
    this.pageBanner = false,
    this.propfirm = false,
    this.tradingCentral = false,
    this.externalCopyTrading = false,
  });

  factory EnabledModulesModel.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value, {bool whenMissing = false}) {
      if (value == null) return whenMissing;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final v = value.toLowerCase();
        return v == 'true' || v == '1';
      }
      return whenMissing;
    }

    return EnabledModulesModel(
      pmam: parseBool(json['pmam']),
      copytrading: parseBool(json['copytrading']),
      scratchcard: parseBool(json['scratchcard']),
      tradewin: parseBool(json['tradewin']),
      ibmReports: parseBool(json['ibm_reports']),
      traderTransfer: parseBool(json['trader_transfer']),
      priceAlert: parseBool(json['price_alert'], whenMissing: true),
      platform: parseBool(json['platform'], whenMissing: true),
      ib: parseBool(json['ib'], whenMissing: true),
      helpdesk: parseBool(json['helpdesk'], whenMissing: true),
      democontest: parseBool(json['democontest']),
      pageBanner: parseBool(json['page_banner']),
      propfirm: parseBool(json['propfirm']),
      tradingCentral: parseBool(json['trading_central']),
      externalCopyTrading: parseBool(json['external_copy_trading']),
    );
  }

  static const EnabledModulesModel empty = EnabledModulesModel();
}
