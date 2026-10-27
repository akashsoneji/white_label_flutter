import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import '../../data/models/notification_model.dart';
import '../../data/providers/notification_api_provider.dart';
import '../pages/widgets/mt5_credentials_sheet.dart';

class NotificationController extends GetxController {
  final NotificationApiProvider _apiProvider = NotificationApiProvider();
  
  final ScrollController scrollController = ScrollController();
  var isLoading = true.obs;
  var isPaginating = false.obs;
  var notifications = <NotificationItem>[].obs;
  var unreadTotal = 0.obs;
  var isMarkingAllRead = false.obs;
  var isOpeningCredentials = false.obs;

  var currentPage = 1;
  var hasMoreData = true;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_scrollListener);
    fetchNotifications();
  }

  void _scrollListener() {
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 50) {
      fetchMoreNotifications();
    }
  }

  Future<void> fetchNotifications() async {
    isLoading(true);
    currentPage = 1;
    hasMoreData = true;
    try {
      final response = await _apiProvider.getAllNotifications(currentPage);
      if (response != null && response.notifications != null) {
        notifications.assignAll(response.notifications!);
        unreadTotal.value = response.unreadTotal ??
            response.notifications!.where((n) => n.readAt == null).length;
        if (response.notifications!.isEmpty) {
          hasMoreData = false;
        }
      } else {
        hasMoreData = false;
      }
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchMoreNotifications() async {
    if (!hasMoreData || isPaginating.value) return;
    
    isPaginating(true);
    currentPage++;
    try {
      final response = await _apiProvider.getAllNotifications(currentPage);
      // GET user/notifications has no `page` param (per the API spec) and
      // returns the same list for every page, so stop once nothing new comes.
      final knownIds = notifications.map((n) => n.id).toSet();
      final newItems = (response?.notifications ?? const <NotificationItem>[])
          .where((n) => n.id == null || !knownIds.contains(n.id))
          .toList();
      if (newItems.isEmpty) {
        hasMoreData = false;
      } else {
        notifications.addAll(newItems);
      }
    } finally {
      isPaginating(false);
    }
  }

  Future<void> markAllAsRead() async {
    if (isMarkingAllRead.value || unreadTotal.value == 0) return;
    isMarkingAllRead(true);
    try {
      final success = await _apiProvider.markAllAsRead();
      if (!success) return;
      final now = DateTime.now().toIso8601String();
      // Materialise first: assignAll clears the list before reading the
      // lazy iterable, which would otherwise map over an empty list.
      final updated = notifications
          .map((n) => n.readAt == null ? n.markedRead(now) : n)
          .toList();
      notifications.assignAll(updated);
      unreadTotal.value = 0;
    } finally {
      isMarkingAllRead(false);
    }
  }

  Future<void> markAsRead(NotificationItem item) async {
    final id = item.id;
    if (id == null || item.readAt != null) return;
    final index = notifications.indexOf(item);
    if (index < 0) return;
    notifications[index] = item.markedRead(DateTime.now().toIso8601String());
    if (unreadTotal.value > 0) unreadTotal.value--;

    final success = await _apiProvider.markAsRead(id);
    if (success) return;
    // Server rejected it; restore the unread state so the UI stays truthful.
    final restoreIndex = notifications.indexWhere((n) => n.id == id);
    if (restoreIndex >= 0) notifications[restoreIndex] = item;
    unreadTotal.value++;
  }

  Future<void> openMt5Credentials(NotificationItem item) async {
    final id = item.id;
    if (id == null || isOpeningCredentials.value) return;
    isOpeningCredentials(true);
    final Mt5CredentialsResult result;
    try {
      result = await _apiProvider.getMt5Credentials(id);
    } finally {
      isOpeningCredentials(false);
    }
    markAsRead(item);

    final credentials = result.credentials;
    // Not a credentials notification after all; marking it read is enough.
    if (credentials == null && result.notFound) return;
    if (credentials == null) {
      CustomToastService.showError(
        message: result.alreadyShown
            ? TranslationUtils.tr('mt5_credentials_already_shown')
            : (result.message?.isNotEmpty == true
                ? result.message!
                : TranslationUtils.tr('mt5_credentials_load_failed')),
      );
      return;
    }

    await Get.bottomSheet<void>(
      Mt5CredentialsSheet(credentials: credentials),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    // Acknowledge on close (any dismissal), same as the web `ackAndClose`.
    await _apiProvider.ackMt5Credentials(id);
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
