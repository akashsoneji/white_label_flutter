import 'package:get/get.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// IB-side demo contests (`ib/demo-contest/*`): the contests this IB created,
/// create/edit, cancel, prize fund top-up and enrollment approval.
///
/// Rows are kept as raw maps because `my-contests` returns the contest record
/// as stored (the same field names `store` accepts), and screens only read a
/// handful of them.
class IbDemoContestController extends GetxController {
  final RxList<Map<String, dynamic>> contests = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final RxList<Map<String, dynamic>> instrumentCategories =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> instrumentSymbols =
      <Map<String, dynamic>>[].obs;

  final RxList<Map<String, dynamic>> enrollments = <Map<String, dynamic>>[].obs;
  final RxBool isEnrollmentsLoading = false.obs;
  final RxSet<int> busyIds = <int>{}.obs;
  final RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadContests();
  }

  static List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// `data` may be a plain list or a Laravel paginator (`data.data`).
  static List<Map<String, dynamic>> _rowsOf(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is List) return _mapList(data);
    if (data is Map) return _mapList(data['data']);
    return const [];
  }

  static String _messageOr(String? message, String fallbackKey) =>
      message != null && message.isNotEmpty
          ? message
          : TranslationUtils.tr(fallbackKey);

  Future<void> loadContests() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final response =
          await ApiService.get(endpoint: ApiConstants.ibDemoContestMyContests);
      if (!response.success) {
        errorMessage.value =
            _messageOr(response.message, 'ib_contest_load_failed');
        return;
      }
      contests.assignAll(_rowsOf(response.data));
    } catch (_) {
      errorMessage.value = TranslationUtils.tr('ib_contest_load_failed');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadInstruments() async {
    if (instrumentSymbols.isNotEmpty) return;
    try {
      final response =
          await ApiService.get(endpoint: ApiConstants.ibDemoContestInstruments);
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (!response.success || data is! Map) return;
      instrumentCategories.assignAll(_mapList(data['categories']));
      instrumentSymbols.assignAll(_mapList(data['symbols']));
    } catch (_) {
      // The instrument picker is optional; the form still submits without it.
    }
  }

  /// Create (`id == null`) or update a contest. Returns true on success.
  Future<bool> saveContest(Map<String, dynamic> payload, {int? id}) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      final response = await ApiService.post(
        endpoint: id == null
            ? ApiConstants.ibDemoContestStore
            : ApiConstants.ibDemoContestUpdate(id),
        data: payload,
      );
      if (!response.success) {
        CustomToastService.showError(
          message: _messageOr(response.message, 'ib_contest_save_failed'),
        );
        return false;
      }
      CustomToastService.showSuccess(
        message: _messageOr(response.message, 'ib_contest_saved'),
      );
      await loadContests();
      return true;
    } catch (_) {
      CustomToastService.showError(
        message: TranslationUtils.tr('ib_contest_save_failed'),
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> cancelContest(int id) => _runAction(
        id,
        () => ApiService.post(endpoint: ApiConstants.ibDemoContestCancel(id)),
        reloadContests: true,
      );

  Future<void> addPrizeFund(int id, double amount) => _runAction(
        id,
        () => ApiService.post(
          endpoint: ApiConstants.ibDemoContestAddPrizeFund(id),
          data: {'amount': amount},
        ),
        reloadContests: true,
      );

  Future<void> loadEnrollments(int contestId) async {
    isEnrollmentsLoading.value = true;
    enrollments.clear();
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.ibDemoContestEnrollments(contestId),
      );
      if (!response.success) {
        CustomToastService.showError(
          message: _messageOr(response.message, 'ib_contest_load_failed'),
        );
        return;
      }
      enrollments.assignAll(_rowsOf(response.data));
    } catch (_) {
      CustomToastService.showError(
        message: TranslationUtils.tr('ib_contest_load_failed'),
      );
    } finally {
      isEnrollmentsLoading.value = false;
    }
  }

  Future<void> approveEnrollment(int enrollmentId, int contestId) =>
      _runAction(
        enrollmentId,
        () => ApiService.post(
          endpoint: ApiConstants.ibDemoContestEnrollmentApprove(enrollmentId),
        ),
        reloadEnrollmentsOf: contestId,
      );

  Future<void> rejectEnrollment(
    int enrollmentId,
    int contestId,
    String reason,
  ) =>
      _runAction(
        enrollmentId,
        () => ApiService.post(
          endpoint: ApiConstants.ibDemoContestEnrollmentReject(enrollmentId),
          data: {if (reason.isNotEmpty) 'reason': reason},
        ),
        reloadEnrollmentsOf: contestId,
      );

  Future<void> _runAction(
    int busyId,
    Future<dynamic> Function() call, {
    bool reloadContests = false,
    int? reloadEnrollmentsOf,
  }) async {
    if (busyIds.contains(busyId)) return;
    busyIds.add(busyId);
    try {
      final response = await call();
      if (!response.success) {
        CustomToastService.showError(
          message: _messageOr(response.message, 'ib_contest_action_failed'),
        );
        return;
      }
      CustomToastService.showSuccess(
        message: _messageOr(response.message, 'ib_contest_action_done'),
      );
      if (reloadContests) await loadContests();
      if (reloadEnrollmentsOf != null) {
        await loadEnrollments(reloadEnrollmentsOf);
      }
    } catch (_) {
      CustomToastService.showError(
        message: TranslationUtils.tr('ib_contest_action_failed'),
      );
    } finally {
      busyIds.remove(busyId);
    }
  }
}
