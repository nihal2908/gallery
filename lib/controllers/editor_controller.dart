// controllers/editor_controller.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

class EditorController extends ChangeNotifier {
  final AssetEntity asset;
  final bool isVideo;
  EditorController(this.asset, {this.isVideo = false});

  late final File file;
  bool processing = true;
  bool error = false;

  void init() async {
    await asset.file.then((value) {
      if (value != null) {
        file = value;
      } else {
        error = true;
      }
    });
    processing = false;
    notifyListeners();
  }

  Future<void> saveAndExit(Uint8List bytes) async {
    processing = true;
    notifyListeners();
    final filePathParts = file.path.split('.');
    final newPath =
        '${filePathParts.sublist(0, filePathParts.length - 1).join('.')}_edit.${filePathParts.last}';
    await PhotoManager.editor.saveImageWithPath(newPath);
    processing = false;
    notifyListeners();
  }
}
