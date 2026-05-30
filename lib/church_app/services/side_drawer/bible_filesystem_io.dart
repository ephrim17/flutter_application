import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<bool> isLocalBibleStorageSupported() async => true;

Future<String?> getLocalBibleVersionDirectory(String versionId) async {
  final directory = await getApplicationDocumentsDirectory();
  final localDir = Directory('${directory.path}/bible/$versionId');
  if (!await localDir.exists()) {
    await localDir.create(recursive: true);
  }
  return localDir.path;
}

Future<bool> localBibleFileExists(String fileName, String versionId) async {
  final localDir = await getLocalBibleVersionDirectory(versionId);
  final file = File('$localDir/$fileName');
  return file.exists();
}

Future<String?> readLocalBibleFile(String fileName, String versionId) async {
  final localDir = await getLocalBibleVersionDirectory(versionId);
  final file = File('$localDir/$fileName');
  if (!await file.exists()) {
    return null;
  }
  return file.readAsString();
}

Future<void> writeLocalBibleFile(
    String fileName, String content, String versionId) async {
  final localDir = await getLocalBibleVersionDirectory(versionId);
  final file = File('$localDir/$fileName');
  await file.writeAsString(content, flush: true);
}

Future<void> deleteLocalBibleFile(String fileName, String versionId) async {
  final localDir = await getLocalBibleVersionDirectory(versionId);
  final file = File('$localDir/$fileName');
  if (await file.exists()) {
    await file.delete();
  }
}
