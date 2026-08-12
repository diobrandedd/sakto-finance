import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

bool localFileExists(String? path) {
  if (path == null || path.isEmpty) return false;
  return File(path).existsSync();
}

ImageProvider? localFileImage(String path) => FileImage(File(path));

Future<String> copyPickedImageToDocuments(String sourcePath) async {
  final directory = await getApplicationDocumentsDirectory();
  final destination = File(
    '${directory.path}${Platform.pathSeparator}sakto_background.jpg',
  );
  await File(sourcePath).copy(destination.path);
  return destination.path;
}

Future<void> deleteLocalFile(String? path) async {
  if (path == null || path.isEmpty) return;
  final file = File(path);
  if (file.existsSync()) {
    await file.delete();
  }
}

Future<String> writeTextDocument(String fileName, String contents) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(contents, flush: true);
  return file.path;
}
