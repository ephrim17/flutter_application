import 'bible_filesystem_io.dart'
    if (dart.library.html) 'bible_filesystem_web.dart' as fs;

Future<bool> isLocalBibleStorageSupported() =>
    fs.isLocalBibleStorageSupported();
Future<String?> getLocalBibleVersionDirectory(String versionId) =>
    fs.getLocalBibleVersionDirectory(versionId);
Future<bool> localBibleFileExists(String fileName, String versionId) =>
    fs.localBibleFileExists(fileName, versionId);
Future<String?> readLocalBibleFile(String fileName, String versionId) =>
    fs.readLocalBibleFile(fileName, versionId);
Future<void> writeLocalBibleFile(
        String fileName, String content, String versionId) =>
    fs.writeLocalBibleFile(fileName, content, versionId);
Future<void> deleteLocalBibleFile(String fileName, String versionId) =>
    fs.deleteLocalBibleFile(fileName, versionId);
