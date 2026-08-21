class BannerResponse {
  bool? status;
  bool? success;
  String? message;
  BannerData? data;

  BannerResponse({this.status, this.success, this.message, this.data});

  factory BannerResponse.fromJson(Map<String, dynamic> json) {
    BannerData? bannerData;
    if (json['data'] != null) {
      if (json['data'] is Map<String, dynamic>) {
        bannerData = BannerData.fromJson(json['data'] as Map<String, dynamic>);
      } else if (json['data'] is List) {
        bannerData = BannerData(
          banners: List<BannerItem>.from(
            (json['data'] as List).map(
              (x) => BannerItem.fromJson(x is Map<String, dynamic> ? x : {}),
            ),
          ),
        );
      }
    } else if (json['banners'] != null) {
      bannerData = BannerData.fromJson(json);
    }

    final rawStatus = json['status'];
    final rawSuccess = json['success'];
    final bool isStatusTrue = rawStatus is bool
        ? rawStatus
        : (rawStatus?.toString().toLowerCase() == 'true' || rawStatus == 1);
    final bool isSuccessTrue = rawSuccess is bool
        ? rawSuccess
        : (rawSuccess?.toString().toLowerCase() == 'true' || rawSuccess == 1);

    return BannerResponse(
      status: isStatusTrue,
      success: isSuccessTrue,
      message: json['message']?.toString(),
      data: bannerData,
    );
  }
}

class BannerData {
  List<BannerItem>? banners;

  BannerData({this.banners});

  factory BannerData.fromJson(Map<String, dynamic> json) {
    return BannerData(
      banners: json['banners'] != null
          ? List<BannerItem>.from(
              json['banners'].map((x) => BannerItem.fromJson(x)),
            )
          : null,
    );
  }
}

class BannerItem {
  int? id;
  String? title;
  String? imageUrl;
  String? imageAlt;
  String? clickUrl;
  bool? clickUrlNewTab;
  String? position;
  String? style;
  String? priority;
  bool? isDismissible;
  bool? isRecurring;

  BannerItem({
    this.id,
    this.title,
    this.imageUrl,
    this.imageAlt,
    this.clickUrl,
    this.clickUrlNewTab,
    this.position,
    this.style,
    this.priority,
    this.isDismissible,
    this.isRecurring,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      id: json['id'],
      title: json['title'],
      imageUrl: json['image_url'],
      imageAlt: json['image_alt'],
      clickUrl: json['click_url'],
      clickUrlNewTab: json['click_url_new_tab'] is bool
          ? json['click_url_new_tab']
          : json['click_url_new_tab'] == 1,
      position: json['position'],
      style: json['style'],
      priority: json['priority'],
      isDismissible: json['is_dismissible'] is bool
          ? json['is_dismissible']
          : json['is_dismissible'] == 1,
      isRecurring: json['is_recurring'] is bool
          ? json['is_recurring']
          : json['is_recurring'] == 1,
    );
  }
}
