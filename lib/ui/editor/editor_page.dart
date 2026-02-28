import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../controllers/editor_controller.dart';

class EditorHomePage extends StatefulWidget {
  final AssetEntity asset;
  final bool isVideo;
  const EditorHomePage({super.key, required this.asset, this.isVideo = false});

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  late final EditorController controller;

  @override
  void initState() {
    controller = EditorController(widget.asset);
    controller.init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          body: (controller.processing)
              ? const Center(child: CircularProgressIndicator())
              : (controller.error)
              ? const Center(child: Text("Error loading image."))
              : (!controller.processing && !controller.error)
              ? ProImageEditor.file(
                  controller.file,
                  callbacks: ProImageEditorCallbacks(
                    onCloseEditor: (editorMode) {
                      showDiscardChangesDialog(context);
                    },
                    onImageEditingComplete: (bytes) async {
                      controller.saveAndExit(bytes);
                    },
                  ),
                )
              : const Center(child: Text("Error loading image.")),
        );
      },
    );
  }

  void showDiscardChangesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Discard Changes?"),
          content: const Text("Are you sure you want to discard your changes?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Discard"),
            ),
          ],
        );
      },
    );
  }
}
