import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PickedImageData {
  const PickedImageData({
    required this.bytes,
    required this.name,
  });

  final Uint8List bytes;
  final String name;

  static Future<PickedImageData?> fromXFile(XFile? file) async {
    if (file == null) return null;

    return PickedImageData(
      bytes: await file.readAsBytes(),
      name: file.name,
    );
  }
}
