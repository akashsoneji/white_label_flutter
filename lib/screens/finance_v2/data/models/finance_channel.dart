import 'finance_v2_json.dart';

/// The server-priced quote of a channel card. The app does no fee or rate
/// maths: the display strings are shown as they come.
class ChannelQuote {
  /// Quotes live 120 s; resubmitting this close to the end risks a 409.
  static const Duration expiryMargin = Duration(seconds: 5);

  final String quoteId;
  final DateTime? expiresAt;
  final String youPay;
  final String youGet;
  final String rateLine;
  final String feeLine;
  final String feeLabel;

  /// The typed local amount could not be matched exactly; show the quoted
  /// figures before submit.
  final bool adjusted;

  const ChannelQuote({
    required this.quoteId,
    this.expiresAt,
    this.youPay = '',
    this.youGet = '',
    this.rateLine = '',
    this.feeLine = '',
    this.feeLabel = '',
    this.adjusted = false,
  });

  factory ChannelQuote.fromJson(Map<String, dynamic> json) {
    final display = jsonMap(json['display']);
    return ChannelQuote(
      quoteId: jsonString(json['quote_id']),
      expiresAt: jsonDateTime(json['expires_at']),
      youPay: jsonString(display['you_pay']),
      youGet: jsonString(display['you_get']),
      rateLine: jsonString(display['rate_line']),
      feeLine: jsonString(display['fee_line']),
      feeLabel: jsonString(jsonMap(json['fee'])['label']),
      adjusted: jsonBool(json['adjusted']),
    );
  }

  /// Null when [json] is not a quote object.
  static ChannelQuote? tryParse(dynamic json) {
    final map = jsonMap(json);
    if (map.isEmpty) return null;
    return ChannelQuote.fromJson(map);
  }

  bool isExpiredAt(DateTime now, {Duration margin = expiryMargin}) {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return !now.add(margin).isBefore(expiry);
  }

  /// True when the quote must be refreshed (POST /finance/channels) before
  /// it is submitted. A quote without expires_at never expires here.
  bool get isExpired => isExpiredAt(DateTime.now());
}

/// One card of POST /finance/channels.
class FinanceChannel {
  final String slug;
  final String name;
  final String logo;
  final String paymentType;
  final bool eligible;

  /// Text to show on a card that is not eligible.
  final String reason;

  /// Raw code of [reason] (AMOUNT_BELOW_MIN, CURRENCY_NOT_SUPPORTED ...).
  final String reasonCode;
  final bool isRedirect;
  final bool isOffline;

  /// Where a deposit card is submitted, as the server sent it.
  final String depositApi;
  final bool openInNewTab;
  final bool verificationReq;
  final String averageLabel;
  final String uptoLabel;
  final ChannelQuote? quote;

  const FinanceChannel({
    required this.slug,
    this.name = '',
    this.logo = '',
    this.paymentType = '',
    this.eligible = false,
    this.reason = '',
    this.reasonCode = '',
    this.isRedirect = false,
    this.isOffline = false,
    this.depositApi = '',
    this.openInNewTab = false,
    this.verificationReq = false,
    this.averageLabel = '',
    this.uptoLabel = '',
    this.quote,
  });

  factory FinanceChannel.fromJson(Map<String, dynamic> json) {
    final label = jsonString(json['label']);
    final icon = jsonString(json['icon']);
    return FinanceChannel(
      slug: jsonString(json['slug']),
      name: label.isEmpty ? jsonString(json['name']) : label,
      logo: icon.isEmpty ? jsonString(json['logo']) : icon,
      paymentType: jsonString(json['payment_type']),
      eligible: jsonBool(json['eligible']),
      reason: jsonString(json['reason']),
      reasonCode: jsonString(json['reason_code']),
      isRedirect: jsonBool(json['is_redirect']),
      isOffline: jsonBool(json['is_offline']),
      depositApi: jsonString(json['deposit_api']),
      openInNewTab: jsonBool(json['open_in_new_tab']),
      verificationReq: jsonBool(json['verification_req']),
      averageLabel: jsonString(json['average_label']),
      uptoLabel: jsonString(json['upto_label']),
      quote: ChannelQuote.tryParse(json['quote']),
    );
  }

  /// True when the card can be picked and submitted.
  bool get isSelectable => eligible && quote != null;

  /// An online gateway is submitted straight from the cards; everything else
  /// opens the details screen first.
  bool get submitsDirectly => isRedirect && !isOffline;
}
