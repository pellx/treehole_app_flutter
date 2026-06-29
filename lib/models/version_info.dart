class VersionInfo {
  /// 当前 app 版本号，与 pubspec.yaml 保持一致
  static const String currentVersion = '1.0.0';

  final int id;
  final String versionNumber;
  final String platform;
  final String changelog;
  final String releaseDate;

  const VersionInfo({
    required this.id,
    required this.versionNumber,
    required this.platform,
    required this.changelog,
    required this.releaseDate,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      id: json['id'] as int? ?? 0,
      versionNumber: json['version_number'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      releaseDate: json['release_date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'version_number': versionNumber,
    'platform': platform,
    'changelog': changelog,
    'release_date': releaseDate,
  };
}
