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
    final title = data['title']?.toString().trim() ?? '';
    final bookFileNames = data['bookFileNames'];
    return BibleVersion(
      id: id,
      title: title.isEmpty ? id : title,
      subtitle: data['subtitle']?.toString().trim() ?? '',
      languageLabel: data['languageLabel']?.toString().trim().isNotEmpty == true
          ? data['languageLabel'].toString().trim()
          : id.toUpperCase(),
      description: data['description']?.toString().trim().isNotEmpty == true
          ? data['description'].toString().trim()
          : 'Downloads all Bible book files for offline reading.',
      bookFileNames: bookFileNames is Iterable
          ? bookFileNames
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
          : const [],
      assetBasePath: _optionalString(data['assetBasePath']),
      downloadBaseUrl: _optionalString(data['downloadBaseUrl']),
      storagePath: _optionalString(data['storagePath']),
      enabled: data['enabled'] != false,
      sortOrder: _int(data['sortOrder']),
      contentVersion: _int(data['contentVersion'], fallback: 1),
    );
  }

  bool get hasRemoteSource =>
      downloadBaseUrl != null && downloadBaseUrl!.trim().isNotEmpty;

  bool get hasStorageSource =>
      storagePath != null && storagePath!.trim().isNotEmpty;

  bool get hasAssetSource =>
      assetBasePath != null && assetBasePath!.trim().isNotEmpty;
}

String? _optionalString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}
