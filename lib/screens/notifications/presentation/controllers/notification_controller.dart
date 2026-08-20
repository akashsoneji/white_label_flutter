import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../data/models/notification_model.dart';
import '../../data/providers/notification_api_provider.dart';

class NotificationController extends GetxController {
  final NotificationApiProvider _apiProvider = NotificationApiProvider();
  
  final ScrollController scrollController = ScrollController();
  var isLoading = true.obs;
  var isPaginating = false.obs;
  var notifications = <NotificationItem>[].obs;
  
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
      if (response != null && response.notifications != null) {
        if (response.notifications!.isEmpty) {
          hasMoreData = false;
        } else {
          notifications.addAll(response.notifications!);
        }
      } else {
        hasMoreData = false;
      }
    } finally {
      isPaginating(false);
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
