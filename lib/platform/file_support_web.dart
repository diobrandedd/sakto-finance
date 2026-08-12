import 'package:flutter/widgets.dart';

bool localFileExists(String? path) => false;

ImageProvider? localFileImage(String path) => null;

Future<String> copyPickedImageToDocuments(String sourcePath) async {
  throw UnsupportedError(
    'Custom background photos are available on Android. Use the emulator or a phone to try this feature.',
  );
}

Future<void> deleteLocalFile(String? path) async {}

Future<String> writeTextDocument(String fileName, String contents) async {
  throw UnsupportedError(
    'JSON backup export is available on Android. Use the emulator or a phone for this feature.',
  );
}
