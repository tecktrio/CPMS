import 'dart:typed_data';
import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart' as impl;

class FileDownloader {
  static Future<void> download({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    await impl.downloadFileBytes(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
  }
}

