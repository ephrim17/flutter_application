import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';

Future<bool> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  return downloadBytesImpl(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
  );
}
