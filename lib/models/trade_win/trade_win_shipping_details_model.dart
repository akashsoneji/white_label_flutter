class TradeWinShippingDetailsModel {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String country;

  const TradeWinShippingDetailsModel({
    this.name = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.country = '',
  });

  factory TradeWinShippingDetailsModel.fromJson(Map<String, dynamic> json) {
    return TradeWinShippingDetailsModel(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'city': city,
    'country': country,
  };
}
