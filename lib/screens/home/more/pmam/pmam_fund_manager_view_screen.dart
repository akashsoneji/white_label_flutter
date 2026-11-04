import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/pmam_model.dart';
import 'package:crm_app/screens/wallet/view_models/wallet_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../constants/color.dart';
import '../../../../services/pmam_service.dart';
import '../../../../controllers/pmam/pmam_controller.dart';
import '../../../../widgets/app_select_field.dart';
import '../../../../widgets/common_loading_widget.dart';
import '../../../../widgets/app_svg_back_button.dart';
import 'package:crm_app/services/language_service.dart';

class PmamFundManagerViewScreen extends StatefulWidget {
  const PmamFundManagerViewScreen({super.key});

  @override
  State<PmamFundManagerViewScreen> createState() =>
      _PmamFundManagerViewScreenState();
}

class _PmamFundManagerViewScreenState extends State<PmamFundManagerViewScreen> {
  String _managerCode = '';
  late PmamController _ctrl;

  bool _loadingProfile = true;
  bool _loadingTrades = false;
  bool _loadingOpen = false;

  /// Friendly text when `managers/{code}` fails ("Manager not found", ...).
  String _profileError = '';

  /// Set when the plan's trades / open positions call fails ("Plan not found").
  String _planError = '';

  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _selectedPlan;

  List<Map<String, dynamic>> _trades = [];
  List<Map<String, dynamic>> _openPositions = [];

  /// Plan picked from an Explore search suggestion; preselected on load.
  int? _initialPlanId;

  bool _showAllOpenPositions = false;
  bool _showAllTrades = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is String) {
      _managerCode = args;
    } else if (args is Map && args['manager_code'] is String) {
      _managerCode = args['manager_code'] as String;
      _initialPlanId = int.tryParse('${args['plan_id'] ?? ''}');
    }
    if (Get.isRegistered<PmamController>()) {
      _ctrl = Get.find<PmamController>();
    } else {
      _ctrl = Get.put(PmamController());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    if (_managerCode.isEmpty) {
      setState(() => _loadingProfile = false);
      return;
    }
    setState(() {
      _loadingProfile = true;
      _profileError = '';
    });
    try {
      // Doc flow: the profile always refreshes enrollments + eligible accounts
      // so "Invest now" vs "My investment" reflects the latest status.
      Future.wait([
        _ctrl.loadEnrollments(),
        _ctrl.loadEligibleAccounts(),
      ]).then((_) {
        if (mounted) setState(() {});
      });
      final resp = await PmamService.getManagerProfile(_managerCode);
      if (!resp.success) {
        _profile = {};
        _profileError = PmamController.friendlyError(
          resp.message,
          TranslationUtils.tr('pmam_fund_manager_view_manager_not_found'),
        );
      } else if (resp.data is Map) {
        final root = Map<String, dynamic>.from(resp.data as Map);
        final data = (root['data'] is Map)
            ? Map<String, dynamic>.from(root['data'] as Map)
            : <String, dynamic>{};
        _profile = data;
        final plansRaw = data['plans'];
        _plans = (plansRaw is List)
            ? plansRaw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : <Map<String, dynamic>>[];
        _selectedPlan = _plans.firstWhereOrNull(
              (p) => int.tryParse('${p['id']}') == _initialPlanId,
            ) ??
            (_plans.isNotEmpty ? _plans.first : null);
        if (_selectedPlan != null) {
          _loadPlanData(_selectedPlan!);
        }
      }
    } catch (_) {
      _profile = {};
      _profileError =
          TranslationUtils.tr('pmam_fund_manager_view_manager_not_found');
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadPlanData(Map<String, dynamic> plan) async {
    final planId = int.tryParse(plan['id'].toString()) ?? 0;
    if (planId == 0) return;
    setState(() {
      _loadingOpen = true;
      _loadingTrades = true;
      _openPositions = [];
      _trades = [];
      _planError = '';
    });
    try {
      final results = await Future.wait([
        PmamService.getManagerOpenPositions(
          managerCode: _managerCode,
          planId: planId,
        ),
        PmamService.getManagerTradesPublic(
          managerCode: _managerCode,
          planId: planId,
        ),
      ]);

      final openResp = results[0];
      final tradesFailed = results[1];
      final failed = !openResp.success
          ? openResp
          : (!tradesFailed.success ? tradesFailed : null);
      if (failed != null) {
        _planError = PmamController.friendlyError(
          failed.message,
          TranslationUtils.tr('pmam_failed_to_load_plans'),
        );
      }
      if (openResp.success && openResp.data is Map) {
        final root = Map<String, dynamic>.from(openResp.data as Map);
        final data = root['data'];
        if (data is List) {
          _openPositions = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      final tradesResp = results[1];
      if (tradesResp.success && tradesResp.data is Map) {
        final root = Map<String, dynamic>.from(tradesResp.data as Map);
        final data = root['data'];
        if (data is Map) {
          final rows = data['trades'];
          if (rows is List) {
            _trades = rows
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        } else if (data is List) {
          _trades = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (_) {
      _planError = TranslationUtils.tr('pmam_failed_to_load_plans');
    } finally {
      if (mounted) {
        setState(() {
          _loadingOpen = false;
          _loadingTrades = false;
        });
      }
    }
  }

  /// True when the user has a pending/active enrollment with this manager
  /// (doc 2.2), or the profile itself says so.
  bool get _hasInvestment {
    if (_profile['is_enrolled'] == true) return true;
    return _ctrl.enrollments.any((e) {
      final status = (e['status'] ?? '').toString();
      return e['manager_code']?.toString() == _managerCode &&
          (status == 'pending' || status == 'active');
    });
  }

  String get _initials {
    final name = (_profile['manager_name'] ?? '').toString().trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  String _money(double v) {
    final val = v.abs();
    final prefix = v < 0 ? '-\$' : '\$';
    if (val >= 1000000) return '$prefix${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '$prefix${(val / 1000).toStringAsFixed(2)}K';
    return '$prefix${val.toStringAsFixed(2)}';
  }

  /// Success path of the Invest drawer: server message (+ add-on receipt when
  /// `data.purchase` is a map), wallet refresh, and the enrolled badge.
  void _onJoined(PmamJoinResult result) {
    final purchase = result.purchase;
    var message = result.message;
    if (purchase != null) {
      message += '\n${TranslationUtils.trArgs('pmam_addon_purchased', {
            'name': (purchase['option_name'] ?? '').toString(),
            'amount': _num(purchase['amount']).toStringAsFixed(2),
            'wallet': _num(purchase['wallet_balance_after']).toStringAsFixed(2),
          })}';
      if (Get.isRegistered<WalletController>()) {
        Get.find<WalletController>().fetchWalletData();
      }
    }
    CustomToastService.showSuccess(message: message);
    if (mounted) setState(() {});
  }

  void _showInvestSheet(BuildContext btnCtx) {
    if (_selectedPlan == null) {
      Get.snackbar(
        TranslationUtils.tr('general_not_available'),
        TranslationUtils.tr('pmam_no_active_plans_to_invest'),
        backgroundColor: Colors.orange,
        colorText: AppColors.onColoredBackground,
      );
      return;
    }
    Map<String, dynamic>? selectedAccount;
    Map<String, dynamic> sheetPlan = _selectedPlan!;
    bool accountsLoading = true;
    bool firstLoadTriggered = false;
    bool submitting = false;
    bool sheetOpen = true;
    PmamPurchaseOptions addons = PmamPurchaseOptions.none;
    int selectedAddonId = 0; // 0 = no add-on
    double? serverShortage;
    final amountCtrl = TextEditingController();
    late StateSetter setSheetState;

    void updateSheet(VoidCallback fn) {
      if (sheetOpen) setSheetState(fn);
    }

    void selectAccount(Map<String, dynamic>? acc) {
      selectedAccount = acc;
      amountCtrl.text = acc == null
          ? ''
          : _num(acc['available_balance']).toStringAsFixed(2);
    }

    // Doc flow: eligible accounts + purchase options on every drawer open.
    Future<void> loadSheetData(int pId) async {
      updateSheet(() => accountsLoading = true);
      final accountsFuture = _ctrl.loadEligibleAccounts(pId);
      final fresh = await _ctrl.loadPurchaseOptions();
      await accountsFuture;
      updateSheet(() {
        addons = fresh;
        if (!fresh.options.any((o) => o.id == selectedAddonId)) {
          selectedAddonId = 0;
        }
        if (_ctrl.eligibleAccounts.length == 1) {
          selectAccount(_ctrl.eligibleAccounts.first);
        }
        accountsLoading = false;
      });
    }

    final labelStyle = AppTextStyles.bodyText.copyWith(
      fontSize: 13.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    final hintStyle = AppTextStyles.bodyText.copyWith(
      fontSize: 11.sp,
      color: AppColors.textGrey,
    );

    showModalBottomSheet(
      context: btnCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          setSheetState = setState;

          final planId = int.tryParse(sheetPlan['id'].toString()) ?? 0;
          if (!firstLoadTriggered && planId > 0) {
            firstLoadTriggered = true;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => loadSheetData(planId));
          }

          final double commission = _num(sheetPlan['commission_percentage']);
          final double minInvest = _num(sheetPlan['minimum_investment']);
          final double minAllowed = minInvest < 1 ? 1 : minInvest;
          final String planName =
              (sheetPlan['plan_name'] ?? 'Plan').toString();

          final double available = _num(selectedAccount?['available_balance']);
          final String amountText = amountCtrl.text.trim();
          final double amount = double.tryParse(amountText) ?? 0;

          String? amountError;
          if (selectedAccount != null) {
            if (available < minAllowed) {
              amountError = TranslationUtils.tr(
                  'pmam_fund_manager_view_insufficient_balance_for_this_plan');
            } else if (amountText.isNotEmpty && amount < minAllowed) {
              amountError = TranslationUtils.trArgs(
                  'pmam_amount_below_minimum',
                  {'amount': minAllowed.toStringAsFixed(2)});
            } else if (amount > available) {
              amountError = TranslationUtils.tr('pmam_amount_above_available');
            }
          }

          final PmamPurchaseOption? addon =
              addons.options.firstWhereOrNull((o) => o.id == selectedAddonId);
          final double localShortage =
              addon == null ? 0 : addon.feeInUsd - addons.walletBalance;
          final double shortage =
              serverShortage ?? (localShortage > 0 ? localShortage : 0);

          final bool canInvest = selectedAccount != null &&
              !submitting &&
              amountText.isNotEmpty &&
              amountError == null &&
              shortage <= 0;

          Future<void> submit() async {
            updateSheet(() => submitting = true);
            final result = await _ctrl.requestJoin(
              planId: planId,
              accountId: int.tryParse('${selectedAccount!['id']}') ?? 0,
              amount: amount,
              purchaseOptionId: addon?.id,
            );
            if (result.ok) {
              if (sheetOpen) Navigator.pop(ctx);
              _onJoined(result);
              return;
            }
            if (result.shortage != null) {
              updateSheet(() {
                submitting = false;
                serverShortage = result.shortage;
              });
              return;
            }
            CustomToastService.showError(message: result.message);
            // A stale or switched-off add-on is a 422 too: refresh the list.
            final fresh = await _ctrl.loadPurchaseOptions();
            updateSheet(() {
              submitting = false;
              addons = fresh;
              if (!fresh.options.any((o) => o.id == selectedAddonId)) {
                selectedAddonId = 0;
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
              ),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(20.w, 16.h, 12.w, 12.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TranslationUtils.tr(
                              'pmam_fund_manager_view_invest_in_plan'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            Icons.close,
                            size: 22.sp,
                            color: AppColors.textGrey,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.border),

                  // ── Body ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Select Plan ──
                          Text(
                            TranslationUtils.tr(
                                'pmam_fund_manager_view_select_plan'),
                            style: labelStyle,
                          ),
                          SizedBox(height: 8.h),
                          if (_plans.length > 1)
                            AppSelectField<Map<String, dynamic>>(
                              value: sheetPlan,
                              hint: TranslationUtils.tr('pmam_select_a_plan'),
                              sheetTitle: TranslationUtils.tr(
                                  'pmam_fund_manager_view_select_plan'),
                              backgroundColor: AppColors.card,
                              valueEquals: (a, b) =>
                                  a['id'].toString() == b['id'].toString(),
                              options: _plans.map((p) {
                                final pName =
                                    (p['plan_name'] ?? 'Plan').toString();
                                final pComm = _num(p['commission_percentage']);
                                return AppSelectOption<Map<String, dynamic>>(
                                  value: p,
                                  title:
                                      '$pName - ${pComm.toStringAsFixed(2)}% ${TranslationUtils.tr('general_commission')}',
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                updateSheet(() {
                                  sheetPlan = val;
                                  selectAccount(null);
                                });
                                final newPlanId =
                                    int.tryParse(val['id'].toString()) ?? 0;
                                if (newPlanId > 0) loadSheetData(newPlanId);
                              },
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 13.h,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: AppColors.border),
                                color: AppColors.onColoredBackground,
                              ),
                              child: Text(
                                '$planName - ${commission.toStringAsFixed(2)}% ${TranslationUtils.tr('general_commission')}',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.isDarkMode
                                      ? AppColors.pureBlack
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                          SizedBox(height: 6.h),
                          Text(
                            '${TranslationUtils.tr('pmam_manager_detail_screen_min_investment')}: \$${minInvest.toStringAsFixed(2)}',
                            style: hintStyle,
                          ),
                          SizedBox(height: 20.h),

                          // ── Trading Account ──
                          Text(
                            TranslationUtils.tr(
                                'copy_trading_edit_plan_trading_account'),
                            style: labelStyle,
                          ),
                          SizedBox(height: 8.h),
                          if (accountsLoading)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(12.h),
                                child: CommonLoadingWidget(
                                  size: 22,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          else if (_ctrl.eligibleAccounts.isEmpty) ...[
                            _sheetNotice(
                              TranslationUtils.tr(
                                  'pmam_no_eligible_investor_account'),
                              AppColors.textGrey,
                            ),
                            SizedBox(height: 12.h),
                            // No live account to invest from: close the sheet
                            // and open the live-account picker. Reopening
                            // Invest Now reloads the eligible accounts.
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Get.toNamed(AppPages.CHOOSE_ACCOUNT);
                              },
                              icon: Icon(
                                Icons.add_rounded,
                                size: 18.sp,
                                color: AppColors.onColoredBackground,
                              ),
                              label: Text(
                                TranslationUtils.tr(
                                    'create_account_create_button'),
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onColoredBackground,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                elevation: 0,
                                minimumSize: Size(double.infinity, 46.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                            ),
                          ]
                          else
                            AppSelectField<Map<String, dynamic>>(
                              value: selectedAccount,
                              hint: TranslationUtils.tr(
                                  'create_account_select_account'),
                              sheetTitle: TranslationUtils.tr(
                                  'pmam_manager_detail_screen_select_trading_account'),
                              backgroundColor: AppColors.card,
                              valueEquals: (a, b) =>
                                  a['id'].toString() == b['id'].toString(),
                              options: _ctrl.eligibleAccounts.map((acc) {
                                final no =
                                    acc['meta_account_number']?.toString() ??
                                        '-';
                                final avail = _num(acc['available_balance']);
                                return AppSelectOption<Map<String, dynamic>>(
                                  value: acc,
                                  title: no,
                                  subtitle:
                                      '${TranslationUtils.tr('ibm_available')}: \$${avail.toStringAsFixed(2)}',
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  updateSheet(() => selectAccount(val)),
                            ),

                          // ── Amount ──
                          if (selectedAccount != null) ...[
                            SizedBox(height: 16.h),
                            Text(
                              TranslationUtils.tr('pmam_investment_amount'),
                              style: labelStyle,
                            ),
                            SizedBox(height: 8.h),
                            TextField(
                              controller: amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              onChanged: (_) => updateSheet(() {}),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 14.sp,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                prefixText: '\$ ',
                                errorText: amountError,
                                errorMaxLines: 2,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 12.h,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide:
                                      BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide:
                                      BorderSide(color: AppColors.primary),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide:
                                      BorderSide(color: AppColors.error),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide:
                                      BorderSide(color: AppColors.error),
                                ),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '${TranslationUtils.tr('ibm_available')}: \$${available.toStringAsFixed(2)}',
                              style: hintStyle,
                            ),
                          ],

                          // ── Add-on (only when the server enables it) ──
                          if (addons.isAvailable) ...[
                            SizedBox(height: 16.h),
                            Text(
                              TranslationUtils.tr('pmam_addon_label'),
                              style: labelStyle,
                            ),
                            SizedBox(height: 8.h),
                            AppSelectField<int>(
                              value: selectedAddonId,
                              hint: TranslationUtils.tr('pmam_addon_none'),
                              sheetTitle: TranslationUtils.tr('pmam_addon_label'),
                              backgroundColor: AppColors.card,
                              valueEquals: (a, b) => a == b,
                              options: [
                                AppSelectOption<int>(
                                  value: 0,
                                  title: TranslationUtils.tr('pmam_addon_none'),
                                ),
                                ...addons.options.map(
                                  (o) => AppSelectOption<int>(
                                    value: o.id,
                                    title:
                                        '${o.name} — \$${o.feeInUsd.toStringAsFixed(2)}',
                                    subtitle: o.description.isEmpty
                                        ? null
                                        : o.description,
                                  ),
                                ),
                              ],
                              onChanged: (val) => updateSheet(() {
                                selectedAddonId = val ?? 0;
                                serverShortage = null;
                              }),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              TranslationUtils.trArgs('pmam_wallet_balance', {
                                'amount':
                                    addons.walletBalance.toStringAsFixed(2),
                              }),
                              style: hintStyle,
                            ),
                          ],

                          // ── Wallet shortage (local check or server 422) ──
                          if (shortage > 0) ...[
                            SizedBox(height: 10.h),
                            _sheetNotice(
                              TranslationUtils.trArgs('pmam_wallet_shortage', {
                                'amount': shortage.toStringAsFixed(2),
                              }),
                              AppColors.error,
                              action: TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Get.toNamed(AppPages.DEPOSIT);
                                },
                                child: Text(
                                  TranslationUtils.tr('pmam_deposit_to_wallet'),
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 20.h),

                          // ── Summary card ──
                          if (selectedAccount != null)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _summaryRow(
                                    TranslationUtils.tr('pmam_plan_label'),
                                    planName,
                                    isFirst: true,
                                  ),
                                  _summaryDivider(),
                                  _summaryRow(
                                    TranslationUtils.tr('general_commission'),
                                    '${commission.toStringAsFixed(2)}%',
                                  ),
                                  _summaryDivider(),
                                  _summaryRow(
                                    TranslationUtils.tr(
                                        'pmam_investment_amount'),
                                    '\$${amount.toStringAsFixed(2)}',
                                    isLast: addon == null,
                                  ),
                                  if (addon != null) ...[
                                    _summaryDivider(),
                                    _summaryRow(
                                      TranslationUtils.tr('pmam_addon_label'),
                                      '${addon.name} — \$${addon.feeInUsd.toStringAsFixed(2)}',
                                      isLast: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),
                  Divider(height: 1, color: AppColors.border),

                  // ── Bottom buttons ──
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 16.h,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 13.h),
                              ),
                              child: Text(
                                TranslationUtils.tr('account_management_cancel'),
                                style: AppTextStyles.bodyText.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: canInvest ? submit : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.textPrimary,
                                disabledBackgroundColor: AppColors.textPrimary
                                    .withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 13.h),
                                elevation: 0,
                              ),
                              child: submitting
                                  ? SizedBox(
                                      height: 18.h,
                                      child: CommonLoadingWidget(
                                        size: 18,
                                        color: AppColors.card,
                                      ),
                                    )
                                  : Text(
                                      TranslationUtils.tr(
                                          'pmam_fund_manager_view_confirm_investment'),
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: AppColors.isDarkMode
                                            ? AppColors.pureBlack
                                            : AppColors.onColoredBackground,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      sheetOpen = false;
      amountCtrl.dispose();
    });
  }

  /// Small bordered message used inside the Invest drawer.
  Widget _sheetNotice(String text, Color color, {Widget? action}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (action != null)
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textGrey),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Divider(height: 1, color: AppColors.border);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.card,
        elevation: 0,
        centerTitle: true,
        leading: AppSvgBackButton(
          onPressed: () => Get.back(),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
        title: Text(
          TranslationUtils.tr('pmam_fund_manager_view_fund_manager'),
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loadingProfile
          ? Center(child: CircularProgressIndicator())
          : _profile.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
                children: [
                  _buildTopCard(),
                  if (_planError.isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    _buildPlanErrorBanner(),
                  ],
                  SizedBox(height: 10.h),
                  _buildPerformanceChart(),
                  SizedBox(height: 10.h),
                  _buildOpenPositionsSection(),
                  SizedBox(height: 10.h),
                  _buildTradeHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildTopCard() {
    final name = (_profile['manager_name'] ?? '—').toString();
    final since = (_profile['member_since'] ?? '').toString();
    final s = (_profile['performance_summary'] is Map)
        ? Map<String, dynamic>.from(_profile['performance_summary'] as Map)
        : <String, dynamic>{};

    final profit = _num(s['total_profit']);
    final pnl = _num(s['total_pnl_value']);
    final aum = _num(_profile['total_aum']);
    final investors = _num(_profile['total_investors']).toInt();

    double commission = 0;
    double minInv = 0;
    String risk = TranslationUtils.tr('pmam_risk_1_title');
    double drawdown = 0;
    String description = '';

    if (_selectedPlan != null) {
      commission = _num(_selectedPlan!['commission_percentage']);
      minInv = _num(_selectedPlan!['minimum_investment']);
      risk = (_selectedPlan!['risk_information'] ??
              TranslationUtils.tr('pmam_risk_1_title'))
          .toString();
      description = (_selectedPlan!['strategy_description'] ?? '').toString();
      if (_selectedPlan!['performance'] is Map) {
        drawdown = _num(_selectedPlan!['performance']['max_drawdown']);
      }
    }

    final hasInvestment = _hasInvestment;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 50.w,
                      height: 50.h,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          PositionedDirectional(
                            start: 3.w,
                            top: 1.h,
                            child: CircleAvatar(
                              radius: 22.r,
                              backgroundColor: AppColors.chipSurface,
                              child: Text(
                                _initials,
                                style: AppTextStyles.bodyText.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.card,
                              ),
                              padding: EdgeInsets.all(1),
                              child: Icon(
                                Icons.check_circle,
                                size: 14.sp,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6.w,
                            runSpacing: 2.h,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.chipSurface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  TranslationUtils.tr('pmam_fund_manager_caps'),
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                since.isNotEmpty
                                    ? TranslationUtils.trArgs(
                                        'pmam_member_since', {'date': since})
                                    : TranslationUtils.tr(
                                        'pmam_verified_manager'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 7.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield,
                            size: 11.sp,
                            color: const Color(0xFFD97706),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            risk.isNotEmpty
                                ? risk
                                : TranslationUtils.tr('pmam_moderate_risk'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!hasInvestment) {
                        _showInvestSheet(context);
                      } else {
                        Get.toNamed(
                          Routes.PMAM_MY_INVESTMENT,
                          arguments: {'managerCode': _managerCode},
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasInvestment
                          ? const Color(0xFF10B981)
                          : AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      hasInvestment
                          ? TranslationUtils.tr('pmam_my_investment')
                          : TranslationUtils.tr(
                              'pmam_manager_detail_screen_invest_now'),
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.isDarkMode
                            ? AppColors.pureBlack
                            : AppColors.onColoredBackground,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 2.h),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    '${TranslationUtils.tr('pmam_manager_detail_screen_min_investment')}: \$${minInv.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 9.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTopMetric(
                  TranslationUtils.tr('pmam_gain_caps'),
                  '${profit.toStringAsFixed(1)}%',
                  profit >= 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  TranslationUtils.tr('pmam_total_pnl_caps'),
                  _money(pnl),
                  pnl >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  TranslationUtils.tr('pmam_total_aum_caps'),
                  _money(aum),
                  AppColors.textPrimary,
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  TranslationUtils.tr('pmam_investors_caps'),
                  '$investors',
                  AppColors.textPrimary,
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  TranslationUtils.tr('pmam_commission_caps'),
                  '${commission.toStringAsFixed(2)}%',
                  AppColors.textPrimary,
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  TranslationUtils.tr('trader_details_screen_floating_profit'),
                  '\$0',
                  const Color(0xFF10B981),
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  TranslationUtils.tr('pmam_max_drawdown_caps'),
                  '-${drawdown.toStringAsFixed(2)}%',
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
          if (description.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DESCRIPTION',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGrey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopMetric(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(width: 1, height: 30.h, color: AppColors.border);
  }

  Widget _buildPerformanceChart() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TranslationUtils.tr('portfolio_performance'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['1W', '1M', '3M', '6M', '1Y', 'All'].map((e) {
                    final isSelected = e == '1M';
                    return Container(
                      margin: EdgeInsetsDirectional.only(start: 3.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 7.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.chipSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        e,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.isDarkMode
                                    ? AppColors.pureBlack
                                    : Colors.white
                              : AppColors.textGrey,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 180.h,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 100,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: AppColors.chipSurface, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return _bottomTitle(
                              TranslationUtils.tr('transaction_history_start'));
                        }
                        if (value == 3) return _bottomTitle('2026-04-10');
                        if (value == 6) return _bottomTitle('2026-04-13');
                        if (value == 9) return _bottomTitle('2026-04-16');
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 100,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value == 0 ? '\$0' : '\$${value.toInt()}',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.textGreyLight,
                            fontSize: 9.sp,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 10,
                minY: -100,
                maxY: 600,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      FlSpot(0, 0),
                      FlSpot(1, 150),
                      FlSpot(2, 300),
                      FlSpot(3, 450),
                      FlSpot(4, 550),
                      FlSpot(4.5, 480),
                      FlSpot(4.8, 500),
                      FlSpot(5, 100),
                      FlSpot(5.5, 120),
                      FlSpot(6, 40),
                      FlSpot(7, 40),
                      FlSpot(7.5, 200),
                      FlSpot(8, 200),
                      FlSpot(9, 80),
                      FlSpot(10, 80),
                    ],
                    isCurved: true,
                    color: AppColors.textPrimary,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: AppTextStyles.bodyText.copyWith(color: AppColors.textGreyLight, fontSize: 9.sp),
      ),
    );
  }

  Widget _buildOpenPositionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  TranslationUtils.tr('dashboard_open_positions'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    TranslationUtils.trArgs('pmam_count_live',
                        {'count': '${_openPositions.length}'}),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          if (_loadingOpen)
            Padding(
              padding: EdgeInsets.all(16.h),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_openPositions.isEmpty)
            Padding(
              padding: EdgeInsets.all(16.h),
              child: Center(
                child: Text(
                  TranslationUtils.tr(
                      'pmam_fund_manager_view_no_open_positions'),
                  style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey),
                ),
              ),
            )
          else ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: _colHeader(
                          TranslationUtils.tr('meta_watchlist_symbol'))),
                  Expanded(
                      flex: 2,
                      child: _colHeader(TranslationUtils.tr('common_type'))),
                  Expanded(
                      flex: 3,
                      child: _colHeader(
                          TranslationUtils.tr('scratch_card_screen_lot'))),
                  Expanded(
                      flex: 4,
                      child: _colHeader(
                          TranslationUtils.tr('trading_order_open_price'))),
                  Expanded(
                      flex: 4,
                      child: _colHeader(TranslationUtils.tr('open_time'))),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _showAllOpenPositions
                  ? _openPositions.length
                  : (_openPositions.length > 5 ? 5 : _openPositions.length),
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (context, index) {
                final p = _openPositions[index];
                final symbol = (p['symbol'] ?? '—').toString();
                final type = (p['type'] ?? 0).toString();
                final isBuy = type == '0' || type.toLowerCase() == 'buy';
                final lot = _num(p['lot_size']);
                final openPrice = (p['open_price'] ?? '—').toString();
                final openTime = (p['open_time'] ?? '—').toString();
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          symbol,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isBuy
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444))
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isBuy ? 'BUY' : 'SELL',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                              color: isBuy
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          TranslationUtils.trArgs('pmam_lot_suffix', {
                            'lots': lot.toStringAsFixed(2),
                          }),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          openPrice,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 10.sp,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          openTime.length > 10
                              ? openTime.substring(0, 10)
                              : openTime,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_openPositions.length > 5 && !_showAllOpenPositions) ...[
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              InkWell(
                onTap: () {
                  setState(() {
                    _showAllOpenPositions = true;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  alignment: Alignment.center,
                  child: Text(
                    TranslationUtils.tr('pmam_fund_manager_view_view_all'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTradeHistory() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  TranslationUtils.tr('my_clients_screen_trade_history'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.chipSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    TranslationUtils.trArgs(
                        'pmam_count_trades', {'count': '${_trades.length}'}),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child:
                        _colHeader(TranslationUtils.tr('meta_watchlist_symbol'))),
                Expanded(
                    flex: 2,
                    child: _colHeader(TranslationUtils.tr('common_type'))),
                Expanded(
                    flex: 2, child: _colHeader(TranslationUtils.tr('pmam_pnl'))),
                Expanded(
                    flex: 3,
                    child: _colHeader(TranslationUtils.tr(
                        'pmam_investor_portal_screen_close_time'))),
                Expanded(
                    flex: 2,
                    child: _colHeader(
                        TranslationUtils.tr('bonus_screen_duration'))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          if (_loadingTrades)
            Padding(
              padding: EdgeInsets.all(16.h),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_trades.isEmpty)
            Padding(
              padding: EdgeInsets.all(16.h),
              child: Center(
                  child: Text(TranslationUtils.tr(
                      'pmam_fund_manager_view_no_trades_available'))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _showAllTrades
                  ? _trades.length
                  : (_trades.length > 5 ? 5 : _trades.length),
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (context, index) {
                final t = _trades[index];
                return _buildTradeRow(t);
              },
            ),
          if (_trades.length > 5 && !_showAllTrades) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            InkWell(
              onTap: () {
                setState(() {
                  _showAllTrades = true;
                });
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                alignment: Alignment.center,
                child: Text(
                  TranslationUtils.tr('pmam_fund_manager_view_view_all'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _colHeader(String text) {
    return Text(
      text,
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 9.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textGrey,
      ),
    );
  }

  Widget _buildTradeRow(Map<String, dynamic> t) {
    final symbol = (t['symbol'] ?? '—').toString();
    final typeStr = (t['type'] ?? '').toString();
    final profit = _num(t['profit']);
    final closeTime = (t['close_time'] ?? '').toString();

    // Attempting to calculate duration if open_time and close_time exist
    String duration = '0m';
    final openTimeStr = (t['open_time'] ?? '').toString();
    if (openTimeStr.isNotEmpty && closeTime.isNotEmpty) {
      try {
        final o = DateTime.parse(openTimeStr);
        final c = DateTime.parse(closeTime);
        final diff = c.difference(o);
        if (diff.inDays > 0) {
          duration = '${diff.inDays}d ${diff.inHours % 24}h';
        } else if (diff.inHours > 0) {
          duration = '${diff.inHours}h ${diff.inMinutes % 60}m';
        } else {
          duration = '${diff.inMinutes}m';
        }
      } catch (_) {}
    }

    final isBuy = typeStr.toLowerCase() == 'buy' || typeStr == '0';
    final isProfit = profit >= 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              symbol,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color:
                        (isBuy
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444))
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isBuy ? 'BUY' : 'SELL',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: isBuy
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isProfit
                  ? '+\$${profit.toStringAsFixed(2)}'
                  : '-\$${profit.abs().toStringAsFixed(2)}',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isProfit
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              closeTime.isNotEmpty ? closeTime : '-',
              style: AppTextStyles.bodyText.copyWith(fontSize: 10.sp, color: AppColors.textGrey),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              duration,
              style: AppTextStyles.bodyText.copyWith(fontSize: 10.sp, color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanErrorBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16.sp, color: AppColors.error),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              _planError,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                color: AppColors.error,
              ),
            ),
          ),
          TextButton(
            onPressed: _selectedPlan == null
                ? null
                : () => _loadPlanData(_selectedPlan!),
            child: Text(
              TranslationUtils.tr('common_retry'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 48.sp,
              color: AppColors.textGreyLight,
            ),
            SizedBox(height: 12.h),
            Text(
                  TranslationUtils.tr(
                      'pmam_fund_manager_view_manager_not_found'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              _managerCode.isEmpty
                      ? TranslationUtils.tr('pmam_no_manager_id_provided')
                      : _profileError.isNotEmpty
                          ? _profileError
                          : TranslationUtils.trArgs('pmam_unable_to_load_profile',
                              {'code': _managerCode}),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey),
            ),
            if (_managerCode.isNotEmpty) ...[
              SizedBox(height: 12.h),
              OutlinedButton.icon(
                onPressed: _loadProfile,
                icon: Icon(Icons.refresh, size: 16.sp, color: AppColors.primary),
                label: Text(
                  TranslationUtils.tr('common_retry'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
