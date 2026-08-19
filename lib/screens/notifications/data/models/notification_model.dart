class NotificationResponse {
  final List<NotificationItem>? notifications;

  NotificationResponse({this.notifications});

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    dynamic notifs = json['notifications'];
    List<dynamic>? list;
    
    if (notifs is List) {
      list = notifs;
    } else if (notifs is Map && notifs['data'] is List) {
      list = notifs['data']; // Handle Laravel paginator inside 'notifications'
    } else if (json['data'] is List) {
      list = json['data'];
    } else if (json['data'] is Map && json['data']['notifications'] is List) {
      list = json['data']['notifications'];
    }

    return NotificationResponse(
      notifications: list != null
          ? list.map((i) => NotificationItem.fromJson(i as Map<String, dynamic>)).toList()
          : <NotificationItem>[],
    );
  }
}

class NotificationItem {
  final String? type;
  final int? id;
  final String? amount;
  final String? fullname;
  final String? fulltext;
  final String? title;
  final String? avatar;
  final String? createdAt;
  final String? newNt;
  final String? readAt;
  final String? targetUrl;
  final String? module;

  NotificationItem({
    this.type,
    this.id,
    this.amount,
    this.fullname,
    this.fulltext,
    this.title,
    this.avatar,
    this.createdAt,
    this.newNt,
    this.readAt,
    this.targetUrl,
    this.module,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      type: json['type']?.toString(),
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      amount: json['amount']?.toString(),
      fullname: json['fullname']?.toString(),
      fulltext: json['fulltext']?.toString(),
      title: json['title']?.toString(),
      avatar: json['avatar']?.toString(),
      createdAt: json['created_at']?.toString(),
      newNt: json['new_nt']?.toString(),
      readAt: json['read_at']?.toString(),
      targetUrl: json['target_url']?.toString(),
      module: json['module']?.toString(),
    );
  }
}
