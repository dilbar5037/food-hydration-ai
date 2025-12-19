import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class ImageCaptureResult {
  ImageCaptureResult({
    required this.path,
    this.file,
    this.bytes,
  });

  final String path;
  final File? file;
  final Uint8List? bytes;

  int? get byteLength => bytes?.lengthInBytes;
}

class ImageCaptureService {
  ImageCaptureService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<ImageCaptureResult?> captureFromCamera() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera);
    if (xfile == null) {
      return null;
    }

    final bytes = await xfile.readAsBytes();
    return ImageCaptureResult(
      path: xfile.path,
      file: File(xfile.path),
      bytes: bytes,
    );
  }
}
