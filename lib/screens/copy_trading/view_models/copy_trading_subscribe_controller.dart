import 'package:get/get.dart';

import 'package:crm_app/screens/copy_trading/data/repositories/copy_trading_repository.dart';
import 'package:crm_app/core/network/api_response.dart';

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

class CopyTradingSubscribeController extends GetxController {
  final CopyTradingRepository _repo = Get.find<CopyTradingRepository>();
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

  @override
  void onInit() {
    super.onInit();
    loadEligibleAccounts(showLoading: true);
  }

  Future<void> loadEligibleAccounts({bool showLoading = false}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final res = await _repo.getCopierEligibleAccounts(
        queryParameters: {'plan_id': planId.toString(), '_t': timestamp.toString()},
      );
      if (!res.success || res.data == null) {
        eligibleAccounts.clear();
        errorMessage.value = res.message ?? 'Failed to load eligible accounts';
        return;
      }
      final data = res.data?['data'];
      if (data is! List) {
        eligibleAccounts.clear();
        errorMessage.value = 'Invalid response';
        return;
      }
      final list =
          data.whereType<Map>().map((e) => EligibleCopyAccount.fromJson(e.cast<String, dynamic>())).toList();
      eligibleAccounts.assignAll(list);
      if (autoSelectFirstAccount && selectedAccount.value == null && list.isNotEmpty) {
        selectedAccount.value = list.first;
      }
    } catch (e) {
      eligibleAccounts.clear();
      errorMessage.value = 'Load error: $e';
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
        errorMessage.value = 'Select an account';
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

      final res = await _repo.subscribeCopier(payload: payload);
      if (!res.success) {
        errorMessage.value = res.message ?? 'Failed to subscribe';
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Subscribe error: $e';
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
    };
  }

  Future<ApiResponse> updateSubscription({required int subscriptionId}) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final payload = buildUpdateSettingsPayload();
      final res = await _repo.updateCopierSubscription(
        subscriptionId: subscriptionId,
        payload: payload,
      );
      if (!res.success) {
        errorMessage.value = res.message ?? 'Failed to update';
      }
      return res;
    } catch (e) {
      errorMessage.value = 'Update error: $e';
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
  }
}

