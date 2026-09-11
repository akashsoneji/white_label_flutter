import 'package:get/get.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
import 'package:crm_app/services/language_service.dart';

// To parse this JSON data, do
//
//     final planModel = planModelFromJson(jsonString);

import 'dart:convert';

PlanModel planModelFromJson(String str) => PlanModel.fromJson(json.decode(str));

String planModelToJson(PlanModel data) => json.encode(data.toJson());

class PlanModel {
  int? id;
  String? groupName;
  String? mt5GroupName;
  String? execution;
  String? leverage;
  String? minimumDeposit;
  String? planTitle;
  String? minimumTradeSize;
  double? spread;
  String? stopOutLevel;
  String? swapFreeDays;
  String? tradingInstruments;
  String? tradingPlatform;
  int? isDefault;
  String? status;
  int? isPrivate;
  int? isDemo;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? deletedAt;
  String? marginCallLevel;
  int? isSwapFree;
  String? maxPositions;
  String? maxPendingOrders;
  String? swapType;
  String? swapLong;
  String? swapShort;
  String? currency;
  String? groupCategory;
  int? hedgingAllowed;

  PlanModel({
    this.id,
    this.groupName,
    this.mt5GroupName,
    this.execution,
    this.leverage,
    this.minimumDeposit,
    this.planTitle,
    this.minimumTradeSize,
    this.spread,
    this.stopOutLevel,
    this.swapFreeDays,
    this.tradingInstruments,
    this.tradingPlatform,
    this.isDefault,
    this.status,
    this.isPrivate,
    this.isDemo,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.marginCallLevel,
    this.isSwapFree,
    this.maxPositions,
    this.maxPendingOrders,
    this.swapType,
    this.swapLong,
    this.swapShort,
    this.currency,
    this.groupCategory,
    this.hedgingAllowed,
  });

  PlanModel copyWith({
    int? id,
    String? groupName,
    String? mt5GroupName,
    String? execution,
    String? leverage,
    String? minimumDeposit,
    String? planTitle,
    String? minimumTradeSize,
    double? spread,
    String? stopOutLevel,
    String? swapFreeDays,
    String? tradingInstruments,
    String? tradingPlatform,
    int? isDefault,
    String? status,
    int? isPrivate,
    int? isDemo,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deletedAt,
    String? marginCallLevel,
    int? isSwapFree,
    String? maxPositions,
    String? maxPendingOrders,
    String? swapType,
    String? swapLong,
    String? swapShort,
    String? currency,
    String? groupCategory,
    int? hedgingAllowed,
  }) => PlanModel(
    id: id ?? this.id,
    groupName: groupName ?? this.groupName,
    mt5GroupName: mt5GroupName ?? this.mt5GroupName,
    execution: execution ?? this.execution,
    leverage: leverage ?? this.leverage,
    minimumDeposit: minimumDeposit ?? this.minimumDeposit,
    planTitle: planTitle ?? this.planTitle,
    minimumTradeSize: minimumTradeSize ?? this.minimumTradeSize,
    spread: spread ?? this.spread,
    stopOutLevel: stopOutLevel ?? this.stopOutLevel,
    swapFreeDays: swapFreeDays ?? this.swapFreeDays,
    tradingInstruments: tradingInstruments ?? this.tradingInstruments,
    tradingPlatform: tradingPlatform ?? this.tradingPlatform,
    isDefault: isDefault ?? this.isDefault,
    status: status ?? this.status,
    isPrivate: isPrivate ?? this.isPrivate,
    isDemo: isDemo ?? this.isDemo,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    marginCallLevel: marginCallLevel ?? this.marginCallLevel,
    isSwapFree: isSwapFree ?? this.isSwapFree,
    maxPositions: maxPositions ?? this.maxPositions,
    maxPendingOrders: maxPendingOrders ?? this.maxPendingOrders,
    swapType: swapType ?? this.swapType,
    swapLong: swapLong ?? this.swapLong,
    swapShort: swapShort ?? this.swapShort,
    currency: currency ?? this.currency,
    groupCategory: groupCategory ?? this.groupCategory,
    hedgingAllowed: hedgingAllowed ?? this.hedgingAllowed,
  );

  factory PlanModel.fromJson(Map<String, dynamic> json) => PlanModel(
    id: json["id"],
    groupName: json["group_name"]?.toString(),
    mt5GroupName: json["mt5_group_name"]?.toString(),
    execution: json["execution"]?.toString(),
    leverage: json["leverage"]?.toString(),
    minimumDeposit: json["minimum_deposit"]?.toString(),
    planTitle: json["plan_title"]?.toString(),
    minimumTradeSize: json["minimum_trade_size"]?.toString(),
    spread: json["spread"]?.toDouble(),
    stopOutLevel: json["stop_out_level"]?.toString(),
    swapFreeDays: json["swap_free_days"]?.toString(),
    tradingInstruments: json["trading_instruments"]?.toString(),
    tradingPlatform: json["trading_platform"]?.toString(),
    isDefault: json["is_default"],
    status: json["status"]?.toString(),
    isPrivate: json["is_private"],
    isDemo: json["is_demo"],
    createdAt:
        json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt:
        json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"]?.toString(),
    marginCallLevel: json["margin_call_level"]?.toString(),
    isSwapFree: json["is_swap_free"],
    maxPositions: json["max_positions"]?.toString(),
    maxPendingOrders: json["max_pending_orders"]?.toString(),
    swapType: json["swap_type"]?.toString(),
    swapLong: json["swap_long"]?.toString(),
    swapShort: json["swap_short"]?.toString(),
    currency: json["currency"]?.toString(),
    groupCategory: json["group_category"]?.toString(),
    hedgingAllowed: json["hedging_allowed"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "group_name": groupName,
    "mt5_group_name": mt5GroupName,
    "execution": execution,
    "leverage": leverage,
    "minimum_deposit": minimumDeposit,
    "plan_title": planTitle,
    "minimum_trade_size": minimumTradeSize,
    "spread": spread,
    "stop_out_level": stopOutLevel,
    "swap_free_days": swapFreeDays,
    "trading_instruments": tradingInstruments,
    "trading_platform": tradingPlatform,
    "is_default": isDefault,
    "status": status,
    "is_private": isPrivate,
    "is_demo": isDemo,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "margin_call_level": marginCallLevel,
    "is_swap_free": isSwapFree,
    "max_positions": maxPositions,
    "max_pending_orders": maxPendingOrders,
    "swap_type": swapType,
    "swap_long": swapLong,
    "swap_short": swapShort,
    "currency": currency,
    "group_category": groupCategory,
    "hedging_allowed": hedgingAllowed,
  };
}

class PlanController extends GetxController {
  final FinanceRepository _financeRepo = Get.find<FinanceRepository>();
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var plan = Rxn<PlanModel>(); // for single object
  var plans = <PlanModel>[].obs; // for list, if API returns array

  Future<void> fetchPlan({int? groupId, bool? isDemo}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Clear previous data
      plan.value = null;
      plans.clear();

      // Build request data based on parameters
      Map<String, dynamic> requestData;
      if (isDemo != null) {
        // Use is_demo or is_live parameter
        if (isDemo) {
          requestData = {"is_demo": 1};
        } else {
          requestData = {"is_live": 1};
        }
      } else if (groupId != null) {
        // Backward compatibility: use group_id if provided
        requestData = {"group_id": groupId};
      } else {
        // Default to live accounts if no parameter provided
        requestData = {"is_live": 1};
      }

      final response = await _financeRepo.postRealPlanDetails(
        data: requestData,
      );

      print('Plan API Response: ${response.data}');
      print('Request data: $requestData');

      if (response.success) {
        final data = response.data;

        // When using is_demo or is_live, API returns a Map with 'data' containing list of plans
        // When using group_id, behavior depends on groupId value
        if (data is Map && data.containsKey('data')) {
          if (data['data'] is List) {
            // Array of plans (when using is_demo/is_live or groupId == 0)
            plans.value =
                (data['data'] as List)
                    .map((e) => PlanModel.fromJson(e))
                    .toList();
            print('Fetched ${plans.length} plans');

            if (plans.isNotEmpty) {
              print("object plans json full dtaa${plans.first.toJson()}");
            }
          } else if (data['data'] is Map && groupId != null && groupId > 0) {
            // Single plan object (for backward compatibility with groupId > 0)
            plan.value = PlanModel.fromJson(data['data']);
            print('Fetched plan: ${plan.value?.groupName}');
          } else {
            errorMessage.value =
                "Expected Map with 'data' list but got ${data['data'].runtimeType}";
          }
        } else {
          errorMessage.value =
              "Expected Map with 'data' but got ${data.runtimeType}";
        }
      } else {
        errorMessage.value = response.message ?? TranslationUtils.tr('plan_controller_failed_to_fetch_plan');
      }
    } catch (e, t) {
      errorMessage.value = "Error: $e";
      print('Error in fetchPlan: $e');
      print('Error in fetchPlan: $t');
    } finally {
      isLoading.value = false;
    }
  }
}
