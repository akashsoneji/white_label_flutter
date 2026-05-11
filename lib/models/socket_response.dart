class SocketResponse {
  final List<Group> groups;

  SocketResponse({required this.groups});

  SocketResponse copyWith({List<Group>? groups}) =>
      SocketResponse(groups: groups ?? this.groups);

  factory SocketResponse.fromJson(Map<String, dynamic> json) {
    return SocketResponse(
      groups:
          (json['groups'] as List? ?? [])
              .map((group) => Group.fromJson(group as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'groups': groups.map((group) => group.toJson()).toList()};
  }
}

class Group {
  final String groupName;
  final List<ListElement> list;

  Group({required this.groupName, required this.list});

  Group copyWith({String? groupName, List<ListElement>? list}) =>
      Group(groupName: groupName ?? this.groupName, list: list ?? this.list);

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      groupName: json['group_name'] ?? '',
      list:
          (json['list'] as List? ?? [])
              .map((item) => ListElement.fromJson(item as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_name': groupName,
      'list': list.map((item) => item.toJson()).toList(),
    };
  }
}

class ListElement {
  final String symbol;
  final int digits;
  final double bid;
  final double ask;
  final int last;
  final int volume;
  final int volumeReal;
  final String logo;
  final double spreadDiff;
  final String?
  category; // Category from WebSocket (e.g., "Crypto", "Indices Spot")
  final double? dayHigh; // Day high price
  final double? dayLow; // Day low price

  ListElement({
    required this.symbol,
    required this.digits,
    required this.bid,
    required this.ask,
    required this.last,
    required this.volume,
    required this.volumeReal,
    required this.logo,
    required this.spreadDiff,
    this.category,
    this.dayHigh,
    this.dayLow,
  });

  ListElement copyWith({
    String? symbol,
    int? digits,
    double? bid,
    double? ask,
    int? last,
    int? volume,
    int? volumeReal,
    String? logo,
    double? spreadDiff,
    String? category,
    double? dayHigh,
    double? dayLow,
  }) => ListElement(
    symbol: symbol ?? this.symbol,
    digits: digits ?? this.digits,
    bid: bid ?? this.bid,
    ask: ask ?? this.ask,
    last: last ?? this.last,
    volume: volume ?? this.volume,
    volumeReal: volumeReal ?? this.volumeReal,
    logo: logo ?? this.logo,
    spreadDiff: spreadDiff ?? this.spreadDiff,
    category: category ?? this.category,
    dayHigh: dayHigh ?? this.dayHigh,
    dayLow: dayLow ?? this.dayLow,
  );

  factory ListElement.fromJson(Map<String, dynamic> json) {
    return ListElement(
      symbol: json['Symbol'] ?? '',
      digits: json['Digits'] ?? 0,
      bid: (json['Bid'] ?? 0.0).toDouble(),
      ask: (json['Ask'] ?? 0.0).toDouble(),
      last: json['Last'] ?? 0,
      volume: json['Volume'] ?? 0,
      volumeReal: json['VolumeReal'] ?? 0,
      logo: json['logo'] ?? '',
      spreadDiff: (json['SpreadDiff'] ?? 0.0).toDouble(),
      category: json['category'] ?? json['Category'],
      dayHigh:
          json['day_high'] != null
              ? (json['day_high'] as num).toDouble()
              : null,
      dayLow:
          json['day_low'] != null ? (json['day_low'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Symbol': symbol,
      'Digits': digits,
      'Bid': bid,
      'Ask': ask,
      'Last': last,
      'Volume': volume,
      'VolumeReal': volumeReal,
      'logo': logo,
      'SpreadDiff': spreadDiff,
      'category': category,
      'day_high': dayHigh,
      'day_low': dayLow,
    };
  }
}
