Future<bool> isLocalBibleStorageSupported() async => false;

Future<String?> getLocalBibleVersionDirectory(String versionId) async => null;

Future<bool> localBibleFileExists(String fileName, String versionId) async {
  return false;
}

Future<String?> readLocalBibleFile(String fileName, String versionId) async {
  return null;
}

Future<void> writeLocalBibleFile(
    String fileName, String content, String versionId) async {
  throw UnsupportedError('Local Bible storage is not available on web.');
}

Future<void> deleteLocalBibleFile(String fileName, String versionId) async {
  throw UnsupportedError('Local Bible storage is not available on web.');
}
