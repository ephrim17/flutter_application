class BibleVersion {
  const BibleVersion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.languageLabel,
    required this.description,
    required this.bookFileNames,
    this.assetBasePath,
    this.downloadBaseUrl,
    this.storagePath,
    this.enabled = true,
    this.sortOrder = 0,
    this.contentVersion = 1,
  });

  final String id;
  final String title;
  final String subtitle;
  final String languageLabel;
  final String description;
  final List<String> bookFileNames;
  final String? assetBasePath;
  final String? downloadBaseUrl;
  final String? storagePath;
  final bool enabled;
  final int sortOrder;
  final int contentVersion;

  factory BibleVersion.fromMap(String id, Map<String, dynamic> data) {
    return BibleVersion(
      id: id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : id,
      subtitle: (data['subtitle'] as String?) ?? '',
      languageLabel: (data['languageLabel'] as String?) ?? id.toUpperCase(),
      description: (data['description'] as String?) ??
          'Downloads all Bible book files for offline reading.',
      bookFileNames: (data['bookFileNames'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
      assetBasePath: data['assetBasePath'] as String?,
      downloadBaseUrl: data['downloadBaseUrl'] as String?,
      storagePath: data['storagePath'] as String?,
      enabled: data['enabled'] as bool? ?? true,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      contentVersion: (data['contentVersion'] as num?)?.toInt() ?? 1,
    );
  }

  bool get hasRemoteSource =>
      downloadBaseUrl != null && downloadBaseUrl!.trim().isNotEmpty;

  bool get hasStorageSource =>
      storagePath != null && storagePath!.trim().isNotEmpty;

  bool get hasAssetSource =>
      assetBasePath != null && assetBasePath!.trim().isNotEmpty;
}
