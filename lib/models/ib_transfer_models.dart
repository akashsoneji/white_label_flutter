class IbTransferInitResponse {
  bool? success;
  bool? enabled;
  double? availableBalance;
  double? minAmount;
  double? dailyCap;
  double? dailyRemaining;

  IbTransferInitResponse({
    this.success,
    this.enabled,
    this.availableBalance,
    this.minAmount,
    this.dailyCap,
    this.dailyRemaining,
  });

  factory IbTransferInitResponse.fromJson(Map<String, dynamic> json) {
    return IbTransferInitResponse(
      success: json['success'],
      enabled: json['enabled'],
      availableBalance: json['available_balance'] != null
          ? (json['available_balance'] is int
              ? (json['available_balance'] as int).toDouble()
              : json['available_balance'])
          : null,
      minAmount: json['min_amount'] != null
          ? (json['min_amount'] is int
              ? (json['min_amount'] as int).toDouble()
              : json['min_amount'])
          : null,
      dailyCap: json['daily_cap'] != null
          ? (json['daily_cap'] is int
              ? (json['daily_cap'] as int).toDouble()
              : json['daily_cap'])
          : null,
      dailyRemaining: json['daily_remaining'] != null
          ? (json['daily_remaining'] is int
              ? (json['daily_remaining'] as int).toDouble()
              : json['daily_remaining'])
          : null,
    );
  }
}

class IbTransferClientSearchResponse {
  List<IbTransferClient>? results;

  IbTransferClientSearchResponse({this.results});

  factory IbTransferClientSearchResponse.fromJson(Map<String, dynamic> json) {
    return IbTransferClientSearchResponse(
      results: json['results'] != null
          ? List<IbTransferClient>.from(
              json['results'].map((x) => IbTransferClient.fromJson(x)),
            )
          : null,
    );
  }
}

class IbTransferClient {
  int? id;
  String? name;
  String? email;
  bool? isIb;

  IbTransferClient({this.id, this.name, this.email, this.isIb});

  factory IbTransferClient.fromJson(Map<String, dynamic> json) {
    return IbTransferClient(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      isIb: json['is_ib'],
    );
  }
}

class IbTransferHistoryResponse {
  bool? success;
  IbTransferHistoryData? data;

  IbTransferHistoryResponse({this.success, this.data});

  factory IbTransferHistoryResponse.fromJson(Map<String, dynamic> json) {
    return IbTransferHistoryResponse(
      success: json['success'],
      data: json['data'] != null ? IbTransferHistoryData.fromJson(json['data']) : null,
    );
  }
}

class IbTransferHistoryData {
  int? currentPage;
  List<IbTransferHistoryItem>? data;
  String? firstPageUrl;
  int? from;
  int? lastPage;
  String? lastPageUrl;
  String? nextPageUrl;
  String? path;
  int? perPage;
  String? prevPageUrl;
  int? to;
  int? total;

  IbTransferHistoryData({
    this.currentPage,
    this.data,
    this.firstPageUrl,
    this.from,
    this.lastPage,
    this.lastPageUrl,
    this.nextPageUrl,
    this.path,
    this.perPage,
    this.prevPageUrl,
    this.to,
    this.total,
  });

  factory IbTransferHistoryData.fromJson(Map<String, dynamic> json) {
    return IbTransferHistoryData(
      currentPage: json['current_page'],
      data: json['data'] != null
          ? List<IbTransferHistoryItem>.from(
              json['data'].map((x) => IbTransferHistoryItem.fromJson(x)),
            )
          : null,
      firstPageUrl: json['first_page_url'],
      from: json['from'],
      lastPage: json['last_page'],
      lastPageUrl: json['last_page_url'],
      nextPageUrl: json['next_page_url'],
      path: json['path'],
      perPage: json['per_page'],
      prevPageUrl: json['prev_page_url'],
      to: json['to'],
      total: json['total'],
    );
  }
}

class IbTransferHistoryItem {
  int? id;
  int? fromIbUserId;
  int? toClientUserId;
  String? amount;
  String? currency;
  String? status;
  String? requestedAt;
  String? ibComment;
  String? createdAt;
  String? updatedAt;
  IbTransferToClient? toClient;

  IbTransferHistoryItem({
    this.id,
    this.fromIbUserId,
    this.toClientUserId,
    this.amount,
    this.currency,
    this.status,
    this.requestedAt,
    this.ibComment,
    this.createdAt,
    this.updatedAt,
    this.toClient,
  });

  factory IbTransferHistoryItem.fromJson(Map<String, dynamic> json) {
    return IbTransferHistoryItem(
      id: json['id'],
      fromIbUserId: json['from_ib_user_id'],
      toClientUserId: json['to_client_user_id'],
      amount: json['amount'],
      currency: json['currency'],
      status: json['status'],
      requestedAt: json['requested_at'],
      ibComment: json['ib_comment'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      toClient: json['to_client'] != null
          ? IbTransferToClient.fromJson(json['to_client'])
          : null,
    );
  }
}

class IbTransferToClient {
  int? id;
  String? firstName;
  String? lastName;
  String? email;

  IbTransferToClient({this.id, this.firstName, this.lastName, this.email});

  factory IbTransferToClient.fromJson(Map<String, dynamic> json) {
    return IbTransferToClient(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
    );
  }
}
