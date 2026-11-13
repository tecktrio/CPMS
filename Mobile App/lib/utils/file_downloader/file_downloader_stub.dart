import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<void> downloadFileBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  await Printing.sharePdf(bytes: bytes, filename: filename);
}
