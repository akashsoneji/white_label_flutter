class NotificationResponse {
  final List<NotificationItem>? notifications;
  final int? unreadTotal;

  NotificationResponse({this.notifications, this.unreadTotal});

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
      unreadTotal: int.tryParse(json['unread_total']?.toString() ?? ''),
    );
  }
}

class Mt5Credentials {
  final String login;
  final String server;
  final String planTitle;
  final String leverage;
  final String currency;
  final String mainPassword;
  final String investorPassword;

  const Mt5Credentials({
    required this.login,
    required this.server,
    required this.planTitle,
    required this.leverage,
    required this.currency,
    required this.mainPassword,
    required this.investorPassword,
  });

  factory Mt5Credentials.fromJson(Map<String, dynamic> json) {
    final nested = json['data'];
    final source = nested is Map<String, dynamic> ? {...json, ...nested} : json;
    String read(String key) => source[key]?.toString() ?? '';
    return Mt5Credentials(
      login: read('login'),
      server: read('server'),
      planTitle: read('plan_title'),
      leverage: read('leverage'),
      currency: read('currency'),
      mainPassword: read('main_password'),
      investorPassword: read('investor_password'),
    );
  }
}

/// Result of GET notifications/mt5-credentials/{id}. The server shows the
/// passwords only once; afterwards it answers 410 `already_shown`.
class Mt5CredentialsResult {
  final Mt5Credentials? credentials;
  final bool alreadyShown;
  final bool notFound;
  final String? message;

  const Mt5CredentialsResult({
    this.credentials,
    this.alreadyShown = false,
    this.notFound = false,
    this.message,
  });
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

  /// The web portal opens a one-time MT5 credentials popup for these.
  /// The API does not flag them explicitly (a new account arrives as type
  /// "Account Created" with target_url "#"), so they are recognised by text;
  /// the server answers 404 when a notification has no credentials.
  bool get isMt5Credentials {
    final text = '${type ?? ''} ${title ?? ''}'.toLowerCase();
    return text.contains('credential') ||
        text.contains('account created') ||
        (targetUrl ?? '').contains('mt5-credentials');
  }

  NotificationItem markedRead(String readAt) {
    return NotificationItem(
      type: type,
      id: id,
      amount: amount,
      fullname: fullname,
      fulltext: fulltext,
      title: title,
      avatar: avatar,
      createdAt: createdAt,
      newNt: newNt,
      readAt: readAt,
      targetUrl: targetUrl,
      module: module,
    );
  }
}
