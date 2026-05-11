// lib/data/models/instrument.dart
class Instrument {
  final String name;
  final String flag;
  final String status;
  final String bidPrice;
  final String askPrice;
  final String lowPrice;
  final String? heigh;
  final String highPrice;
  final bool isFavorite;
  final String category;

  Instrument({
    required this.name,
    required this.flag,
    required this.status,
    required this.bidPrice,
    this.heigh,
    required this.askPrice,
    required this.lowPrice,
    required this.highPrice,
    this.isFavorite = false,
    required this.category,
  });
}
