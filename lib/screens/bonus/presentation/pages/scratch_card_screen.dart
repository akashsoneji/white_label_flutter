import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/loading_service.dart';
import 'package:crm_app/widgets/rtl_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:scratcher/scratcher.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/bonus/domain/repositories/bonus_repository.dart';
import 'package:crm_app/widgets/mobile_verification_sheet.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/services/language_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class ScratchCardApiModel {
  final int id;
  final String status; // 'active' | 'scratched' | 'expired'
  final num? rewardAmount;
  final String refreshWindow;
  final String expiresAt;
  final String? createdAt;
  final String? scratchedAt;

  ScratchCardApiModel({
    required this.id,
    required this.status,
    this.rewardAmount,
    required this.refreshWindow,
    required this.expiresAt,
    this.createdAt,
    this.scratchedAt,
  });

  factory ScratchCardApiModel.fromJson(Map<String, dynamic> json) {
    final rawReward = json['reward_amount'];

    // Safely parse ID
    int parsedId = 0;
    if (json['id'] != null) {
      if (json['id'] is int)
        parsedId = json['id'];
      else if (json['id'] is String)
        parsedId = int.tryParse(json['id']) ?? 0;
    }

    return ScratchCardApiModel(
      id: parsedId,
      status: json['status']?.toString() ?? 'active',
      rewardAmount:
          (rawReward is num)
              ? rawReward.toDouble()
              : (rawReward is String && rawReward.isNotEmpty)
              ? double.tryParse(rawReward)
              : null,
      refreshWindow: json['refresh_window']?.toString() ?? '',
      expiresAt: json['expires_at']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      scratchedAt: json['scratched_at']?.toString(),
    );
  }

  bool get isScratched => status.toLowerCase() == 'scratched';
  bool get isActive =>
      status.toLowerCase() != 'scratched' && status.toLowerCase() != 'expired';

  DateTime? get _groupingDateTime {
    // Try all 3 timestamps — whichever parses wins.
    // Note: empty-string fallback matters because "?? createdAt ?? expiresAt"
    // was being applied to non-null empty strings, which then crashed DateTime.parse.
    final candidates = <String?>[
      if (isScratched) scratchedAt,
      createdAt,
      expiresAt,
    ];
    for (final raw in candidates) {
      if (raw == null) continue;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      // Try ISO-8601 first (e.g. "2026-07-16T08:00:00Z").
      DateTime? dt = DateTime.tryParse(trimmed);
      // Fallback: space-separated (e.g. "2026-07-16 08:00:00") — treat as UTC.
      dt ??= _tryParseSpaceSeparated(trimmed);
      if (dt != null) return dt.toLocal();
    }
    return null;
  }

  static DateTime? _tryParseSpaceSeparated(String s) {
    // "2026-07-16 08:00:00" or "2026-07-16 08:00:00.000"
    final re = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?$',
    );
    final m = re.firstMatch(s);
    if (m == null) return null;
    try {
      final year = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final day = int.parse(m.group(3)!);
      final hour = int.parse(m.group(4)!);
      final min = int.parse(m.group(5)!);
      final sec = int.parse(m.group(6)!);
      // Treat naive timestamps as UTC; UI then converts to local via .toLocal().
      return DateTime.utc(year, month, day, hour, min, sec);
    } catch (_) {
      return null;
    }
  }

  /// Human-readable expires_at label, e.g. "20 Mar 08:00"
  String get expiresLabel {
    try {
      final dt = DateTime.parse(scratchedAt!).toLocal();
      final months = [
        TranslationUtils.tr('month_short_jan'),
        TranslationUtils.tr('month_short_feb'),
        TranslationUtils.tr('month_short_mar'),
        TranslationUtils.tr('month_short_apr'),
        TranslationUtils.tr('month_short_may'),
        TranslationUtils.tr('month_short_jun'),
        TranslationUtils.tr('month_short_jul'),
        TranslationUtils.tr('month_short_aug'),
        TranslationUtils.tr('month_short_sep'),
        TranslationUtils.tr('month_short_oct'),
        TranslationUtils.tr('month_short_nov'),
        TranslationUtils.tr('month_short_dec'),
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} $h:$m';
    } catch (_) {
      return expiresAt;
    }
  }
}

class ScratchCardLotsStepModel {
  final int step;
  final int thresholdPercent;
  final double targetLots;
  final bool achieved;
  final String status;

  ScratchCardLotsStepModel({
    required this.step,
    required this.thresholdPercent,
    required this.targetLots,
    required this.achieved,
    required this.status,
  });

  factory ScratchCardLotsStepModel.fromJson(Map<String, dynamic> json) {
    final targetLotsRaw = json['target_lots'];
    return ScratchCardLotsStepModel(
      step: (json['step'] as num?)?.toInt() ?? 0,
      thresholdPercent: (json['threshold_percent'] as num?)?.toInt() ?? 0,
      targetLots:
          (targetLotsRaw is num)
              ? targetLotsRaw.toDouble()
              : double.tryParse(targetLotsRaw?.toString() ?? '') ?? 0.0,
      achieved: json['achieved'] == true,
      status: json['status']?.toString() ?? 'locked',
    );
  }
}

class ScratchCardSummaryModel {
  final double earnedAllTime;
  final double earnedIn30Days;
  final int maxLimit30Days;
  final String? nextCardAvailableAt;
  final double scratchPendingRewardTotal;
  final bool scratchCompletedOnce;
  final String? scratchAccountNumber;
  final bool hasScratchAccount;
  final double requiredLots;
  final double lotsAccumulated;
  final double lotsRemaining;
  final int lotsProgressPercent;
  final int activeStep;
  final String activeStepStatus;
  final List<ScratchCardLotsStepModel> steps;
  final bool canConvertPendingToBalance;
  final String convertPendingHint;
  final bool canClaim;
  final String claimStatus;
  final double claimAmount;
  final String claimHint;

  ScratchCardSummaryModel({
    required this.earnedAllTime,
    required this.earnedIn30Days,
    required this.maxLimit30Days,
    this.nextCardAvailableAt,
    required this.scratchPendingRewardTotal,
    required this.scratchCompletedOnce,
    this.scratchAccountNumber,
    required this.hasScratchAccount,
    required this.requiredLots,
    required this.lotsAccumulated,
    required this.lotsRemaining,
    required this.lotsProgressPercent,
    required this.activeStep,
    required this.activeStepStatus,
    required this.steps,
    required this.canConvertPendingToBalance,
    required this.convertPendingHint,
    this.canClaim = false,
    this.claimStatus = '',
    this.claimAmount = 0,
    this.claimHint = '',
  });

  factory ScratchCardSummaryModel.fromJson(Map<String, dynamic> json) {
    final earnedAllTimeRaw = json['earned_all_time'];
    final earned = json['earned_in_30_days'];
    final maxLimit = json['max_limit_30_days'];
    final scratchPendingRaw = json['scratch_pending_reward_total'];
    final requiredLotsRaw = json['required_lots'] ?? json['requiredLots'];
    final lotsAccumulatedRaw =
        json['lots_accumulated'] ?? json['lotsAccumulated'];
    final lotsRemainingRaw = json['lots_remaining'] ?? json['lotsRemaining'];
    final lotsProgressPercentRaw =
        json['lots_progress_percent'] ?? json['lotsProgressPercent'];
    final activeStepRaw = json['active_step'];
    final rawSteps = json['steps'] ?? json['lots'];

    final List<ScratchCardLotsStepModel> parsedSteps;
    if (rawSteps is List) {
      parsedSteps =
          rawSteps
              .whereType<Map>()
              .map(
                (e) => ScratchCardLotsStepModel.fromJson(
                  e.cast<String, dynamic>(),
                ),
              )
              .toList();
    } else if (rawSteps is Map) {
      parsedSteps =
          rawSteps.values
              .whereType<Map>()
              .map(
                (e) => ScratchCardLotsStepModel.fromJson(
                  e.cast<String, dynamic>(),
                ),
              )
              .toList();
    } else {
      parsedSteps = [];
    }

    return ScratchCardSummaryModel(
      earnedAllTime:
          (earnedAllTimeRaw is num)
              ? earnedAllTimeRaw.toDouble()
              : double.tryParse(earnedAllTimeRaw?.toString() ?? '') ?? 0.0,
      earnedIn30Days:
          (earned is num)
              ? earned.toDouble()
              : double.tryParse(earned?.toString() ?? '') ?? 0.0,
      maxLimit30Days:
          (maxLimit is num)
              ? maxLimit.toInt()
              : int.tryParse(maxLimit?.toString() ?? '') ?? 0,
      nextCardAvailableAt: json['next_card_available_at']?.toString(),
      scratchPendingRewardTotal:
          (scratchPendingRaw is num)
              ? scratchPendingRaw.toDouble()
              : double.tryParse(scratchPendingRaw?.toString() ?? '') ?? 0.0,
      scratchCompletedOnce: json['scratch_completed_once'] == true,
      scratchAccountNumber: json['scratch_account_number']?.toString(),
      hasScratchAccount: json['has_scratch_account'] == true,
      requiredLots:
          (requiredLotsRaw is num)
              ? requiredLotsRaw.toDouble()
              : double.tryParse(requiredLotsRaw?.toString() ?? '') ?? 0.0,
      lotsAccumulated:
          (lotsAccumulatedRaw is num)
              ? lotsAccumulatedRaw.toDouble()
              : double.tryParse(lotsAccumulatedRaw?.toString() ?? '') ?? 0.0,
      lotsRemaining:
          (lotsRemainingRaw is num)
              ? lotsRemainingRaw.toDouble()
              : double.tryParse(lotsRemainingRaw?.toString() ?? '') ?? 0.0,
      lotsProgressPercent:
          (lotsProgressPercentRaw is num)
              ? lotsProgressPercentRaw.toInt()
              : int.tryParse(lotsProgressPercentRaw?.toString() ?? '') ?? 0,
      activeStep:
          (activeStepRaw is num)
              ? activeStepRaw.toInt()
              : int.tryParse(activeStepRaw?.toString() ?? '') ?? 0,
      activeStepStatus: json['active_step_status']?.toString() ?? '',
      steps: parsedSteps,
      canConvertPendingToBalance:
          json['can_convert_pending_to_balance'] == true,
      convertPendingHint: json['convert_pending_hint']?.toString() ?? '',
      canClaim: json['can_claim'] == true,
      claimStatus: json['claim_status']?.toString() ?? '',
      claimAmount: double.tryParse('${json['claim_amount'] ?? ''}') ?? 0.0,
      claimHint: json['claim_hint']?.toString() ?? '',
    );
  }

  List<ScratchCardLotsStepModel> get lots => steps;

  /// Parsed next card available time, or null if not set / in the past
  DateTime? get nextCardDateTime {
    if (nextCardAvailableAt == null || nextCardAvailableAt!.isEmpty)
      return null;
    try {
      return DateTime.parse(nextCardAvailableAt!).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// True when a new card countdown is active (not null and in the future)
  bool get hasUpcomingCard {
    final dt = nextCardDateTime;
    if (dt == null) return false;
    return dt.isAfter(DateTime.now());
  }

  /// Human-readable label, e.g. "Next card: 21 Mar 20:00"
  String get nextCardLabel {
    final dt = nextCardDateTime;
    if (dt == null) return '';
    final months = [
      TranslationUtils.tr('month_short_jan'),
      TranslationUtils.tr('month_short_feb'),
      TranslationUtils.tr('month_short_mar'),
      TranslationUtils.tr('month_short_apr'),
      TranslationUtils.tr('month_short_may'),
      TranslationUtils.tr('month_short_jun'),
      TranslationUtils.tr('month_short_jul'),
      TranslationUtils.tr('month_short_aug'),
      TranslationUtils.tr('month_short_sep'),
      TranslationUtils.tr('month_short_oct'),
      TranslationUtils.tr('month_short_nov'),
      TranslationUtils.tr('month_short_dec'),
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} $h:$m';
  }
}

class ScratchCardRevealModel {
  final int cardId;
  final String status;
  final double rewardAmount;
  final String scratchedAt;
  final String creditStatus; // 'none' | 'pending' | 'credited' | 'failed'
  final String creditError;

  ScratchCardRevealModel({
    required this.cardId,
    required this.status,
    required this.rewardAmount,
    required this.scratchedAt,
    required this.creditStatus,
    required this.creditError,
  });

  factory ScratchCardRevealModel.fromJson(Map<String, dynamic> json) {
    final reward = json['reward_amount'];
    return ScratchCardRevealModel(
      cardId: (json['card_id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'scratched',
      rewardAmount:
          (reward is num)
              ? reward.toDouble()
              : double.tryParse(reward?.toString() ?? '') ?? 0.0,
      scratchedAt: json['scratched_at']?.toString() ?? '',
      creditStatus: json['credit_status']?.toString() ?? 'none',
      creditError: json['credit_error']?.toString() ?? '',
    );
  }

  bool get isWin => rewardAmount > 0;
  bool get isCreditFailed => creditStatus == 'failed';
}

class ScratchLeaderboardWindowModel {
  final String windowKey;
  final String rangeLabel;
  final int batchIndex;

  ScratchLeaderboardWindowModel({
    required this.windowKey,
    required this.rangeLabel,
    required this.batchIndex,
  });

  factory ScratchLeaderboardWindowModel.fromJson(Map<String, dynamic> json) {
    return ScratchLeaderboardWindowModel(
      windowKey: json['window_key']?.toString() ?? '',
      rangeLabel: json['range_label']?.toString() ?? '',
      batchIndex: (json['batch_index'] as num?)?.toInt() ?? 0,
    );
  }
}

class ScratchLeaderboardEntryModel {
  final int position;
  final String displayName;
  final String avatarLetter;
  final double amount;

  ScratchLeaderboardEntryModel({
    required this.position,
    required this.displayName,
    required this.avatarLetter,
    required this.amount,
  });

  factory ScratchLeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    final amt = json['amount'];
    return ScratchLeaderboardEntryModel(
      position: (json['position'] as num?)?.toInt() ?? 0,
      displayName: json['display_name']?.toString() ?? '',
      avatarLetter: json['avatar_letter']?.toString() ?? '',
      amount:
          (amt is num)
              ? amt.toDouble()
              : double.tryParse(amt?.toString() ?? '') ?? 0.0,
    );
  }

  String get rankLabel {
    if (position == 1) return '🥇';
    if (position == 2) return '🥈';
    if (position == 3) return '🥉';
    return position.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCRATCH CARD CONTROLLER  (list-level)
// ─────────────────────────────────────────────────────────────────────────────

class ScratchCardController extends GetxController {
  final BonusRepository _bonusRepo = Get.find<BonusRepository>();
  final FinanceRepository _financeRepo = Get.find<FinanceRepository>();
  // ── State ──
  final RxList<ScratchCardApiModel> cards = <ScratchCardApiModel>[].obs;
  final Rxn<ScratchCardSummaryModel> summary = Rxn<ScratchCardSummaryModel>();
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isRevealing = false.obs;
  final RxBool isConverting = false.obs;
  final RxBool isClaiming = false.obs;
  final RxBool isCreatingAccount = false.obs;
  final RxBool isLeaderboardLoading = false.obs;
  final Rxn<ScratchLeaderboardWindowModel> leaderboardWindow =
      Rxn<ScratchLeaderboardWindowModel>();
  final RxList<ScratchLeaderboardEntryModel> leaderboard =
      <ScratchLeaderboardEntryModel>[].obs;

  /// Stored from 409 response so we can pass to create-account call
  int? _pendingScratchGroupId;

  /// The card_id we tried to reveal when we got 409 (to retry after account creation)
  int? _pendingRevealCardId;

  // ── Lifecycle ──
  @override
  void onInit() {
    super.onInit();
    fetchCards();
    fetchLeaderboard();
  }

  Future<void> fetchLeaderboard({bool showLoader = false}) async {
    try {
      if (showLoader && leaderboard.isEmpty) {
        isLeaderboardLoading.value = true;
      }
      final response = await _bonusRepo.getScratchLeaderboard();

      if (response.success) {
        final data = response.data?['data'];
        if (data is Map<String, dynamic>) {
          if (data['window'] is Map<String, dynamic>) {
            leaderboardWindow.value = ScratchLeaderboardWindowModel.fromJson(
              data['window'] as Map<String, dynamic>,
            );
          }
          final rows = data['leaderboard'];
          if (rows is List) {
            leaderboard.assignAll(
              rows
                  .whereType<Map>()
                  .map(
                    (e) => ScratchLeaderboardEntryModel.fromJson(
                      e.cast<String, dynamic>(),
                    ),
                  )
                  .toList(),
            );
          } else {
            leaderboard.clear();
          }
        }
      }
    } catch (_) {
      // leaderboard is marketing-only; keep UI quiet
    } finally {
      isLeaderboardLoading.value = false;
    }
  }

  /// `POST v1/user/scratch-cards/claim` — sends the reward for admin approval;
  /// the refreshed summary then carries `claim_status: pending`.
  Future<void> claimReward() async {
    if (isClaiming.value) return;
    try {
      isClaiming.value = true;
      // The web portal verifies the mobile number before a reward claim.
      if (!await ensureMobileVerified()) return;
      final response = await _bonusRepo.claimScratchReward();
      if (response.success) {
        CustomToastService.showSuccess(
          title: TranslationUtils.tr('general_success'),
          message: (response.message?.isNotEmpty == true)
              ? response.message!
              : TranslationUtils.tr('scratch_claim_sent'),
        );
        await fetchCards(showLoader: false);
      } else {
        CustomToastService.showError(
          title: TranslationUtils.tr('general_error'),
          message: (response.message?.isNotEmpty == true)
              ? response.message!
              : TranslationUtils.tr('scratch_claim_failed'),
        );
      }
    } catch (_) {
      CustomToastService.showError(
        title: TranslationUtils.tr('general_error'),
        message: TranslationUtils.tr('error_network'),
      );
    } finally {
      isClaiming.value = false;
    }
  }

  Future<void> convertCreditToBalance({required int accountId}) async {
    try {
      isConverting.value = true;
      final response = await _bonusRepo.convertScratchCreditToBalance(
        accountId: accountId,
      );

      if (response.success) {
        CustomToastService.showSuccess(
          title: TranslationUtils.tr('general_success'),
          message:
              (response.message?.isNotEmpty == true)
                  ? response.message!
                  : TranslationUtils.tr('scratch_card_screen_credit_converted'),
        );
        await fetchCards(showLoader: false);
        if (Get.isRegistered<AccountController>()) {
          await Get.find<AccountController>().forceRefreshMT5Accounts();
        }
      } else {
        CustomToastService.showError(
          title: TranslationUtils.tr('general_error'),
          message:
              (response.message?.isNotEmpty == true)
                  ? response.message!
                  : TranslationUtils.tr('scratch_card_screen_failed_convert_credit'),
        );
      }
    } catch (_) {
      CustomToastService.showError(
        title: TranslationUtils.tr('general_error'),
        message: TranslationUtils.tr('error_network'),
      );
    } finally {
      isConverting.value = false;
    }
  }

  // ───────────────────────────────────────────────────��─────────────────────
  // 1) Fetch cards
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchCards({bool showLoader = true}) async {
    try {
      final shouldShowFullLoader = showLoader && cards.isEmpty;
      if (shouldShowFullLoader) {
        isLoading.value = true;
      } else {
        isRefreshing.value = true;
      }
      final response = await _bonusRepo.getScratchCards();

      if (response.success) {
        final rootData = response.data;
        // response.data is ApiResponse.data — could be:
        //   - the raw envelope {data: {...}}  (most common)
        //   - or already unwrapped {summary, cards, ...}
        final Map<String, dynamic>? envelope =
            (rootData is Map<String, dynamic>) ? rootData : null;
        final Map<String, dynamic>? payload =
            envelope != null && envelope['data'] is Map<String, dynamic>
                ? envelope['data'] as Map<String, dynamic>
                : envelope;

        if (payload == null) {
          // Success but unparseable — wipe stale state so UI doesn't lie.
          cards.clear();
          summary.value = null;
          return;
        }

        // ── Summary (always overwrite, even with null payload value) ──
        final rawSummary = payload['summary'];
        if (rawSummary is Map<String, dynamic>) {
          summary.value = ScratchCardSummaryModel.fromJson(rawSummary);
        } else {
          summary.value = null;
        }

        // ── Cards (always overwrite — never keep stale list) ──
        final rawCards = payload['cards'];
        if (rawCards is List) {
          cards.assignAll(
            rawCards
                .whereType<Map>()
                .map(
                  (e) =>
                      ScratchCardApiModel.fromJson(e.cast<String, dynamic>()),
                )
                .toList(),
          );
        } else {
          // Backend sent success but no cards field → clear stale data.
          cards.clear();
        }
      } else {
        // Server-level error — don't wipe local state on transient errors
        // (e.g. timeout) so user keeps seeing last known cards.
        // But DO surface a toast.
        if (cards.isEmpty) {
          // First-load failure → also wipe so empty-state renders correctly.
          summary.value = null;
        }
        CustomToastService.showError(
          title: TranslationUtils.tr('general_error'),
          message:
              (response.message?.isNotEmpty == true)
                  ? response.message!
                  : TranslationUtils.tr('scratch_card_screen_failed_load_cards'),
        );
      }
    } catch (e, t) {
      debugPrint('[ScratchCard] fetchCards exception: $e');
      debugPrint(t.toString());
      // Same logic as failure: keep stale on transient, clear on first-load.
      if (cards.isEmpty) {
        summary.value = null;
      }
      CustomToastService.showError(
        title: TranslationUtils.tr('general_error'),
        message: TranslationUtils.tr('error_network'),
      );
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2) Reveal card
  // ─────────────────────────────────────────────────────────────────────────
  String _generateRandomPassword({int length = 12}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  Future<ScratchCardRevealModel?> revealCard(int cardId) async {
    try {
      isRevealing.value = true;
      final response = await _bonusRepo.revealScratchCard(cardId: cardId);

      if (response.success) {
        final data = response.data?['data'];
        if (data != null && data is Map<String, dynamic>) {
          final reveal = ScratchCardRevealModel.fromJson(data);
          // Update card status locally to avoid re-fetching immediately
          _updateLocalCardStatus(cardId, reveal.rewardAmount);
          return reveal;
        }
      } else {
        // Check for 409 SCRATCH_ACCOUNT_REQUIRED
        final errData = response.data;
        if (errData is Map<String, dynamic> &&
            errData['code'] == 'SCRATCH_ACCOUNT_REQUIRED') {
          _pendingRevealCardId = cardId;

          final rawGroupId = errData['scratch_group_id'];
          if (rawGroupId is num) {
            _pendingScratchGroupId = rawGroupId.toInt();
          } else if (rawGroupId is String && rawGroupId.isNotEmpty) {
            _pendingScratchGroupId = int.tryParse(rawGroupId);
          } else {
            _pendingScratchGroupId = null;
          }

          // Spec: no password popup.
          // Auto-generate passwords, create account, then retry reveal.
          if (_pendingScratchGroupId == null) {
            CustomToastService.showError(
              title: TranslationUtils.tr('general_error'),
              message:
                  (response.message?.isNotEmpty == true)
                      ? response.message!
                      : TranslationUtils.tr('scratch_card_screen_group_not_configured'),
            );
            return null;
          }

          Get.dialog(
            const Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                width: 80,
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            barrierDismissible: false,
          );

          final mainPassword = _generateRandomPassword();
          var investorPassword = _generateRandomPassword();
          while (investorPassword == mainPassword) {
            investorPassword = _generateRandomPassword();
          }

          // createScratchAccount() will retry reveal and show result dialogs.
          await createScratchAccount(
            mainPassword: mainPassword,
            investorPassword: investorPassword,
          );

          return null; // caller should not show win/lose — handled via retry
        } else {
          CustomToastService.showError(
            title: TranslationUtils.tr('general_error'),
            message:
                (response.message?.isNotEmpty == true)
                    ? response.message!
                    : TranslationUtils.tr('scratch_card_screen_failed_reveal_card'),
          );
        }
      }
    } catch (e, t) {
      debugPrint('ScratchCardScreen revealCard exception: $e');
      debugPrint('Stacktrace: $t');
      CustomToastService.showError(
        title: TranslationUtils.tr('general_error_prefix'),
        message: 'Error: $e',
      );
    } finally {
      isRevealing.value = false;
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3) Create scratch trading account (called from dialog)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> createScratchAccount({
    required String mainPassword,
    required String investorPassword,
  }) async {
    if (_pendingScratchGroupId == null) {
      CustomToastService.showError(
        title: TranslationUtils.tr('general_error'),
        message: TranslationUtils.tr(
          'scratch_card_screen_scratch_group_not_found_please_try',
        ),
      );
      return;
    }

    try {
      isCreatingAccount.value = true;

      final response = await _financeRepo.createMt5Account(
        data: {
          'group_id': _pendingScratchGroupId,
          'main_password': mainPassword,
          'investor_password': investorPassword,
        },
      );

      if (response.success) {
        // Close the loading dialog
        if (Get.isDialogOpen ?? false) Get.back();

        // Auto-retry reveal
        if (_pendingRevealCardId != null) {
          final cardId = _pendingRevealCardId!;
          _pendingRevealCardId = null;
          final reveal = await revealCard(cardId);
          if (reveal != null) {
            _showRevealResultDialog(
              reveal,
              onDone: () {
                if (Get.isDialogOpen ?? false) Get.back();
                fetchCards();
              },
            );
          }
        }
      } else {
        // Close the loading dialog on failure too
        if (Get.isDialogOpen ?? false) Get.back();
        CustomToastService.showError(
          title: TranslationUtils.tr('general_error'),
          message:
              (response.message?.isNotEmpty == true)
                  ? response.message!
                  : TranslationUtils.tr('scratch_card_screen_failed_create_account'),
        );
      }
    } catch (e, t) {
      debugPrint('ScratchCardScreen createScratchAccount exception: $e');
      debugPrint('Stacktrace: $t');
      CustomToastService.showError(
        title: TranslationUtils.tr('general_error_prefix'),
        message: 'Error: $e',
      );
    } finally {
      isCreatingAccount.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _updateLocalCardStatus(int cardId, double rewardAmount) {
    final idx = cards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      final old = cards[idx];
      cards[idx] = ScratchCardApiModel(
        id: old.id,
        status: 'scratched',
        rewardAmount: rewardAmount,
        refreshWindow: old.refreshWindow,
        expiresAt: old.expiresAt,
        createdAt: old.createdAt,
        scratchedAt: DateTime.now().toIso8601String(),
      );
      cards.refresh();
    }
  }

  void _showRevealResultDialog(
    ScratchCardRevealModel reveal, {
    VoidCallback? onDone,
  }) {
    final VoidCallback defaultDone = () {
      if (Get.isDialogOpen ?? false) Get.back();
      // If we are on detail screen, we might need to go back another level
      // but usually the caller provides onDone if they want specific navigation.
      fetchCards();
    };

    // If a scratch dialog is already open, close it before showing result dialog.
    // This prevents stacked dialogs (user sees only the latest).
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    Future.microtask(() {
      Get.dialog(
        reveal.isWin
            ? _WinResultDialog(reveal: reveal, onDone: onDone ?? defaultDone)
            : _LoseResultDialog(onDone: onDone ?? defaultDone),
        barrierDismissible: false,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PER-CARD SCRATCH GESTURE CONTROLLER
// ─────────────────────────────────────────────────────────────────────────────

class _ScratchGestureController extends GetxController {
  final ScratchCardApiModel card;
  _ScratchGestureController(this.card);

  // 25% → trigger reveal
  static const double checkThreshold = 25.0;

  RxDouble progress = 0.0.obs;
  RxBool hasTriggeredReveal = false.obs;
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  final scratchKey = GlobalKey<ScratcherState>();

  @override
  void onInit() {
    super.onInit();
    if (card.isScratched) {
      hasTriggeredReveal.value = true;
      progressNotifier.value = 1.0;
    }
  }

  void onProgress(double value) {
    progress.value = value;
    progressNotifier.value = value / 100.0;
  }

  void onScratchEnd() {
    if (!hasTriggeredReveal.value && progress.value >= checkThreshold) {
      _doReveal();
    }
  }

  void _doReveal() {
    if (!hasTriggeredReveal.value) {
      hasTriggeredReveal.value = true;
      progressNotifier.value = 1.0;
      scratchKey.currentState?.reveal(
        duration: const Duration(milliseconds: 350),
      );
    }
  }

  @override
  void onClose() {
    progressNotifier.dispose();
    super.onClose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCRATCH CARD LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ScratchCardListScreen extends StatelessWidget {
  const ScratchCardListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ScratchCardController());

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          Get.isRegistered<LanguageService>()
              ? Get.find<LanguageService>().tr('general_scratch_card')
              : 'Scratch Card',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () => controller.fetchCards(showLoader: false),
            tooltip: TranslationUtils.tr('general_refresh'),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await controller.fetchCards(showLoader: false);
            await controller.fetchLeaderboard(showLoader: false);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                if (controller.isRefreshing.value)
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                    backgroundColor: Colors.black.withOpacity(0.06),
                  ),

                // ── Summary Banner ──
                _SummaryBanner(controller: controller),

                // ── Next Card Countdown Banner ──
                // _NextCardCountdownBanner(controller: controller),
                if (controller.cards.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 24.h),
                    child: _EmptyState(),
                  )
                else ...[
                  _ScratchCardsGrid(controller: controller),
                  SizedBox(height: 10.h),
                  _ScratchHistoryList(controller: controller),
                  SizedBox(height: 14.h),
                  _ScratchLeaderboardSection(controller: controller),
                  SizedBox(height: 24.h),
                ],

                _ScratchLotsProgressSection(controller: controller),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _ScratchCardsGrid extends StatefulWidget {
  final ScratchCardController controller;
  const _ScratchCardsGrid({required this.controller});

  @override
  State<_ScratchCardsGrid> createState() => _ScratchCardsGridState();
}

class _ScratchCardsGridState extends State<_ScratchCardsGrid> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasLocked =
          widget.controller.summary.value?.hasUpcomingCard == true;
      final scratchCards =
          widget.controller.cards.where((c) => c.isActive).toList();
      final totalCards = scratchCards.length;
      final visibleCards = _showAll ? totalCards : min(4, totalCards);

      // locked card should appear first
      final itemCount = (hasLocked ? 1 : 0) + visibleCards;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            child: Row(
              children: [
                Text(
                  TranslationUtils.tr('scratch_card_screen_scratch_cards'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                if (totalCards > 4)
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(_showAll
                        ? TranslationUtils.tr('scratch_card_screen_show_less')
                        : TranslationUtils.tr('tw_view_all')),
                  ),
              ],
            ),
          ),
          // Debug info to help identify data issues in release
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 1,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (hasLocked && index == 0) {
                  final s = widget.controller.summary.value;
                  if (s == null) return const SizedBox.shrink();
                  return _LockedScratchCardGridItem(summary: s);
                }

                final cardIndex = index - (hasLocked ? 1 : 0);
                if (cardIndex < 0 || cardIndex >= visibleCards) {
                  return const SizedBox.shrink();
                }

                final card = scratchCards[cardIndex];
                return _ScratchCardGridItem(
                  card: card,
                  onTap: () async {
                    if (card.isScratched) return;
                    await Get.dialog(
                      _ScratchCardDialog(card: card),
                      barrierDismissible: false,
                    );
                    await widget.controller.fetchCards(showLoader: false);
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEADERBOARD (API)
// ─────────────────────────────────────────────────────────────────────────────

class _ScratchLeaderboardSection extends StatelessWidget {
  final ScratchCardController controller;
  const _ScratchLeaderboardSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.leaderboard;
      final week = controller.leaderboardWindow.value?.rangeLabel ?? '';

      if (controller.isLeaderboardLoading.value && rows.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    TranslationUtils.tr('scratch_card_screen_scratch_leaderboard'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 18.r,
                  height: 18.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (rows.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              TranslationUtils.tr('scratch_card_screen_top_earners_this_week'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          TranslationUtils.tr('scratch_card_screen_scratch_leaderboard'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (week.isNotEmpty)
                        Text(
                          week,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  ...rows.map((r) {
                    final letter =
                        r.avatarLetter.isNotEmpty
                            ? r.avatarLetter
                            : (r.displayName.isNotEmpty
                                ? r.displayName[0]
                                : 'U');

                    return Container(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26.w,
                            child: Text(
                              r.rankLabel,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 14.sp,
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Container(
                            width: 30.w,
                            height: 30.w,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                letter,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              r.displayName,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 13.sp,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Text(
                            '\$${r.amount.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13.sp,
                              color: AppColors.prizeGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ScratchLotsProgressSection extends StatelessWidget {
  final ScratchCardController controller;
  const _ScratchLotsProgressSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final summary = controller.summary.value;
      // Show the section whenever summary is available.
      // Steps table is optional and may be omitted by backend for some users.
      if (summary == null) {
        return const SizedBox.shrink();
      }

      final targetLots = summary.requiredLots;
      final doneLots = summary.lotsAccumulated;
      final computedPct = targetLots <= 0 ? 0.0 : (doneLots / targetLots);
      final apiPct = summary.lotsProgressPercent / 100.0;
      // API value of 0 is valid (0%). We only fallback if API percent is missing (null).
      final pct = (summary.lotsProgressPercent >= 0) ? apiPct : computedPct;
      final safePct = pct.clamp(0.0, 1.0).toDouble();
      final tiers = summary.steps.take(5).toList();
      final fullUnlockAmount = summary.maxLimit30Days.toDouble();
      final canEnableByRules =
          doneLots >= targetLots &&
          summary.scratchPendingRewardTotal > 0 &&
          summary.hasScratchAccount;
      final firstStep = tiers.isNotEmpty ? tiers.first : null;

      double fallbackAmount(ScratchCardLotsStepModel step) {
        if (targetLots <= 0) return 0.0;
        // Updated API response does not include per-step amount.
        // We scale max_limit_30_days proportionally to target_lots / required_lots.
        return (fullUnlockAmount * step.targetLots) / targetLots;
      }

      String statusLabel(String status) {
        if (status == 'completed') {
          return TranslationUtils.tr('scratch_card_screen_status_completed');
        }
        if (status == 'in_progress') {
          return TranslationUtils.tr('scratch_card_screen_status_active');
        }
        return TranslationUtils.tr('scratch_card_screen_status_inactive');
      }

      Color statusTextColor(String status) {
        if (status == 'completed') return AppColors.success;
        if (status == 'in_progress') return AppColors.primary;
        return AppColors.textGrey;
      }

      Color statusBgColor(String status) {
        if (status == 'completed')
          return AppColors.success.withValues(alpha: 0.12);
        if (status == 'in_progress') return AppColors.primary.withOpacity(0.08);
        return AppColors.surface;
      }

      Border? statusBorder(String status) {
        if (status == 'in_progress') {
          return Border.all(color: AppColors.primary.withOpacity(0.35));
        }
        return null;
      }

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  TranslationUtils.tr('scratch_card_screen_lots_progress'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${doneLots.toStringAsFixed(2)} / ${targetLots.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: Container(
                height: 10.h,
                color: AppColors.primary,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: safePct,
                    child: Container(
                      height: 10.h,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Text(
                  TranslationUtils.tr('scratch_card_screen_lots'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 10.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (firstStep != null && firstStep.targetLots > 0) ...[
                  Text(
                    '${firstStep.targetLots.toStringAsFixed(0)} ${TranslationUtils.tr('scratch_card_screen_lots_lower')}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 10.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '${firstStep.thresholdPercent}%',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 10.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${targetLots.toStringAsFixed(0)} ${TranslationUtils.tr('scratch_card_screen_lots_lower')} ✓',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 10.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            if (tiers.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            TranslationUtils.tr('scratch_card_screen_lots_completed'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          TranslationUtils.tr('scratch_card_screen_withdrawable_amount'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    ...tiers.map((step) {
                      final status = step.status;
                      final isCompleted = status == 'completed';
                      final amount = fallbackAmount(step);
                      return Container(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.primary.withOpacity(0.10),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    '${step.step} ${step.step == 1 ? TranslationUtils.tr('scratch_card_screen_lot') : TranslationUtils.tr('general_lots')}',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 13.sp,
                                      color:
                                          isCompleted
                                              ? AppColors.textPrimary
                                              : (status == 'in_progress'
                                                  ? AppColors.textPrimary
                                                  : AppColors.textGrey),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    '(${step.targetLots.toStringAsFixed(0)} ${TranslationUtils.tr('scratch_card_screen_lots_lower')} · ${step.thresholdPercent}%)',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 11.sp,
                                      color: AppColors.textGrey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBgColor(status),
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: statusBorder(status),
                                    ),
                                    child: Text(
                                      statusLabel(status),
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontSize: 10.sp,
                                        color: statusTextColor(status),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${amount.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 13.sp,
                                color:
                                    isCompleted
                                        ? AppColors.success
                                        : AppColors.textGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            SizedBox(height: 12.h),
            GetX<AccountController>(
              builder: (accCtrl) {
                final scratchLive = accCtrl.mt5Accounts.firstWhereOrNull(
                  (a) =>
                      a.masterGroupId == 'ScratchCard' &&
                      a.accountType.toLowerCase() == 'live',
                );
                final scratchAny = accCtrl.mt5Accounts.firstWhereOrNull(
                  (a) => a.masterGroupId == 'ScratchCard',
                );
                final acc = scratchLive ?? scratchAny;
                final accountId = int.tryParse(acc?.metaAccountNumber ?? '');

                final canConvert =
                    summary.canConvertPendingToBalance &&
                    canEnableByRules &&
                    accountId != null &&
                    !controller.isConverting.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RTLComponents.elevatedButton(
                      padding: EdgeInsets.zero,
                      text: TranslationUtils.tr('scratch_card_screen_convert_to_balance'),
                      width: double.infinity,
                      height: 42,
                      backgroundColor:
                          canConvert ? AppColors.primary : AppColors.border,
                      foregroundColor: AppColors.onColoredBackground,
                      isLoading: controller.isConverting.value,
                      onPressed:
                          canConvert
                              ? () => controller.convertCreditToBalance(
                                accountId: accountId,
                              )
                              : null,
                    ),
                    if (summary.canClaim || summary.claimStatus.isNotEmpty)
                      ..._buildClaimSection(summary),
                  ],
                );
              },
            ),
          ],
        ),
      );
    });
  }

  /// Reward claim (`POST v1/user/scratch-cards/claim`): button while
  /// `can_claim`, otherwise the pending/approved status chip.
  List<Widget> _buildClaimSection(ScratchCardSummaryModel summary) {
    final amount = summary.claimAmount > 0
        ? ' \$${summary.claimAmount.toStringAsFixed(2)}'
        : '';
    return [
      SizedBox(height: 10.h),
      if (summary.canClaim)
        RTLComponents.elevatedButton(
          padding: EdgeInsets.zero,
          text: '${TranslationUtils.tr('scratch_claim_reward')}$amount',
          width: double.infinity,
          height: 42,
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.onColoredBackground,
          isLoading: controller.isClaiming.value,
          onPressed:
              controller.isClaiming.value ? null : controller.claimReward,
        )
      else
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            TranslationUtils.trArgs('scratch_claim_status', {
              'status': summary.claimStatus.capitalizeFirst ?? summary.claimStatus,
            }) +
                amount,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      if (summary.claimHint.isNotEmpty) ...[
        SizedBox(height: 6.h),
        Text(
          summary.claimHint,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 11.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ];
  }
}

// MOCK REWARDS UI SECTION (legacy — unused)
// ─────────────────────────────────────────────────────────────────────────────

class _ScratchRewardsMockSection extends StatelessWidget {
  const _ScratchRewardsMockSection();

  static final Map<String, dynamic> _mockJson = {
    "streak": {
      "titleSmall": "Daily Streak",
      "title": "7 Days Strong",
      "rightSmall": "Bonus unlocks at 10 days",
      "rightCta": "3 more days to go →",
    },
    "unlock": {
      "title": "Credit → Withdrawal Unlock",
      "subtitle":
          "Complete 6 lots of trading to withdraw \$30 to your main balance",
      "targetLots": 6.0,
      "doneLots": 3.2,
      "withdrawTiers": [
        {"lots": 1, "amount": 5, "status": "done"},
        {"lots": 2, "amount": 10, "status": "done"},
        {"lots": 3, "amount": 15, "status": "done"},
        {"lots": 4, "amount": 20, "status": "pending"},
        {"lots": 5, "amount": 25, "status": "pending"},
        {"lots": 6, "amount": 30, "status": "pending", "label": "Full Unlock"},
      ],
    },
    "leaderboard": {
      "title": "Scratch Leaderboard",
      "week": "Apr 7 – 13",
      "rows": [
        {"rank": "🥇", "name": "R***l", "amount": 12.40, "you": false},
        {"rank": "🥈", "name": "P***a", "amount": 9.80, "you": false},
        {"rank": "🥉", "name": "A***d", "amount": 7.25, "you": false},
        {"rank": "4", "name": "S***h", "amount": 6.10, "you": false},
        {"rank": "5", "name": "M***a", "amount": 5.50, "you": false},
        {"rank": "8", "name": "Y***u", "amount": 3.74, "you": true},
      ],
    },
    "history": [
      {
        "icon": "🏆",
        "title": "Reward Unlocked",
        "sub": "13 Apr · 12:54",
        "chip": "Credited to account",
        "amount": 0.27,
      },
      {
        "icon": "🏆",
        "title": "Reward Unlocked",
        "sub": "12 Apr · 10:22",
        "chip": "Credited to account",
        "amount": 0.10,
      },
      {
        "icon": "🏆",
        "title": "Reward Unlocked",
        "sub": "11 Apr · 09:15",
        "chip": "Credited to account",
        "amount": 0.05,
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final streak = (_mockJson["streak"] as Map).cast<String, dynamic>();
    final unlock = (_mockJson["unlock"] as Map).cast<String, dynamic>();
    final leaderboard =
        (_mockJson["leaderboard"] as Map).cast<String, dynamic>();
    final history =
        ((_mockJson["history"] as List?) ?? [])
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MockStreakBanner(data: streak),
          SizedBox(height: 12.h),
          _MockUnlockCard(data: unlock),
          SizedBox(height: 14.h),
          _MockLeaderboardCard(data: leaderboard),
          SizedBox(height: 14.h),
          _MockHistoryCard(items: history),
        ],
      ),
    );
  }
}

class _MockStreakBanner extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MockStreakBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Text('🔥', style: AppTextStyles.bodyText.copyWith(fontSize: 22.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data["titleSmall"] ?? "").toString(),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  (data["title"] ?? "").toString(),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    color: AppColors.prizeYellow,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (data["rightSmall"] ?? "").toString(),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 10.sp,
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                (data["rightCta"] ?? "").toString(),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 11.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockUnlockCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MockUnlockCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final targetLots = (data["targetLots"] as num?)?.toDouble() ?? 6.0;
    final doneLots = (data["doneLots"] as num?)?.toDouble() ?? 0.0;
    final remaining = max(0.0, targetLots - doneLots);
    final pct = targetLots <= 0 ? 0.0 : (doneLots / targetLots).clamp(0.0, 1.0);
    final tiers =
        ((data["withdrawTiers"] as List?) ?? [])
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data["title"] ?? "").toString(),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.sp,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      (data["subtitle"] ?? "").toString(),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: Colors.grey.shade600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Column(
                  children: [
                    Text(
                      'Target',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 9.sp,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${targetLots.toStringAsFixed(0)} Lots',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                doneLots.toStringAsFixed(1),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
              SizedBox(width: 6.w),
              Padding(
                padding: EdgeInsets.only(bottom: 2.h),
                child: Text(
                  'lots traded',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.only(bottom: 2.h),
                child: Text(
                  'of ${targetLots.toStringAsFixed(1)} lots',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: Container(
              height: 10.h,
              color: AppColors.surfacePurpleLight,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(color: AppColors.primary),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceGold,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.prizeYellow, width: 0.8),
            ),
            child: Row(
              children: [
                Text('⚡', style: AppTextStyles.bodyText.copyWith(fontSize: 18.sp)),
                SizedBox(width: 10.w),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.prizeBrown,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(text: 'Only '),
                        TextSpan(
                          text:
                              '${remaining.toStringAsFixed(1)} more lots to trade',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(text: ' — and your full '),
                        TextSpan(
                          text: '\$30.00',
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: ' will be withdrawable to your main balance!',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lots Completed',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Withdrawable Amount',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                ...tiers.map((t) {
                  final lots = (t["lots"] ?? "").toString();
                  final amount = (t["amount"] as num?)?.toDouble() ?? 0.0;
                  final status = (t["status"] ?? "").toString();
                  final isDone = status == "done";
                  final label = (t["label"] ?? "").toString();
                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: AppColors.primary.withOpacity(0.10),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                '$lots Lot${lots == "1" ? "" : "s"}',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 13.sp,
                                  color:
                                      isDone
                                          ? AppColors.textPrimary
                                          : Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDone
                                          ? AppColors.prizeBgGreen
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  isDone ? 'done' : 'pending',
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 10.sp,
                                    color:
                                        isDone
                                            ? AppColors.prizeDarkGreen
                                            : Colors.grey.shade600,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${amount.toStringAsFixed(2)}${label.isNotEmpty ? ' ← $label' : ''}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            color:
                                isDone
                                    ? AppColors.prizeGreen
                                    : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(vertical: 13.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Text(
                  'Withdraw \$30.00 — Locked',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Complete ${remaining.toStringAsFixed(1)} more lots to unlock withdrawal',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockLeaderboardCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MockLeaderboardCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows =
        ((data["rows"] as List?) ?? [])
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (data["title"] ?? "").toString(),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                (data["week"] ?? "").toString(),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 11.sp,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...rows.map((r) {
            final isYou = r["you"] == true;
            final rank = (r["rank"] ?? "").toString();
            final name = (r["name"] ?? "").toString();
            final amount = (r["amount"] as num?)?.toDouble() ?? 0.0;
            final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
            return Container(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black.withOpacity(0.05)),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 26.w,
                    child: Text(
                      rank,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color:
                            isYou ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: isYou ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: BoxDecoration(
                      color:
                          isYou
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color:
                              isYou ? AppColors.prizeYellow : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            color:
                                isYou
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                            fontWeight:
                                isYou ? FontWeight.w500 : FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (isYou) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              'You',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 10.sp,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      color: AppColors.prizeGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _MockHistoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _MockHistoryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'History',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 10.h),
        ...items.map((h) {
          final icon = (h["icon"] ?? "🏆").toString();
          final title = (h["title"] ?? "").toString();
          final sub = (h["sub"] ?? "").toString();
          final chip = (h["chip"] ?? "").toString();
          final amount = (h["amount"] as num?)?.toDouble() ?? 0.0;
          return Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(icon, style: AppTextStyles.bodyText.copyWith(fontSize: 16.sp)),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        sub,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (chip.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.prizeBgGreen,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            chip,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 10.sp,
                              color: AppColors.prizeDarkGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '+\$${amount.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.prizeGreen,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ScratchHistoryList extends StatefulWidget {
  final ScratchCardController controller;
  const _ScratchHistoryList({required this.controller});

  @override
  State<_ScratchHistoryList> createState() => _ScratchHistoryListState();
}

class _ScratchHistoryListState extends State<_ScratchHistoryList> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final history =
          widget.controller.cards.where((c) => c.isScratched).toList();

      if (history.isEmpty) return const SizedBox.shrink();

      final visible = _showAll ? history.length : min(4, history.length);

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  TranslationUtils.tr('general_history'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                if (history.length > 4)
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(_showAll
                        ? TranslationUtils.tr('scratch_card_screen_show_less')
                        : TranslationUtils.tr('tw_view_all')),
                  ),
              ],
            ),
            SizedBox(height: 6.h),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                final card = history[index];
                final reward =
                    (card.rewardAmount is num)
                        ? (card.rewardAmount as num).toDouble()
                        : 0.0;

                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.expand(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20.r),
                            child: SvgPicture.asset(
                              'assets/svg/more/scratch_complete_with_cup.svg',
                              fit: BoxFit.cover,
                              colorMapper: PurpleToAppColorMapper(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reward > 0
                                  ? TranslationUtils.tr('scratch_card_screen_reward_unlocked_lower')
                                  : TranslationUtils.tr('scratch_card_screen_no_reward'),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '${TranslationUtils.tr('scratch_card_screen_expires')}: ${card.expiresLabel}',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 11.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        reward > 0 ? '\$${reward.toStringAsFixed(2)}' : '-',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color:
                              reward > 0 ? Colors.green.shade700 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final ScratchCardController controller;
  const _SummaryBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GetX<AccountController>(
        builder: (accCtrl) {
          final scratchLive = accCtrl.mt5Accounts.firstWhereOrNull(
            (a) =>
                a.masterGroupId == 'ScratchCard' &&
                a.accountType.toLowerCase() == 'live',
          );
          final scratchAny = accCtrl.mt5Accounts.firstWhereOrNull(
            (a) => a.masterGroupId == 'ScratchCard',
          );
          final acc = scratchLive ?? scratchAny;

          if (acc == null) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TranslationUtils.tr('scratch_card_screen_scratchcard_account'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        TranslationUtils.tr(
                          'scratch_card_screen_account_details_will_appear_here_once',
                        ),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 20.r,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            );
          }

          final balance = double.tryParse(acc.balance) ?? 0.0;
          final credit = double.tryParse(acc.credit) ?? 0.0;
          final equity = double.tryParse(acc.equity) ?? 0.0;

          Widget metric(String label, String value) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 10.sp,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TranslationUtils.tr('scratch_card_screen_scratchcard_account'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                acc.metaAccountNumber,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Obx(() {
                              final s = controller.summary.value;
                              final earned = s?.earnedIn30Days ?? 0.0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '---> \$${earned.toStringAsFixed(2)}',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.75),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.expand(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100.r),
                          child: SvgPicture.asset(
                            'assets/svg/more/scratch_complete_with_cup.svg',
                            fit: BoxFit.cover,
                            colorMapper: PurpleToAppColorMapper(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: metric(TranslationUtils.tr('general_balance'),
                        '\$${balance.toStringAsFixed(2)}'),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: metric(TranslationUtils.tr('trade_metric_credit'),
                        '\$${credit.toStringAsFixed(2)}'),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: metric(TranslationUtils.tr('general_equity'),
                        '\$${equity.toStringAsFixed(2)}'),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              RTLComponents.elevatedButton(
                padding: EdgeInsets.zero,
                text: TranslationUtils.tr('scratch_card_screen_trade_now'),
                width: double.infinity,
                height: 42,
                onPressed: () async {
                  try {
                    if (!Get.isRegistered<LoadingService>()) {
                      Get.put(LoadingService());
                    }
                    Get.loading.showLoadingWithoutMessage(
                      color: AppColors.primary,
                    );

                    // Ensure AccountController exists (may only be bound on Trading)
                    if (!Get.isRegistered<AccountController>()) {
                      Get.loading.hideLoading();
                      Get.offAllNamed(AppPages.TRADING, arguments: 1);
                      await Future.delayed(const Duration(milliseconds: 600));
                      Get.loading.showLoadingWithoutMessage(
                        color: AppColors.primary,
                      );
                    }

                    final accountCtrl = Get.find<AccountController>();
                    await accountCtrl.waitForInitialization();
                    await accountCtrl.forceRefreshMT5Accounts();

                    final scratchLive = accountCtrl.mt5Accounts
                        .firstWhereOrNull(
                          (a) =>
                              a.masterGroupId == 'ScratchCard' &&
                              a.accountType.toLowerCase() == 'live',
                        );
                    final scratchAny = accountCtrl.mt5Accounts.firstWhereOrNull(
                      (a) => a.masterGroupId == 'ScratchCard',
                    );
                    final target = scratchLive ?? scratchAny;

                    if (target == null) {
                      Get.loading.hideLoading();
                      CustomToastService.showError(
                        title: TranslationUtils.tr('scratch_card_screen_account_not_found'),
                        message: TranslationUtils.tr(
                          'scratch_card_screen_scratchcard_trading_account_not_available_yet',
                        ),
                      );
                      return;
                    }

                    await accountCtrl.setActiveMT5Account(
                      target.metaAccountNumber,
                    );

                    Get.loading.hideLoading();
                    Get.offAllNamed(AppPages.TRADING, arguments: 1);
                  } catch (_) {
                    if (Get.isRegistered<LoadingService>()) {
                      Get.loading.hideLoading();
                    }
                    CustomToastService.showError(
                      title: TranslationUtils.tr('general_error'),
                      message: TranslationUtils.tr(
                        'scratch_card_screen_unable_to_open_trade_screen_please',
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEXT CARD COUNTDOWN BANNER  (yellow progress line + countdown)
// ─────────────────────────────────────────────────────────────────────────────

class _NextCardCountdownBanner extends StatefulWidget {
  final ScratchCardController controller;
  const _NextCardCountdownBanner({required this.controller});

  @override
  State<_NextCardCountdownBanner> createState() =>
      _NextCardCountdownBannerState();
}

class _NextCardCountdownBannerState extends State<_NextCardCountdownBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh every second so the countdown is live
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatCountdown(Duration diff) {
    if (diff.inSeconds <= 0) {
      return TranslationUtils.tr('scratch_card_screen_available_now');
    }
    if (diff.inHours >= 24) {
      final d = diff.inDays;
      final h = diff.inHours % 24;
      return '${d}d ${h}h';
    }
    if (diff.inMinutes >= 60) {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      return '${h}h ${m}m';
    }
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = widget.controller.summary.value;
      if (s == null || !s.hasUpcomingCard) return const SizedBox.shrink();

      final target = s.nextCardDateTime!;
      final now = DateTime.now();
      final diff = target.difference(now);
      final totalWindow = const Duration(hours: 12); // full 12-hour window
      final elapsed = totalWindow - diff;
      // Progress goes from 0 → 1 as time approaches
      final progress = (elapsed.inSeconds / totalWindow.inSeconds).clamp(
        0.0,
        1.0,
      );

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.prizeBackground,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.yellow.shade300, width: 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange.shade700, size: 18.r),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    TranslationUtils.tr('scratch_card_screen_next_card_available_at'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  s.nextCardLabel,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            // Countdown + yellow progress line
            Row(
              children: [
                // Live countdown
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    _formatCountdown(diff),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      color: AppColors.whiteColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                // Yellow progress line
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 6.h,
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade200,
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                        child: FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade700,
                              borderRadius: BorderRadius.circular(3.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        TranslationUtils.tr('scratch_card_screen_new_card_arriving'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 10.sp,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.card_giftcard, size: 64.r, color: Colors.grey.shade300),
          SizedBox(height: 12.h),
          Text(
            TranslationUtils.tr('scratch_card_screen_no_scratch_cards_available'),
            style: AppTextStyles.bodyText.copyWith(fontSize: 15.sp, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCKED (NEXT CARD) GRID ITEM
// ─────────────────────────────────────────────────────────────────────────────

class _LockedScratchCardGridItem extends StatefulWidget {
  final ScratchCardSummaryModel summary;

  const _LockedScratchCardGridItem({required this.summary});

  @override
  State<_LockedScratchCardGridItem> createState() =>
      _LockedScratchCardGridItemState();
}

class _LockedScratchCardGridItemState
    extends State<_LockedScratchCardGridItem> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatCountdown(Duration diff) {
    if (diff.inSeconds <= 0) return '00:00';
    if (diff.inHours >= 24) {
      final d = diff.inDays;
      final h = diff.inHours % 24;
      return '${d}d ${h}h';
    }
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.summary.nextCardDateTime;
    if (target == null) return const SizedBox.shrink();

    final diff = target.difference(DateTime.now());
    final totalWindow = const Duration(hours: 12);
    final elapsed = totalWindow - diff;
    (elapsed.inSeconds / totalWindow.inSeconds).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        //   Get.dialog(
        //     AlertDialog(
        //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        //       backgroundColor: AppColors.tradeBackgroundCenterColor,
        //       title: Row(
        //         children: [
        //           Icon(Icons.lock_clock, color: Colors.orange.shade700, size: 22.r),
        //           SizedBox(width: 8.w),
        //           Text(
        //             'Card Locked',
        //             style: AppTextStyles.bodyText.copyWith(
        //               fontSize: 16.sp,
        //               fontWeight: FontWeight.w700,
        //               color: AppColors.textPrimary,
        //             ),
        //           ),
        //         ],
        //       ),
        //       content: Column(
        //         mainAxisSize: MainAxisSize.min,
        //         crossAxisAlignment: CrossAxisAlignment.start,
        //         children: [
        //           Text(
        //             'Next card will be available at:',
        //             style: AppTextStyles.bodyText.copyWith(
        //               fontSize: 13.sp,
        //               color: AppColors.textSecondary,
        //             ),
        //           ),
        //           SizedBox(height: 8.h),
        //           Container(
        //             padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        //             decoration: BoxDecoration(
        //               color: Colors.orange.shade50,
        //               borderRadius: BorderRadius.circular(10.r),
        //               border: Border.all(color: Colors.orange.shade200),
        //             ),
        //             child: Row(
        //               children: [
        //                 Icon(Icons.schedule, color: Colors.orange.shade700, size: 18.r),
        //                 SizedBox(width: 8.w),
        //                 Text(
        //                   widget.summary.nextCardLabel,
        //                   style: AppTextStyles.bodyText.copyWith(
        //                     fontSize: 15.sp,
        //                     fontWeight: FontWeight.w700,
        //                     color: Colors.orange.shade800,
        //                   ),
        //                 ),
        //               ],
        //             ),
        //           ),
        //           SizedBox(height: 12.h),
        //           Row(
        //             children: [
        //               Icon(Icons.timer, color: Colors.grey.shade600, size: 16.r),
        //               SizedBox(width: 6.w),
        //               Text(
        //                 'Time remaining: ${_formatCountdown(diff)}',
        //                 style: AppTextStyles.bodyText.copyWith(
        //                   fontSize: 13.sp,
        //                   color: Colors.grey.shade600,
        //                   fontWeight: FontWeight.w500,
        //                 ),
        //               ),
        //             ],
        //           ),
        //         ],
        //       ),
        //       actions: [
        //         TextButton(
        //           onPressed: () => Get.back(),
        //           child: Text(
        //             'OK',
        //             style: AppTextStyles.bodyText.copyWith(
        //               color: AppColors.primary,
        //               fontWeight: FontWeight.w700,
        //               fontSize: 14.sp,
        //             ),
        //           ),
        //         ),
        //       ],
        //     ),
        //   );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          children: [
            // Background SVG
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.31),
                  BlendMode.saturation,
                ),
                child: ColoredBox(
                  color: FlavorConfig.instance.primaryColor,
                  child: SvgPicture.asset(
                    'assets/svg/more/scratch-card.svg',
                    fit: BoxFit.cover,
                    colorMapper: PurpleToAppColorMapper(
                      Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),

            // Dark overlay
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.28)),
            ),

            // Lock icon + countdown content
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 8.h),

                  // Progress bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Container(
                      height: 30.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accentStatic,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: Text(
                        '${TranslationUtils.tr('scratch_card_screen_unlock_after')} ${_formatCountdown(diff)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.scratchCardYellow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID ITEM
// ─────────────────────────────────────────────────────────────────────────────

class _ScratchCardGridItem extends StatelessWidget {
  final ScratchCardApiModel card;
  final VoidCallback? onTap;

  const _ScratchCardGridItem({required this.card, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          children: [
            // Background SVG
            Positioned.fill(
              child: ColoredBox(
                color: FlavorConfig.instance.primaryColor,
                child: SvgPicture.asset(
                  card.isScratched
                      ? 'assets/svg/more/scratch_complete_with_cup.svg'
                      : 'assets/svg/more/scratch-card.svg',
                  fit: BoxFit.cover,
                  colorMapper: PurpleToAppColorMapper(AppColors.primary),
                  // colorMapper: PurpleToAppColorMapper(Colors.white.withOpacity(0.3)),
                ),
              ),
            ),

            // Text overlay for active cards
            if (!card.isScratched)
              Positioned.fill(
                child: Center(
                  child: Text(
                    TranslationUtils.tr('scratch_card_screen_tap_to_scratch'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.pureWhite,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Revealed overlay
            if (card.isScratched)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon(Icons.lock_open, color: AppColors.whiteColor, size: 28.r),
                        // SizedBox(height: 6.h),
                        // Text(
                        //   'Revealed',
                        //   style: AppTextStyles.bodyText.copyWith(
                        //     color: AppColors.whiteColor,
                        //     fontWeight: FontWeight.w700,
                        //     fontSize: 14.sp,
                        //   ),
                        // ),
                        SizedBox(height: 4.h),
                        if (card.rewardAmount != null &&
                            card.rewardAmount! > 0) ...[
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 27.h),
                              child: Text(
                                '\$${card.rewardAmount!.toStringAsFixed(2)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.whiteColor,
                                ),
                              ),
                            ),
                          ),
                        ] else
                          Text(
                            TranslationUtils.tr('scratch_card_screen_no_reward'),
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.whiteColor.withOpacity(0.7),
                              fontSize: 13.sp,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCRATCH CARD DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ScratchCardDetailScreen extends StatelessWidget {
  final ScratchCardApiModel card;

  const ScratchCardDetailScreen({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final listCtrl = Get.find<ScratchCardController>();
    final ctrl = Get.put(
      _ScratchGestureController(card),
      tag: 'scratch_${card.id}',
    );

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          Get.isRegistered<LanguageService>()
              ? Get.find<LanguageService>().tr('general_scratch_card')
              : 'Scratch Card',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  TranslationUtils.tr('scratch_card_screen_hooray'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),
                Text(
                  TranslationUtils.tr(
                    'scratch_card_screen_you_ve_got_scratch_card_reward',
                  ),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 32.h),

                // ── Scratch Area ──
                Obx(() {
                  // Look up latest card state from controller to be reactive
                  final c =
                      listCtrl.cards.firstWhereOrNull(
                        (item) => item.id == card.id,
                      ) ??
                      card;

                  if (c.isScratched) {
                    // Already revealed from API — show result card
                    return _RevealedCard(card: c);
                  }
                  if (ctrl.hasTriggeredReveal.value) {
                    // User scratched ≥ 25% — call reveal API once
                    return _RevealingCard(
                      ctrl: ctrl,
                      listCtrl: listCtrl,
                      card: c,
                    );
                  }
                  return _ActiveScratchCard(ctrl: ctrl);
                }),

                SizedBox(height: 32.h),

                // Sub-text
                Obx(() {
                  final c =
                      listCtrl.cards.firstWhereOrNull(
                        (item) => item.id == card.id,
                      ) ??
                      card;
                  if (c.isScratched || ctrl.hasTriggeredReveal.value) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      Text(
                        TranslationUtils.tr(
                          'scratch_card_screen_scratch_the_card_to_reveal_your',
                        ),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        TranslationUtils.tr(
                          'scratch_card_screen_scratch_at_least_25_to_unlock',
                        ),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          color: Colors.grey.shade500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCRATCH CARD DIALOG (new flow – shown on top of the grid)
// ─────────────────────────────────────────────────────────────────────────────
class _ScratchCardDialog extends StatelessWidget {
  final ScratchCardApiModel card;
  const _ScratchCardDialog({required this.card});

  @override
  Widget build(BuildContext context) {
    final listCtrl = Get.find<ScratchCardController>();
    final ctrl = Get.put(
      _ScratchGestureController(card),
      tag: 'scratch_dialog_${card.id}',
    );

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                TranslationUtils.tr('scratch_card_screen_hooray'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                TranslationUtils.tr(
                  'scratch_card_screen_you_ve_got_scratch_card_reward',
                ),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 18.h),

              // ── Scratch Area ──
              Obx(() {
                final c =
                    listCtrl.cards.firstWhereOrNull(
                      (item) => item.id == card.id,
                    ) ??
                    card;

                if (c.isScratched) {
                  return _RevealedCard(card: c);
                }
                if (ctrl.hasTriggeredReveal.value) {
                  return _RevealingCard(
                    ctrl: ctrl,
                    listCtrl: listCtrl,
                    card: c,
                  );
                }
                return _ActiveScratchCard(ctrl: ctrl);
              }),

              SizedBox(height: 14.h),

              // Sub-text
              Obx(() {
                final c =
                    listCtrl.cards.firstWhereOrNull(
                      (item) => item.id == card.id,
                    ) ??
                    card;
                if (c.isScratched || ctrl.hasTriggeredReveal.value) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    Text(
                      TranslationUtils.tr(
                        'scratch_card_screen_scratch_the_card_to_reveal_your',
                      ),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      TranslationUtils.tr(
                        'scratch_card_screen_scratch_at_least_25_to_unlock',
                      ),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.icongrey,
                        height: 1.4,
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVEALING CARD — calls API right after scratch threshold
// ─────────────────────────────────────────────────────────────────────────────

class _RevealingCard extends StatefulWidget {
  final _ScratchGestureController ctrl;
  final ScratchCardController listCtrl;
  final ScratchCardApiModel card;

  const _RevealingCard({
    required this.ctrl,
    required this.listCtrl,
    required this.card,
  });

  @override
  State<_RevealingCard> createState() => _RevealingCardState();
}

class _RevealingCardState extends State<_RevealingCard> {
  bool _called = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _callRevealApi());
  }

  Future<void> _callRevealApi() async {
    if (_called) return;
    _called = true;
    final reveal = await widget.listCtrl.revealCard(widget.card.id);
    if (reveal != null && mounted) {
      widget.listCtrl._showRevealResultDialog(
        reveal,
        onDone: () {
          if (Get.isDialogOpen ?? false) Get.back(); // close dialog
          // Get.back(); // close detail screen
          widget.listCtrl.fetchCards(); // Refresh list
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (widget.listCtrl.isRevealing.value) {
        return SizedBox(
          width: 250.h,
          height: 250.h,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
              SizedBox(height: 16.h),
              Text(
                TranslationUtils.tr('scratch_card_screen_revealing_your_reward'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }
      // API done — show reward content (win or lose will be in dialog)
      return _RewardContent(rewardAmount: null, hasResult: false);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE SCRATCH CARD (SVG face on top, captured as PNG for Scratcher)
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveScratchCard extends StatefulWidget {
  final _ScratchGestureController ctrl;
  const _ActiveScratchCard({required this.ctrl});

  @override
  State<_ActiveScratchCard> createState() => _ActiveScratchCardState();
}

class _ActiveScratchCardState extends State<_ActiveScratchCard> {
  final GlobalKey _svgRepaintKey = GlobalKey();
  Uint8List? _svgBytes;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureSvgImage());
  }

  Future<void> _captureSvgImage() async {
    if (_capturing || !mounted) return;
    _capturing = true;
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final boundary =
          _svgRepaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        _capturing = false;
        return;
      }

      final img = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();

      if (mounted && byteData != null) {
        setState(() => _svgBytes = byteData.buffer.asUint8List());
      }
    } catch (_) {
      _capturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardHeight = 250.0;
    return Container(
      width: cardHeight.h,
      height: cardHeight.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        // Scratcher's brush/mask coordinates are computed in raw local space;
        // pinning this subtree to LTR keeps them correct under an RTL locale.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              // ── LAYER 1 (bottom): Scratcher ──
              if (_svgBytes != null)
                Positioned.fill(
                  child: Scratcher(
                    key: widget.ctrl.scratchKey,
                    accuracy: ScratchAccuracy.low,
                    brushSize: 70,
                    threshold: 100,
                    color: AppColors.prizeDarkBg,
                    image: Image.memory(_svgBytes!, fit: BoxFit.cover),
                    onChange: widget.ctrl.onProgress,
                    onScratchEnd: widget.ctrl.onScratchEnd,
                    child: _RewardContent(rewardAmount: null, hasResult: false),
                  ),
                ),

              // ── LAYER 2 (top): SVG overlay — fades out when bytes ready ──
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _svgBytes != null,
                  child: AnimatedOpacity(
                    opacity: _svgBytes == null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: RepaintBoundary(
                      key: _svgRepaintKey,
                      child: const _ScratchCoverFace(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SVG cover face
class _ScratchCoverFace extends StatelessWidget {
  const _ScratchCoverFace();

  @override
  Widget build(BuildContext context) {
    // Ensure the scratch-cover render is fully opaque (no see-through to reward layer).
    return ColoredBox(
      color: AppColors.primary,
      // color: AppColors.prizeDarkBg, // matches the dark card background
      child: SvgPicture.asset(
        'assets/svg/more/scratch_pop.svg',
        fit: BoxFit.cover,
        colorMapper: PurpleToAppColorMapper(AppColors.primary),
      ),
    );
  }
}

// Reward content (shown beneath the scratch layer)
class _RewardContent extends StatelessWidget {
  final double? rewardAmount;
  final bool hasResult;
  const _RewardContent({required this.rewardAmount, required this.hasResult});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250.h,
      height: 250.h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20.r)),
      child: Stack(
        children: [
          // Background SVG (purple - scratchcomplete.svg as-is)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: SvgPicture.asset(
                'assets/svg/more/scratchcomplete.svg',
                fit: BoxFit.cover,
                colorMapper: PurpleToAppColorMapper(AppColors.primary),
              ),
            ),
          ),
          // Content overlay
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cup icon
                SvgPicture.asset(
                  'assets/svg/more/scratchcompletecup.svg',
                  width: 52.r,
                  height: 52.r,
                  colorMapper: PurpleToAppColorMapper(AppColors.primary),
                ),
                SizedBox(height: 10.h),
                // Amount
                Text(
                  hasResult && rewardAmount != null
                      ? '\$${rewardAmount!.toStringAsFixed(2)}'
                      : '???',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.yellow.shade300,
                    shadows: [
                      Shadow(
                        blurRadius: 12,
                        color: Colors.black.withOpacity(0.4),
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                // Status text
                Text(
                  hasResult
                      ? TranslationUtils.tr('scratch_card_screen_reward_unlocked')
                      : TranslationUtils.tr('scratch_card_screen_scratch_to_reveal'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVEALED CARD (already scratched — shown in detail screen)
// ─────────────────────────────────────────────────────────────────────────────

class _RevealedCard extends StatelessWidget {
  final ScratchCardApiModel card;

  const _RevealedCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final isWin = card.rewardAmount != null && card.rewardAmount! > 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: 250.h,
        height: 250.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: (isWin ? AppColors.primary : Colors.grey).withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background SVG (purple - scratchcomplete.svg as-is)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: SvgPicture.asset(
                  'assets/svg/more/scratchcomplete.svg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWin)
                    SvgPicture.asset(
                      'assets/svg/more/scratchcompletecup.svg',
                      width: 52.r,
                      height: 52.r,
                    )
                  else
                    Icon(
                      Icons.sentiment_dissatisfied_rounded,
                      color: AppColors.whiteColor.withOpacity(0.7),
                      size: 52.r,
                    ),
                  SizedBox(height: 10.h),
                  if (isWin)
                    Text(
                      '\$${card.rewardAmount!.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 40.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.yellow.shade300,
                        shadows: [
                          Shadow(
                            blurRadius: 12,
                            color: Colors.black.withOpacity(0.4),
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      TranslationUtils.tr('scratch_card_screen_better_luck_next_time'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  SizedBox(height: 8.h),
                  Text(
                    isWin
                        ? TranslationUtils.tr('scratch_card_screen_reward_unlocked')
                        : TranslationUtils.tr('scratch_card_screen_no_reward_this_time'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.whiteColor.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIN RESULT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _WinResultDialog extends StatelessWidget {
  final ScratchCardRevealModel reveal;
  final VoidCallback onDone;

  const _WinResultDialog({required this.reveal, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background SVG layer
          // Positioned.fill(
          //   child: SvgPicture.asset(
          //     'assets/svg/more/scratchcomplete.svg',
          //     fit: BoxFit.cover,
          //   ),
          // ),
          // Foreground content
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.r),
              color: AppColors.whiteColor,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cup icon
                Text(
                  TranslationUtils.tr('congratulations_title'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),

                Text(
                  TranslationUtils.tr('scratch_card_screen_you_won'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                Container(
                  // width: 170.w,
                  // height: 88.h,
                  padding: EdgeInsets.symmetric(
                    horizontal: 50.w,
                    vertical: 25.h,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22.r),
                    // image: DecorationImage(
                    // image: const AssetImage(
                    //   'assets/image/scratchcomplete.jpg',
                    // ),
                    // fit: BoxFit.cover,
                    // colorMapper: PurpleToAppColorMapper(AppColors.primary),
                    //   colorFilter: ColorFilter.mode(
                    //     AppColors.primary.withValues(alpha: 0.3),
                    //     BlendMode.srcATop,
                    //   ),
                    // ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/more/scratchcompletecup.svg',
                          width: 50.r,
                          height: 50.r,
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          '\$${reveal.rewardAmount.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 34.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                // Credit status
                _CreditStatusBadge(reveal: reveal),

                SizedBox(height: 6.h),

                // Trade now + Done
                // Done button
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.whiteColor,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      TranslationUtils.tr('navigation_done'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditStatusBadge extends StatelessWidget {
  final ScratchCardRevealModel reveal;
  const _CreditStatusBadge({required this.reveal});

  @override
  Widget build(BuildContext context) {
    if (reveal.isCreditFailed) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.red.shade400.withOpacity(0.25),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber,
              color: Colors.orange.shade200,
              size: 16.r,
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                TranslationUtils.trArgs('scratch_credit_failed_reason', {
                  'reason':
                      reveal.creditError.isNotEmpty
                          ? reveal.creditError
                          : TranslationUtils.tr('scratch_please_contact_support'),
                }),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 11.sp,
                  color: Colors.orange.shade200,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final label =
        reveal.creditStatus == 'credited'
            ? TranslationUtils.tr(
              'scratch_card_screen_credited_to_your_trading_account',
            )
            : TranslationUtils.tr(
              'scratch_card_screen_pending_will_be_credited_shortly',
            );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 12.sp,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOSE RESULT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _LoseResultDialog extends StatelessWidget {
  final VoidCallback onDone;
  const _LoseResultDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
          color: AppColors.whiteColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sentiment_dissatisfied_rounded,
                color: Colors.grey.shade400,
                size: 40.r,
              ),
            ),
            SizedBox(height: 20.h),

            Text(
              TranslationUtils.tr('scratch_card_screen_better_luck_next_time_2'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 20.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),

            Text(
              TranslationUtils.tr(
                'scratch_card_screen_no_reward_this_time_new_cards',
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24.h),

            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.whiteColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  TranslationUtils.tr('general_close'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE SCRATCH ACCOUNT DIALOG  (shows on 409 SCRATCH_ACCOUNT_REQUIRED)
// ─────────────────────────────────────────────────────────────────────────────

class _CreateScratchAccountDialog extends StatefulWidget {
  const _CreateScratchAccountDialog();

  @override
  State<_CreateScratchAccountDialog> createState() =>
      _CreateScratchAccountDialogState();
}

class _CreateScratchAccountDialogState
    extends State<_CreateScratchAccountDialog> {
  final _mainPwCtrl = TextEditingController();
  final _investorPwCtrl = TextEditingController();
  bool _showMainPw = false;
  bool _showInvestorPw = false;
  String? _error;

  @override
  void dispose() {
    _mainPwCtrl.dispose();
    _investorPwCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = null);

    final main = _mainPwCtrl.text.trim();
    final investor = _investorPwCtrl.text.trim();

    if (main.isEmpty) {
      setState(() => _error =
          TranslationUtils.tr('scratch_card_screen_main_password_required'));
      return;
    }
    if (investor.isEmpty) {
      setState(() => _error =
          TranslationUtils.tr('scratch_card_screen_investor_password_required'));
      return;
    }
    if (main == investor) {
      setState(() => _error =
          TranslationUtils.tr('scratch_card_screen_passwords_cannot_be_same'));
      return;
    }

    final ctrl = Get.find<ScratchCardController>();
    ctrl.createScratchAccount(mainPassword: main, investorPassword: investor);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ScratchCardController>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                    size: 22.r,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TranslationUtils.tr('scratch_card_screen_create_scratch_account'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        TranslationUtils.tr(
                          'scratch_card_screen_required_to_scratch_and_reveal_rewards',
                        ),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // Main password
            Text(
              TranslationUtils.tr('scratch_card_screen_main_password'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            _PasswordField(
              controller: _mainPwCtrl,
              hint: TranslationUtils.tr('scratch_card_screen_enter_main_password'),
              obscure: !_showMainPw,
              onToggle: () => setState(() => _showMainPw = !_showMainPw),
            ),
            SizedBox(height: 14.h),

            // Investor password
            Text(
              TranslationUtils.tr('create_account_investor_password'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            _PasswordField(
              controller: _investorPwCtrl,
              hint: TranslationUtils.tr('create_account_enter_investor_password'),
              obscure: !_showInvestorPw,
              onToggle:
                  () => setState(() => _showInvestorPw = !_showInvestorPw),
            ),

            // Error
            if (_error != null) ...[
              SizedBox(height: 10.h),
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 14.r),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 22.h),

            // Buttons
            Obx(() {
              final loading = ctrl.isCreatingAccount.value;
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: Text(
                        TranslationUtils.tr('general_cancel'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.whiteColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        elevation: 0,
                      ),
                      child:
                          loading
                              ? SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: CircularProgressIndicator(
                                  color: AppColors.whiteColor,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                TranslationUtils.tr('scratch_card_screen_create'),
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade400,
            size: 20.r,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SVG COLOR MAPPER (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

class PurpleToAppColorMapper extends ColorMapper {
  final Color targetColor;
  const PurpleToAppColorMapper(this.targetColor);

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final opaqueHex =
        color
            .withOpacity(1.0)
            .value
            .toRadixString(16)
            .substring(2)
            .toUpperCase();

    final isPurple =
        opaqueHex == '461872' ||
        opaqueHex == '5C288E' ||
        opaqueHex == 'B96BDE' ||
        // opaqueHex == '5F259E' ||
        opaqueHex == '9D63D8';

    if (opaqueHex == '7E41B8') {
      return targetColor.withOpacity(0.9);
    }
    if (opaqueHex == '5F259E') {
      return targetColor.withOpacity(0.9);
    }
    if (isPurple) {
      return targetColor.withOpacity(0.7);
    }
    return color;
  }
}
