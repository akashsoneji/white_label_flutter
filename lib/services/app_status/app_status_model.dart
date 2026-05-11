/// Model for app status API response
class AppStatusModel {
  final String appVersion;
  final bool isUnderMaintenance;
  final bool isForceUpdate;
  final String? laterDate;
  final String? updateUrlIos;
  final String? updateUrlAndroid;
  final String? releaseNotes;

  AppStatusModel({
    required this.appVersion,
    required this.isUnderMaintenance,
    required this.isForceUpdate,
    this.laterDate,
    this.updateUrlIos,
    this.updateUrlAndroid,
    this.releaseNotes,
  });

  /// Create from JSON map
  factory AppStatusModel.fromJson(Map<String, dynamic> json) {
    return AppStatusModel(
      appVersion:
          json['app_version'] as String? ??
          json['latest_version'] as String? ??
          '1.0.0',
      isUnderMaintenance: json['is_under_maintenance'] as bool? ?? false,
      isForceUpdate:
          json['is_force_update'] as bool? ??
          json['force_update'] as bool? ??
          true,
      laterDate: json['later_date'] as String?,
      updateUrlIos: json['update_url_ios'] as String?,
      updateUrlAndroid: json['update_url_android'] as String?,
      releaseNotes: json['release_notes'] as String?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'app_version': appVersion,
      'is_under_maintenance': isUnderMaintenance,
      'is_force_update': isForceUpdate,
      'later_date': laterDate,
      'update_url_ios': updateUrlIos,
      'update_url_android': updateUrlAndroid,
      'release_notes': releaseNotes,
    };
  }

  @override
  String toString() {
    return 'AppStatusModel(appVersion: $appVersion, isUnderMaintenance: $isUnderMaintenance, isForceUpdate: $isForceUpdate, laterDate: $laterDate, releaseNotes: $releaseNotes)';
  }
}
