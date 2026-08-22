class EnrollmentStepModel {
  final int id;
  final String name;
  final String description;
  final String link;
  final String status;
  final DateTime? clickedAt;

  EnrollmentStepModel({
    required this.id,
    required this.name,
    required this.description,
    required this.link,
    required this.status,
    this.clickedAt,
  });

  factory EnrollmentStepModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentStepModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      clickedAt: json['clicked_at'] != null ? DateTime.tryParse(json['clicked_at'].toString()) : null,
    );
  }

  bool get isCompleted => status == 'completed';
}
