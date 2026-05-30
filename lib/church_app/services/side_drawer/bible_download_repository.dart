import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/models/bible_version_model.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_catalog.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_filesystem.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _selectedBibleVersionKey = 'selected_bible_version_id';
const _metadataFileName = 'metadata.json';

class BibleDownloadProgress {
  const BibleDownloadProgress({
    required this.completedFiles,
    required this.totalFiles,
    required this.currentFileName,
  });

  final int completedFiles;
  final int totalFiles;
  final String currentFileName;

  double get progress {
    if (totalFiles == 0) return 0;
    return completedFiles / totalFiles;
  }
}

class BibleDownloadRepository {
  BibleDownloadRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  static const _maxBibleFileBytes = 5 * 1024 * 1024;

  final FirebaseStorage _storage;

  Future<bool> supportsLocalDownloads() => isLocalBibleStorageSupported();

  Future<BibleVersion> selectedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return bibleVersionById(prefs.getString(_selectedBibleVersionKey));
  }

  Future<void> setSelectedVersion(BibleVersion version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedBibleVersionKey, version.id);
  }

  Future<int> downloadedFileCount(BibleVersion version) async {
    var count = 0;
    for (final fileName in version.bookFileNames) {
      if (await localBibleFileExists(fileName, version.id)) {
        count++;
      }
    }
    return count;
  }

  Future<bool> isDownloaded(BibleVersion version) async {
    final localContentVersion = await downloadedContentVersion(version);
    if (localContentVersion != version.contentVersion) {
      return false;
    }

    return hasAllDownloadedFiles(version);
  }

  Future<bool> hasAllDownloadedFiles(BibleVersion version) async {
    final count = await downloadedFileCount(version);
    return count == version.bookFileNames.length;
  }

  Future<int?> downloadedContentVersion(BibleVersion version) async {
    final metadata = await readLocalBibleFile(_metadataFileName, version.id);
    if (metadata == null) return null;

    try {
      final data = json.decode(metadata) as Map<String, dynamic>;
      return (data['contentVersion'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasUpdate(BibleVersion version) async {
    final localContentVersion = await downloadedContentVersion(version);
    if (localContentVersion == null) return false;
    return localContentVersion < version.contentVersion;
  }

  Future<String> loadDownloadedBook({
    required BibleVersion version,
    required String bookKey,
  }) async {
    final fileName = '$bookKey.json';
    final content = await readLocalBibleFile(fileName, version.id);
    if (content == null) {
      throw StateError('${version.title} is not fully downloaded.');
    }
    return content;
  }

  Future<String> loadSourceBook({
    required BibleVersion version,
    required String bookKey,
  }) {
    return _loadSourceFile(version, '$bookKey.json');
  }

  Future<void> downloadVersion(
    BibleVersion version, {
    void Function(BibleDownloadProgress progress)? onProgress,
  }) async {
    if (!await isLocalBibleStorageSupported()) {
      throw UnsupportedError('Local Bible downloads are not supported here.');
    }
    if (!version.hasStorageSource &&
        !version.hasRemoteSource &&
        !version.hasAssetSource) {
      throw StateError('${version.title} does not have a download source.');
    }

    final totalFiles = version.bookFileNames.length;
    final localContentVersion = await downloadedContentVersion(version);
    final existingFileCount = await downloadedFileCount(version);
    final shouldReplaceAll = (localContentVersion != null &&
            localContentVersion < version.contentVersion) ||
        (localContentVersion == null && existingFileCount == totalFiles);

    for (var index = 0; index < totalFiles; index++) {
      final fileName = version.bookFileNames[index];
      onProgress?.call(
        BibleDownloadProgress(
          completedFiles: index,
          totalFiles: totalFiles,
          currentFileName: fileName,
        ),
      );

      if (!shouldReplaceAll &&
          await localBibleFileExists(fileName, version.id)) {
        onProgress?.call(
          BibleDownloadProgress(
            completedFiles: index + 1,
            totalFiles: totalFiles,
            currentFileName: fileName,
          ),
        );
        continue;
      }

      final content = await _loadSourceFile(version, fileName);
      json.decode(content);
      await writeLocalBibleFile(fileName, content, version.id);

      onProgress?.call(
        BibleDownloadProgress(
          completedFiles: index + 1,
          totalFiles: totalFiles,
          currentFileName: fileName,
        ),
      );
    }

    await writeLocalBibleFile(
      _metadataFileName,
      json.encode({
        'contentVersion': version.contentVersion,
        'downloadedAt': DateTime.now().toIso8601String(),
      }),
      version.id,
    );
  }

  Future<String> _loadSourceFile(BibleVersion version, String fileName) async {
    if (version.hasStorageSource) {
      final basePath = version.storagePath!.replaceAll(RegExp(r'/+$'), '');
      final data = await _storage
          .ref()
          .child('$basePath/$fileName')
          .getData(_maxBibleFileBytes)
          .timeout(const Duration(seconds: 30));
      if (data == null) {
        throw StateError('Could not download $fileName.');
      }
      return utf8.decode(data);
    }

    if (version.hasRemoteSource) {
      final baseUrl = version.downloadBaseUrl!.replaceAll(RegExp(r'/+$'), '');
      final response = await http
          .get(Uri.parse('$baseUrl/${Uri.encodeComponent(fileName)}'))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Could not download $fileName.');
      }
      return response.body;
    }

    final basePath = version.assetBasePath!.replaceAll(RegExp(r'/+$'), '');
    return rootBundle
        .loadString('$basePath/$fileName')
        .timeout(const Duration(seconds: 15));
  }
}
