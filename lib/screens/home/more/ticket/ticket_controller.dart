import 'dart:io';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/ticket_model.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class TicketController extends GetxController {
  final RxBool isDownloading = false.obs;
  // ── List state ──────────────────────────────────────────────────────────
  final RxList<TicketDepartment> departments = <TicketDepartment>[].obs;
  final RxList<Ticket> tickets = <Ticket>[].obs;

  final RxString selectedDepartment = 'all'.obs;
  final RxString selectedStatus = 'all'.obs; // all | open | closed
  final RxString selectedPriority = 'all'.obs; // all | low | medium | high
  final RxString searchQuery = ''.obs;

  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorMessage = ''.obs;

  int _currentPage = 1;
  final RxBool hasMorePages = false.obs;
  static const int _perPage = 20;

  // ── Detail state ────────────────────────────────────────────────────────
  final Rxn<TicketDetail> ticketDetail = Rxn<TicketDetail>();
  final RxBool isDetailLoading = false.obs;
  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDepartments();
    fetchTickets(refresh: true);
  }

  // ── Departments ───────────────────────────────────────────────────────────
  Future<void> fetchDepartments() async {
    try {
      final res = await ApiService.get(
        endpoint: ApiConstants.ticketDepartments,
      );
      if (!res.success || res.data == null) return;
      final data = res.data?['data'] ?? res.data;
      if (data is List) {
        departments.assignAll(
          data
              .whereType<Map>()
              .map((e) =>
                  TicketDepartment.fromJson(e.cast<String, dynamic>()))
              .toList(),
        );
      }
    } catch (_) {
      // Departments are non-critical; ignore failures silently.
    }
  }

  // ── List ──────────────────────────────────────────────────────────────────
  Map<String, dynamic> _buildQuery() {
    final qp = <String, dynamic>{
      'page': '$_currentPage',
      'per_page': '$_perPage',
    };
    if (selectedStatus.value != 'all') qp['status'] = selectedStatus.value;
    if (selectedDepartment.value != 'all') {
      qp['department'] = selectedDepartment.value;
    }
    if (selectedPriority.value != 'all') {
      qp['priority'] = selectedPriority.value;
    }
    final q = searchQuery.value.trim();
    if (q.isNotEmpty) qp['search'] = q;
    return qp;
  }

  Future<void> fetchTickets({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      isLoading.value = true;
      errorMessage.value = '';
    } else {
      if (!hasMorePages.value || isLoadingMore.value) return;
      isLoadingMore.value = true;
      _currentPage += 1;
    }

    try {
      final res = await ApiService.get(
        endpoint: ApiConstants.tickets,
        queryParameters: _buildQuery(),
      );

      if (!res.success || res.data == null) {
        if (refresh) tickets.clear();
        errorMessage.value = res.message ?? 'Failed to load tickets';
        return;
      }

      // Response shape: { data: { data: [...], pagination: {...} } }
      final payload = res.data is Map ? (res.data as Map)['data'] : null;
      final list = payload is Map
          ? payload['data']
          : payload; // tolerate a flat { data: [...] } shape too
      final parsed = list is List
          ? list
              .whereType<Map>()
              .map((e) => Ticket.fromJson(e.cast<String, dynamic>()))
              .toList()
          : <Ticket>[];

      if (refresh) {
        tickets.assignAll(parsed);
      } else {
        tickets.addAll(parsed);
      }

      final paginationJson = payload is Map
          ? payload['pagination']
          : (res.data is Map ? (res.data as Map)['pagination'] : null);
      final pagination = TicketPagination.fromJson(
          paginationJson is Map ? paginationJson.cast<String, dynamic>() : null);
      hasMorePages.value = pagination.hasMore;
    } catch (e) {
      if (refresh) tickets.clear();
      errorMessage.value = 'Load error: $e';
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  void setDepartment(String id) {
    if (selectedDepartment.value == id) return;
    selectedDepartment.value = id;
    fetchTickets(refresh: true);
  }

  void setStatus(String status) {
    if (selectedStatus.value == status) return;
    selectedStatus.value = status;
    fetchTickets(refresh: true);
  }

  void setPriority(String priority) {
    if (selectedPriority.value == priority) return;
    selectedPriority.value = priority;
    fetchTickets(refresh: true);
  }

  void setSearch(String query) {
    searchQuery.value = query;
    fetchTickets(refresh: true);
  }

  void clearFilters() {
    selectedDepartment.value = 'all';
    selectedStatus.value = 'all';
    selectedPriority.value = 'all';
    searchQuery.value = '';
    fetchTickets(refresh: true);
  }

  bool get hasActiveFilters =>
      selectedDepartment.value != 'all' ||
      selectedStatus.value != 'all' ||
      selectedPriority.value != 'all' ||
      searchQuery.value.trim().isNotEmpty;

  // ── Create ──────────────────────────────────────────────────────────────
  Future<bool> createTicket({
    required String departmentId,
    required String priority,
    required String title,
    required String description,
    File? attachment,
  }) async {
    isSubmitting.value = true;
    try {
      final res = await ApiService.postFormWithFile(
        endpoint: ApiConstants.tickets,
        formData: {
          'department_id': departmentId,
          'priority': priority,
          'title': title,
          'description': description,
        },
        file: attachment,
        // Backend expects the file field to be named `file` (verified
        // against the live `/api/user/tickets` create request).
        fileField: 'file',
      );

      if (res.success) {
        CustomToastService.showSuccess(
          message: res.message ?? 'Ticket created successfully',
        );
        await fetchTickets(refresh: true);
        return true;
      }
      CustomToastService.showError(
        message: res.message ?? 'Failed to create ticket',
      );
      return false;
    } catch (e) {
      CustomToastService.showError(message: 'Failed to create ticket: $e');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ── Detail ──────────────────────────────────────────────────────────────
  Future<void> fetchTicketDetail(String ticketId) async {
    isDetailLoading.value = true;
    errorMessage.value = '';
    try {
      final res = await ApiService.get(
        endpoint: ApiConstants.ticketDetail(ticketId),
      );
      if (!res.success || res.data == null) {
        errorMessage.value = res.message ?? 'Failed to load ticket';
        return;
      }
      final data = res.data?['data'];
      final map = data is Map<String, dynamic>
          ? data
          : (res.data as Map<String, dynamic>);
      ticketDetail.value = TicketDetail.fromJson(map);
    } catch (e) {
      errorMessage.value = 'Load error: $e';
    } finally {
      isDetailLoading.value = false;
    }
  }

  // ── Reply ─────────────────────────────────────────────────────────────────
  /// Sends a reply to a ticket. The backend expects a JSON body
  /// `{ "reply_text": "..." }` (verified against the live
  /// `/api/user/tickets/{id}/reply` request) — NOT multipart form data.
  Future<bool> replyToTicket(
    String ticketId,
    String message,
  ) async {
    if (message.trim().isEmpty) return false;
    isSubmitting.value = true;
    try {
      final res = await ApiService.post(
        endpoint: ApiConstants.ticketReply(ticketId),
        data: {'reply_text': message.trim()},
      );
      if (res.success) {
        CustomToastService.showSuccess(
          message: res.message ?? 'Reply posted successfully',
        );
        await fetchTicketDetail(ticketId);
        return true;
      }
      CustomToastService.showError(
        message: res.message ?? 'Failed to post reply',
      );
      return false;
    } catch (e) {
      CustomToastService.showError(message: 'Failed to post reply: $e');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ── Close ─────────────────────────────────────────────────────────────────
  Future<bool> closeTicket(String ticketId) async {
    isSubmitting.value = true;
    try {
      final res = await ApiService.post(
        endpoint: ApiConstants.ticketClose(ticketId),
      );
      if (res.success) {
        CustomToastService.showSuccess(
          message: res.message ?? 'Ticket closed successfully',
        );
        await fetchTicketDetail(ticketId);
        await fetchTickets(refresh: true);
        return true;
      }
      CustomToastService.showError(
        message: res.message ?? 'Failed to close ticket',
      );
      return false;
    } catch (e) {
      CustomToastService.showError(message: 'Failed to close ticket: $e');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ── Attachment ──────────────────────────────────────────────────────────
  /// Downloads the attachment with the auth token (the endpoint is protected
  /// and returns 401 if opened directly in a browser), saves it to the temp
  /// directory and opens it with the device's default viewer.
  Future<void> openAttachment(TicketAttachment attachment) async {
    // If the URL is already a local device path, just open it.
    if (attachment.url.isNotEmpty &&
        !attachment.url.startsWith('http') &&
        File(attachment.url).existsSync()) {
      await OpenFilex.open(attachment.url);
      return;
    }

    final url = attachment.url.isNotEmpty
        ? attachment.url
        : '${ApiConstants.baseUrl}${ApiConstants.ticketAttachment}?path=${Uri.encodeComponent(attachment.path)}';

    isDownloading.value = true;
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': '*/*',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        CustomToastService.showError(
          message: 'Could not download attachment (${response.statusCode})',
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final safeName = attachment.filename.isNotEmpty
          ? attachment.filename
          : 'attachment_${DateTime.now().millisecondsSinceEpoch}';
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(response.bodyBytes);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        CustomToastService.showError(
          message: 'Could not open attachment: ${result.message}',
        );
      }
    } catch (e) {
      CustomToastService.showError(message: 'Could not open attachment: $e');
    } finally {
      isDownloading.value = false;
    }
  }
}
