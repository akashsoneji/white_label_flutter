import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/pmam_model.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:get/get.dart';

class EligibleCopyAccount {
  final int id;
  final String metaAccountNumber;
  final String accountType;
  final num balance;
  final num equity;
  final bool isEnrolled;
  final List<Map<String, dynamic>> subscriptions;

  const EligibleCopyAccount({
    required this.id,
    required this.metaAccountNumber,
    required this.accountType,
    required this.balance,
    required this.equity,
    required this.isEnrolled,
    required this.subscriptions,
  });

  factory EligibleCopyAccount.fromJson(Map<String, dynamic> json) {
    final subsRaw = json['subscriptions'];
    final subs = subsRaw is List ? subsRaw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : <Map<String, dynamic>>[];
    return EligibleCopyAccount(
      id: (json['id'] ?? 0) is num ? (json['id'] as num).toInt() : 0,
      metaAccountNumber: (json['meta_account_number'] ?? '').toString(),
      accountType: (json['account_type'] ?? '').toString(),
      balance: (json['balance'] ?? 0) as num? ?? 0,
      equity: (json['equity'] ?? 0) as num? ?? 0,
      isEnrolled: json['is_enrolled'] == true,
      subscriptions: subs,
    );
  }
}

enum LossLimitField { maxDrawdown, dailyLoss, equityFloor }

/// outOfRange: % not in (0, 100], or a negative equity floor.
enum LossLimitProblem { outOfRange, aboveMax, belowMin }

/// A loss-limit value the app refuses before calling subscribe/update.
/// [limit] is the cap (%) for [LossLimitProblem.aboveMax] and the minimum
/// (USD) for [LossLimitProblem.belowMin].
class LossLimitIssue {
  final LossLimitField field;
  final LossLimitProblem problem;
  final double limit;
  const LossLimitIssue(this.field, this.problem, [this.limit = 0]);
}

/// `GET copier/safety-settings`. Every number is a float; 0 means "none".
class CopierSafetySettings {
  final bool lossLimitsAllowed;
  final double defaultMaxDrawdownPct;
  final double defaultDailyLossPct;
  final double defaultEquityFloorPct;
  final double maxDrawdownPctMax;
  final double dailyLossPctMax;
  final double equityFloorPctMin;
  final bool termsRequired;
  final bool kycRequired;

  const CopierSafetySettings({
    this.lossLimitsAllowed = false,
    this.defaultMaxDrawdownPct = 0,
    this.defaultDailyLossPct = 0,
    this.defaultEquityFloorPct = 0,
    this.maxDrawdownPctMax = 0,
    this.dailyLossPctMax = 0,
    this.equityFloorPctMin = 0,
    this.termsRequired = false,
    this.kycRequired = false,
  });

  static const none = CopierSafetySettings();

  factory CopierSafetySettings.fromJson(Map<String, dynamic> json) {
    double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    Map<String, dynamic> m(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};
    final defaults = m(json['defaults']);
    final caps = m(json['caps']);
    return CopierSafetySettings(
      lossLimitsAllowed: json['loss_limits_allowed'] == true,
      defaultMaxDrawdownPct: n(defaults['max_drawdown_pct']),
      defaultDailyLossPct: n(defaults['daily_loss_pct']),
      defaultEquityFloorPct: n(defaults['equity_floor_pct']),
      maxDrawdownPctMax: n(caps['max_drawdown_pct_max']),
      dailyLossPctMax: n(caps['daily_loss_pct_max']),
      equityFloorPctMin: n(caps['equity_floor_pct_min']),
      termsRequired: json['terms_required'] == true,
      kycRequired: json['kyc_required'] == true,
    );
  }

  double _pctOf(double pct, num investment) =>
      double.parse((investment * pct / 100).toStringAsFixed(2));

  /// Minimum equity floor in USD for [investment]; 0 = no minimum.
  double equityFloorMinUsd(num investment) => _pctOf(equityFloorPctMin, investment);

  /// Broker default equity floor in USD for [investment]; 0 = none.
  double equityFloorDefaultUsd(num investment) => _pctOf(defaultEquityFloorPct, investment);

  /// Same checks the web drawer makes before sending. A null value means
  /// "broker default" and is always valid. Pass [investment] null to skip the
  /// equity floor minimum (edit: the server checks it against the
  /// subscription's own baseline equity, which the app does not have).
  LossLimitIssue? validate({
    double? maxDrawdownPct,
    double? dailyLossPct,
    double? equityFloor,
    num? investment,
  }) {
    if (maxDrawdownPct != null) {
      if (maxDrawdownPct <= 0 || maxDrawdownPct > 100) {
        return const LossLimitIssue(LossLimitField.maxDrawdown, LossLimitProblem.outOfRange);
      }
      if (maxDrawdownPctMax > 0 && maxDrawdownPct > maxDrawdownPctMax) {
        return LossLimitIssue(LossLimitField.maxDrawdown, LossLimitProblem.aboveMax, maxDrawdownPctMax);
      }
    }
    if (dailyLossPct != null) {
      if (dailyLossPct <= 0 || dailyLossPct > 100) {
        return const LossLimitIssue(LossLimitField.dailyLoss, LossLimitProblem.outOfRange);
      }
      if (dailyLossPctMax > 0 && dailyLossPct > dailyLossPctMax) {
        return LossLimitIssue(LossLimitField.dailyLoss, LossLimitProblem.aboveMax, dailyLossPctMax);
      }
    }
    if (equityFloor != null) {
      if (equityFloor < 0) {
        return const LossLimitIssue(LossLimitField.equityFloor, LossLimitProblem.outOfRange);
      }
      final min = investment == null ? 0.0 : equityFloorMinUsd(investment);
      if (min > 0 && equityFloor < min) {
        return LossLimitIssue(LossLimitField.equityFloor, LossLimitProblem.belowMin, min);
      }
    }
    return null;
  }
}

class CopyTradingSubscribeController extends GetxController {
  final String masterCode;
  final int planId;
  final bool autoSelectFirstAccount;
  CopyTradingSubscribeController({
    required this.masterCode,
    required this.planId,
    this.autoSelectFirstAccount = true,
  });

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final RxList<EligibleCopyAccount> eligibleAccounts = <EligibleCopyAccount>[].obs;
  final Rxn<EligibleCopyAccount> selectedAccount = Rxn<EligibleCopyAccount>();

  // subscribe params
  /// UI selection / web key (sent as `sizing_method`):
  /// fixed | proportional_equity | proportional_balance | multiplier_only | mirror_ratio | percentage_risk
  /// reverse | dynamic_lot | fixed_ratio
  final RxString sizingMethod = 'fixed'.obs;

  /// API field `copying_method` must be either `fixed` or `proportional`
  /// (backend uses this for legacy compatibility)
  final RxString copyingMethod = 'fixed'.obs;

  /// Only used when copying_method == fixed
  final RxDouble fixedLotSize = 0.10.obs;

  /// Legacy proportional multiplier (also used by proportional_* when desired)
  final RxDouble lotMultiplier = 1.0.obs;

  /// multiplier_only
  final RxDouble multiplierOnly = 2.0.obs;

  /// mirror_ratio
  final RxDouble mirrorRatio = 0.5.obs;

  /// percentage_risk
  final RxDouble percentageRisk = 2.0.obs; // %
  final RxDouble percentageRiskSlPips = 50.0.obs; // used for auto lot calc on web

  /// reverse
  final RxBool isReverse = true.obs;

  /// dynamic_lot
  final RxDouble dynamicDrawdownThreshold = 20.0.obs; // %
  final RxDouble dynamicReductionRatio = 0.5.obs; // 0-1

  /// fixed_ratio
  final RxDouble fixedRatioProfitStep = 1000.0.obs; // $ profit milestone
  final RxDouble fixedRatioLotStep = 0.01.obs; // lot add per milestone

  /// TP/SL override settings
  final RxBool overridesSlTp = false.obs;
  /// sl_tp_mode: "pip" | "dollar" (only if overridesSlTp == true)
  final RxString slTpMode = 'pip'.obs;
  final RxDouble takeProfitPips = 0.0.obs;
  final RxDouble stopLossPips = 0.0.obs;
  final RxDouble takeProfitDollar = 0.0.obs;
  final RxDouble stopLossDollar = 0.0.obs;

  /// Paid add-ons from `GET copier/purchase-options` (same shape as PAMM, own
  /// option list — ids are not interchangeable with PAMM).
  final Rx<PmamPurchaseOptions> addons = PmamPurchaseOptions.none.obs;

  /// 0 = no add-on.
  final RxInt selectedAddonId = 0.obs;

  /// Shortage reported by a 422 `insufficient_wallet`; cleared on re-pick.
  final RxnDouble serverShortage = RxnDouble();

  /// `data.purchase` of the last successful subscribe; null when no add-on.
  Map<String, dynamic>? lastPurchase;

  final Rx<CopierSafetySettings> safety = CopierSafetySettings.none.obs;
  final RxBool safetyLoading = false.obs;
  final RxString safetyError = ''.obs;
  final RxBool termsAccepted = false.obs;

  /// The client's own loss limits; null = broker default (empty field).
  /// Equity floor is in USD.
  final RxnDouble maxDrawdownPct = RxnDouble();
  final RxnDouble dailyLossPct = RxnDouble();
  final RxnDouble equityFloor = RxnDouble();

  /// `safety.effective` of the subscription being edited (null = no limit).
  Map<String, dynamic>? effectiveLimits;

  /// Called when the Start Copy last step or the Edit screen opens: the
  /// broker can change limits, terms and KYC rules at any time.
  Future<void> loadSafetySettings() async {
    safetyLoading.value = true;
    safetyError.value = '';
    try {
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierSafetySettings,
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      final data = res.data is Map ? (res.data as Map)['data'] : null;
      if (res.success && data is Map) {
        safety.value = CopierSafetySettings.fromJson(data.cast<String, dynamic>());
      } else {
        safetyError.value =
            res.message ?? TranslationUtils.tr('copy_trading_loss_limits_load_failed');
      }
    } catch (e) {
      safetyError.value = '${TranslationUtils.tr('copy_trading_loss_limits_load_failed')}: $e';
    } finally {
      safetyLoading.value = false;
    }
  }

  /// Subscribe: only the limits the client typed (left out = broker default).
  /// Nothing when the broker sets the limits, or the server rejects the call.
  Map<String, dynamic> lossLimitSubscribeFields() {
    final out = <String, dynamic>{};
    final s = safety.value;
    if (s.lossLimitsAllowed) {
      if (maxDrawdownPct.value != null) out['max_drawdown_pct'] = maxDrawdownPct.value;
      if (dailyLossPct.value != null) out['daily_loss_pct'] = dailyLossPct.value;
      if (equityFloor.value != null) out['equity_floor'] = equityFloor.value;
    }
    if (s.termsRequired) out['terms_accepted'] = termsAccepted.value;
    return out;
  }

  /// Update: a left-out key keeps the saved limit, so all 3 keys are sent and
  /// null clears a limit back to the broker default.
  Map<String, dynamic> lossLimitUpdateFields() {
    if (!safety.value.lossLimitsAllowed) return const {};
    return <String, dynamic>{
      'max_drawdown_pct': maxDrawdownPct.value,
      'daily_loss_pct': dailyLossPct.value,
      'equity_floor': equityFloor.value,
    };
  }

  PmamPurchaseOption? get selectedAddon =>
      addons.value.options.firstWhereOrNull((o) => o.id == selectedAddonId.value);

  /// Amount the wallet is short for the picked add-on (0 when it is enough).
  double get addonShortage {
    final fromServer = serverShortage.value;
    if (fromServer != null) return fromServer;
    final addon = selectedAddon;
    if (addon == null) return 0;
    final short = addon.feeInUsd - addons.value.walletBalance;
    return short > 0 ? double.parse(short.toStringAsFixed(2)) : 0;
  }

  @override
  void onInit() {
    super.onInit();
    loadEligibleAccounts(showLoading: true);
  }

  /// Re-fetched each time step 2 opens: admin can disable an option any time.
  /// A failed request keeps the current list, so a network blip does not
  /// silently drop the add-on the user picked.
  Future<void> loadPurchaseOptions() async {
    try {
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierPurchaseOptions,
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      final data = res.data is Map ? (res.data as Map)['data'] : null;
      if (res.success && data is Map) {
        addons.value = PmamPurchaseOptions.fromJson(data.cast<String, dynamic>());
      }
    } catch (_) {
      // Keep the previous options.
    }
    if (selectedAddon == null) selectedAddonId.value = 0;
    serverShortage.value = null;
  }

  void selectAddon(int id) {
    selectedAddonId.value = id;
    serverShortage.value = null;
  }

  /// Error `data` of a failed subscribe, whether the client kept the whole
  /// envelope or only its `data`.
  Map<String, dynamic>? _errorData(dynamic raw) {
    if (raw is! Map) return null;
    if (raw['code'] != null) return raw.cast<String, dynamic>();
    final inner = raw['data'];
    return inner is Map ? inner.cast<String, dynamic>() : null;
  }

  Future<void> loadEligibleAccounts({bool showLoading = false}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierEligibleAccounts,
        queryParameters: {'plan_id': planId.toString(), '_t': timestamp.toString()},
      );
      if (!res.success || res.data == null) {
        eligibleAccounts.clear();
        errorMessage.value = res.message ??
            TranslationUtils.tr('copy_trading_failed_to_load_eligible_accounts');
        return;
      }
      final data = res.data?['data'];
      if (data is! List) {
        eligibleAccounts.clear();
        errorMessage.value = TranslationUtils.tr('copy_trading_invalid_response');
        return;
      }
      final list =
          data.whereType<Map>().map((e) => EligibleCopyAccount.fromJson(e.cast<String, dynamic>())).toList();
      eligibleAccounts.assignAll(list);
      final onlyOneChoice = list.length == 1;
      if ((autoSelectFirstAccount || onlyOneChoice) && selectedAccount.value == null && list.isNotEmpty) {
        selectedAccount.value = list.first;
      }
    } catch (e) {
      eligibleAccounts.clear();
      errorMessage.value =
          '${TranslationUtils.tr('copy_trading_load_error')}: $e';
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<ApiResponse> subscribe({required num investmentAmount}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final acc = selectedAccount.value;
      if (acc == null || acc.id <= 0) {
        errorMessage.value = TranslationUtils.tr('copy_trading_select_an_account');
        return ApiResponse.error(errorMessage.value);
      }

      final payload = <String, dynamic>{
        'master_code': masterCode,
        'plan_id': planId,
        'mt5_account_id': acc.id,
        'investment_amount': investmentAmount,
        'sizing_method': sizingMethod.value,
        'copying_method': copyingMethod.value,
      };

      // Always include lot_multiplier (backend examples include it even for fixed)
      payload['lot_multiplier'] = lotMultiplier.value;

      switch (sizingMethod.value) {
        case 'fixed':
          payload['fixed_lot_size'] = fixedLotSize.value;
          break;
        case 'mirror_ratio':
          payload['mirror_ratio'] = mirrorRatio.value;
          break;
        case 'percentage_risk':
          payload['risk_percent'] = percentageRisk.value;
          break;
        case 'reverse':
          payload['is_reverse'] = isReverse.value;
          break;
        case 'dynamic_lot':
          payload['dynamic_lot_rules'] = <String, dynamic>{
            'drawdown_threshold_pct': dynamicDrawdownThreshold.value > 0 ? dynamicDrawdownThreshold.value : null,
            'multiplier': dynamicReductionRatio.value > 0 ? dynamicReductionRatio.value : null,
          };
          break;
        case 'fixed_ratio':
          payload['fixed_ratio_rules'] = <String, dynamic>{
            'profit_step': fixedRatioProfitStep.value > 0 ? fixedRatioProfitStep.value : null,
            'lot_step': fixedRatioLotStep.value > 0 ? fixedRatioLotStep.value : null,
          };
          break;
        // proportional_equity / proportional_balance / multiplier_only etc:
        default:
          // no extra required fields (except ones already included like mirror_ratio/risk_percent)
          break;
      }

      final addon = selectedAddon;
      if (addon != null) {
        payload['purchase_option_id'] = addon.id;
        // Price lock: the server rejects the purchase if the fee changed since
        // the client saw it.
        payload['purchase_option_fee'] = addon.feeInUsd;
      }

      payload.addAll(lossLimitSubscribeFields());

      payload['overrides_sl_tp'] = overridesSlTp.value;
      if (overridesSlTp.value) {
        payload['sl_tp_mode'] = slTpMode.value;
        if (slTpMode.value == 'pip') {
          payload['take_profit_pips'] = takeProfitPips.value;
          payload['stop_loss_pips'] = stopLossPips.value;
        } else {
          payload['take_profit_dollar'] = takeProfitDollar.value;
          payload['stop_loss_dollar'] = stopLossDollar.value;
        }
      }

      lastPurchase = null;
      final res = await ApiService.post(endpoint: ApiConstants.copyTradingCopierSubscribe, data: payload);
      if (res.success) {
        final data = res.data is Map ? (res.data as Map)['data'] : null;
        // `purchase` is "" (not null) when no add-on was bought.
        final purchase = data is Map ? data['purchase'] : null;
        lastPurchase = purchase is Map ? purchase.cast<String, dynamic>() : null;
        return res;
      }
      var message =
          res.message ?? TranslationUtils.tr('copy_trading_failed_to_subscribe');
      final err = _errorData(res.data);
      final code = err?['code'];
      if (code == 'insufficient_wallet') {
        serverShortage.value = double.tryParse('${err!['shortage'] ?? ''}') ?? 0;
      } else if (addon != null) {
        // Fee changed or option disabled meanwhile: show the fresh list.
        await loadPurchaseOptions();
        if (code == 'purchase_option_changed') {
          final refreshed = selectedAddon;
          final newFee = double.tryParse('${err!['fee'] ?? ''}') ??
              (refreshed?.id == addon.id ? refreshed!.feeInUsd : null);
          // Without a known new fee, the server's own text is more honest
          // than repeating the old price.
          if (newFee != null && newFee != addon.feeInUsd) {
            message = TranslationUtils.trArgs(
              'copy_trading_addon_price_changed',
              {'name': addon.name, 'fee': newFee.toStringAsFixed(2)},
            );
          }
        } else if (code == 'purchase_option_unavailable') {
          selectedAddonId.value = 0;
          message = TranslationUtils.trArgs(
            'copy_trading_addon_unavailable',
            {'name': addon.name},
          );
        }
      }
      errorMessage.value = message;
      return res;
    } catch (e) {
      errorMessage.value =
          '${TranslationUtils.tr('copy_trading_subscribe_error')}: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// PUT `/copier/subscriptions/{id}/update` — same logical fields as [subscribe] (settings only).
  Map<String, dynamic> buildUpdateSettingsPayload() {
    final sm = sizingMethod.value;
    final cm = sm == 'fixed' ? 'fixed' : 'proportional';

    double? fixedLot;
    double? lotMult;
    double? mirror;
    var isRev = false;
    double? riskPct;
    Map<String, dynamic>? dynRules;
    Map<String, dynamic>? fixedRatioRules;

    switch (sm) {
      case 'fixed':
        fixedLot = fixedLotSize.value;
        break;
      case 'proportional_equity':
      case 'proportional_balance':
      case 'multiplier_only':
        lotMult = lotMultiplier.value;
        break;
      case 'dynamic_lot':
        lotMult = lotMultiplier.value;
        dynRules = <String, dynamic>{
          'drawdown_threshold_pct': dynamicDrawdownThreshold.value > 0 ? dynamicDrawdownThreshold.value : null,
          'multiplier': dynamicReductionRatio.value > 0 ? dynamicReductionRatio.value : null,
        };
        break;
      case 'mirror_ratio':
        mirror = mirrorRatio.value;
        break;
      case 'percentage_risk':
        riskPct = percentageRisk.value;
        break;
      case 'reverse':
        isRev = isReverse.value;
        break;
      case 'fixed_ratio':
        fixedRatioRules = <String, dynamic>{
          'profit_step': fixedRatioProfitStep.value > 0 ? fixedRatioProfitStep.value : null,
          'lot_step': fixedRatioLotStep.value > 0 ? fixedRatioLotStep.value : null,
        };
        break;
      default:
        lotMult = lotMultiplier.value;
        break;
    }

    final overrides = overridesSlTp.value;
    final slTp = overrides ? slTpMode.value : null;
    double? tpPips;
    double? slPips;
    double? tpUsd;
    double? slUsd;
    if (overrides) {
      if (slTpMode.value == 'pip') {
        tpPips = takeProfitPips.value;
        slPips = stopLossPips.value;
      } else {
        tpUsd = takeProfitDollar.value;
        slUsd = stopLossDollar.value;
      }
    }

    return <String, dynamic>{
      'sizing_method': sm,
      'copying_method': cm,
      'fixed_lot_size': fixedLot,
      'lot_multiplier': lotMult,
      'mirror_ratio': mirror,
      'is_reverse': isRev,
      'risk_percent': riskPct,
      'dynamic_lot_rules': dynRules,
      'fixed_ratio_rules': fixedRatioRules,
      'overrides_sl_tp': overrides,
      'sl_tp_mode': slTp,
      'take_profit_pips': tpPips,
      'stop_loss_pips': slPips,
      'take_profit_dollar': tpUsd,
      'stop_loss_dollar': slUsd,
      ...lossLimitUpdateFields(),
    };
  }

  Future<ApiResponse> updateSubscription({required int subscriptionId}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final payload = buildUpdateSettingsPayload();
      final res = await ApiService.put(
        endpoint: ApiConstants.copyTradingCopierSubscriptionUpdate(subscriptionId),
        data: payload,
      );
      if (!res.success) {
        errorMessage.value =
            res.message ?? TranslationUtils.tr('copy_trading_failed_to_update');
      }
      return res;
    } catch (e) {
      errorMessage.value =
          '${TranslationUtils.tr('copy_trading_update_error')}: $e';
      return ApiResponse.error(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Populate controller from `subscription` object in GET `.../subscriptions/{id}/detail`.
  void applySubscriptionDetail(Map<String, dynamic> json) {
    num? n(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '');

    final sm = (json['sizing_method'] ?? '').toString();
    if (sm.isNotEmpty) {
      sizingMethod.value = sm;
    }
    final cm = (json['copying_method'] ?? '').toString();
    if (cm.isNotEmpty) {
      copyingMethod.value = cm;
    } else if (sm.isNotEmpty) {
      copyingMethod.value = sm == 'fixed' ? 'fixed' : 'proportional';
    }

    final fl = n(json['fixed_lot_size']);
    if (fl != null && fl > 0) fixedLotSize.value = fl.toDouble();

    final lm = n(json['lot_multiplier']);
    if (lm != null && lm > 0) lotMultiplier.value = lm.toDouble();

    final mr = n(json['mirror_ratio']);
    if (mr != null && mr > 0) mirrorRatio.value = mr.toDouble();

    if (json.containsKey('is_reverse')) {
      isReverse.value = json['is_reverse'] == true;
    }

    final rp = n(json['risk_percent']);
    if (rp != null && rp > 0) percentageRisk.value = rp.toDouble();

    final dyn = json['dynamic_lot_rules'];
    if (dyn is Map) {
      final m = dyn.cast<String, dynamic>();
      final dd = n(m['drawdown_threshold_pct']);
      if (dd != null && dd > 0) dynamicDrawdownThreshold.value = dd.toDouble();
      final mul = n(m['multiplier']);
      if (mul != null && mul > 0) dynamicReductionRatio.value = mul.toDouble();
    }

    final fr = json['fixed_ratio_rules'];
    if (fr is Map) {
      final m = fr.cast<String, dynamic>();
      final ps = n(m['profit_step']);
      if (ps != null && ps > 0) fixedRatioProfitStep.value = ps.toDouble();
      final ls = n(m['lot_step']);
      if (ls != null && ls > 0) fixedRatioLotStep.value = ls.toDouble();
    }

    if (json.containsKey('overrides_sl_tp')) {
      overridesSlTp.value = json['overrides_sl_tp'] == true;
    }
    final stm = (json['sl_tp_mode'] ?? '').toString();
    if (stm.isNotEmpty) slTpMode.value = stm;

    final tpp = n(json['take_profit_pips']);
    if (tpp != null && tpp > 0) takeProfitPips.value = tpp.toDouble();
    final slp = n(json['stop_loss_pips']);
    if (slp != null && slp > 0) stopLossPips.value = slp.toDouble();
    final tpd = n(json['take_profit_dollar']);
    if (tpd != null && tpd > 0) takeProfitDollar.value = tpd.toDouble();
    final sld = n(json['stop_loss_dollar']);
    if (sld != null && sld > 0) stopLossDollar.value = sld.toDouble();

    final safetyJson = json['safety'];
    if (safetyJson is Map) {
      final own = safetyJson['own'];
      if (own is Map) {
        maxDrawdownPct.value = n(own['max_drawdown_pct'])?.toDouble();
        dailyLossPct.value = n(own['daily_loss_pct'])?.toDouble();
        equityFloor.value = n(own['equity_floor'])?.toDouble();
      }
      final effective = safetyJson['effective'];
      effectiveLimits = effective is Map ? effective.cast<String, dynamic>() : null;
    }
  }
}

