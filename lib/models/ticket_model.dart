/// Models for the Support Ticket module.

class TicketDepartment {
  final String id;
  final String name;
  final String? icon;

  const TicketDepartment({required this.id, required this.name, this.icon});

  factory TicketDepartment.fromJson(Map<String, dynamic> json) {
    return TicketDepartment(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: json['icon']?.toString(),
    );
  }
}

class TicketAssignee {
  final String name;
  final String? avatar;

  const TicketAssignee({required this.name, this.avatar});

  factory TicketAssignee.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TicketAssignee(name: '');
    return TicketAssignee(
      name: (json['name'] ?? '').toString(),
      avatar: json['avatar']?.toString(),
    );
  }
}

class Ticket {
  final String id;
  final String title;
  final String description;
  final String department;
  final String priority;
  final String status;
  final String createdAt;
  final String updatedAt;
  final TicketAssignee? assignee;
  final int conversationCount;

  const Ticket({
    required this.id,
    required this.title,
    required this.description,
    required this.department,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.assignee,
    this.conversationCount = 0,
  });

  bool get isOpen => status.toLowerCase() == 'open';

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['subject'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      department: (json['department'] is Map
              ? (json['department']['name'] ?? '')
              : (json['department'] ?? ''))
          .toString(),
      priority: (json['priority'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      assignee: json['assignee'] is Map<String, dynamic>
          ? TicketAssignee.fromJson(json['assignee'] as Map<String, dynamic>)
          : null,
      conversationCount: json['conversation_count'] is num
          ? (json['conversation_count'] as num).toInt()
          : 0,
    );
  }
}

class TicketConversation {
  final String id;
  final String type;
  final TicketAssignee author;
  final String content;
  final String timestamp;
  final TicketAttachment? attachment;

  const TicketConversation({
    required this.id,
    required this.type,
    required this.author,
    required this.content,
    required this.timestamp,
    this.attachment,
  });

  /// Whether this message was sent by the current user (right-aligned bubble).
  bool get isUser => type.toLowerCase() == 'user' || type.toLowerCase() == 'customer';

  factory TicketConversation.fromJson(Map<String, dynamic> json) {
    return TicketConversation(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? json['sender_type'] ?? '').toString(),
      author: TicketAssignee.fromJson(
        json['author'] is Map<String, dynamic>
            ? json['author'] as Map<String, dynamic>
            : null,
      ),
      content: (json['content'] ?? json['message'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? json['created_at'] ?? '').toString(),
      attachment: json['attachment'] is Map<String, dynamic>
          ? TicketAttachment.fromJson(
              json['attachment'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TicketAttachment {
  final String filename;
  final String path;
  final String url;

  const TicketAttachment({
    required this.filename,
    required this.path,
    required this.url,
  });

  factory TicketAttachment.fromJson(Map<String, dynamic> json) {
    return TicketAttachment(
      filename: (json['filename'] ?? json['name'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
    );
  }
}

class TicketDetail {
  final Ticket ticket;
  final List<TicketConversation> conversation;
  final TicketAttachment? attachment;

  const TicketDetail({
    required this.ticket,
    required this.conversation,
    this.attachment,
  });

  List<TicketAttachment> get attachments {
    final list = <TicketAttachment>[];
    if (attachment != null) list.add(attachment!);
    for (final c in conversation) {
      if (c.attachment != null) list.add(c.attachment!);
    }
    return list;
  }

  factory TicketDetail.fromJson(Map<String, dynamic> json) {
    final convRaw = json['conversation'] ?? json['conversations'] ?? json['replies'];
    return TicketDetail(
      ticket: Ticket.fromJson(json),
      conversation: convRaw is List
          ? convRaw
              .whereType<Map>()
              .map((e) =>
                  TicketConversation.fromJson(e.cast<String, dynamic>()))
              .toList()
          : <TicketConversation>[],
      attachment: json['attachment'] is Map<String, dynamic>
          ? TicketAttachment.fromJson(
              json['attachment'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TicketPagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const TicketPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;

  factory TicketPagination.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TicketPagination(
          currentPage: 1, lastPage: 1, perPage: 20, total: 0);
    }
    int parse(dynamic v, int fallback) =>
        v is num ? v.toInt() : (int.tryParse('$v') ?? fallback);
    return TicketPagination(
      currentPage: parse(json['current_page'], 1),
      lastPage: parse(json['last_page'], 1),
      perPage: parse(json['per_page'], 20),
      total: parse(json['total'], 0),
    );
  }
}
