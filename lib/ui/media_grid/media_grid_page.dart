import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import './../../core/operations/operation_controller.dart';
import './../../ui/private/password_entry_page.dart';
import '../../controllers/albums_controller.dart';
import '../../controllers/media_controller.dart';
import '../../core/operations/operation_dialog.dart';
import '../../core/settings/app_settings.dart';
import '../../dependency_injector.dart';
import '../../services/media_service.dart';
import '../../services/native_media_service.dart';
import '../../services/private_asset_service.dart';
import '../album/album_grid_page.dart';
import '../media_view/media_view_page.dart';
import 'media_tile.dart';

class MediaGridPage extends StatefulWidget {
  final AssetPathEntity album;

  const MediaGridPage({super.key, required this.album});

  @override
  State<MediaGridPage> createState() => _MediaGridPageState();
}

class _MediaGridPageState extends State<MediaGridPage> {
  late final MediaController controller;
  // final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = MediaController(
      sl<MediaService>(),
      sl<NativeMediaService>(),
      sl<PrivateAssetService>(),
      sl<AlbumsController>(),
      sl<AppSettings>(),
      widget.album,
    );
    controller.init();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        controller.selectedCount,
        controller.favoriteChanged,
      ]),
      builder: (contect, _) {
        return Scaffold(
          appBar: AppBar(
            leading: controller.isSelectionMode.value
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.clearSelection();
                    },
                  )
                : null,
            title: controller.isSelectionMode.value
                ? Text(
                    '${controller.selectedCount.value}/${controller.assetCount.value} selected',
                  )
                : Text(
                    '${controller.album.name} (${controller.assetCount.value})',
                  ),
            actions: [
              // enter selection mode button
              if (!controller.isSelectionMode.value)
                IconButton(
                  icon: const Icon(Icons.check_box),
                  onPressed: () {
                    controller.enterSelectionMode();
                  },
                ),
              // share button
              if (controller.isSelectionMode.value)
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    controller.shareSelected();
                  },
                ),
              // delete button
              if (controller.isSelectionMode.value)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _showDeleteDialog,
                ),
              // more options
              PopupMenuButton(
                itemBuilder: (context) => [
                  controller.areAllSelected
                      ? // deselect all
                        PopupMenuItem(
                          child: Text('Deselect All'),
                          onTap: () => controller.deselectAll(),
                        )
                      : // select all
                        PopupMenuItem(
                          child: Text('Select All'),
                          onTap: () => controller.selectAll(),
                        ),
                  // convert to pdf
                  if (!controller.isNoSelected)
                    PopupMenuItem(
                      onTap: _showGeneratePDFDialog,
                      child: Text('Generate PDF'),
                    ),
                  // copy to album
                  if (!controller.isNoSelected)
                    PopupMenuItem(
                      onTap: () async {
                        final album = await Navigator.push<AssetPathEntity>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AlbumGridPage(
                              mode: AlbumGridMode.pick,
                              title: 'Copy to album',
                            ),
                          ),
                        );
                        if (album != null) _showCopyToAlbumDialog(album);
                      },
                      child: Text('Copy to Album'),
                    ),
                  // move to album
                  if (!controller.isNoSelected)
                    PopupMenuItem(
                      child: Text('Move to Album'),
                      onTap: () async {
                        final album = await Navigator.push<AssetPathEntity>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AlbumGridPage(
                              mode: AlbumGridMode.pick,
                              title: 'Move to album',
                            ),
                          ),
                        );
                        if (album != null) _showMoveToAlbumDialog(album);
                      },
                    ),
                  // hide button
                  if (!controller.isNoSelected)
                    PopupMenuItem(onTap: _showHideDialog, child: Text('Hide')),
                ],
              ),
            ],
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: controller.assetCount.value,
            itemBuilder: (context, index) {
              return MediaTile(
                asset: controller.getAssetAt(index),
                isSelectionMode: controller.isSelectionMode.value,
                isSelected: controller.isSelectedAt(index),
                onSelect: () => controller.toggleSelectionAt(index),
                onOpen: () {
                  controller.setCurrentIndex = index;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MediaViewPage(controller: controller),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showGeneratePDFDialog() {
    final op = OperationController();
    final filenameController = TextEditingController();

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ValueListenableBuilder(
              valueListenable: op.status,
              builder: (_, status, __) {
                if (status == OperationStatus.idle) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Generate PDF from ${controller.selectedCount.value} item(s)?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: filenameController,
                        decoration: InputDecoration(
                          hintText: 'Enter filename (optional)',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () async {
                              op.start();
                              controller.convertSelectedToPDF(
                                filename: filenameController.text.trim(),
                                op: op,
                              );
                            },
                            child: Text('Generate'),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                if (status == OperationStatus.running) {
                  return StreamBuilder<OperationProgress>(
                    stream: op.progressStream,
                    builder: (_, snapshot) {
                      final progress = snapshot.data;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Processing..."),
                          const SizedBox(height: 20),
                          LinearProgressIndicator(
                            value: progress == null ? 0 : progress.percent,
                          ),
                          const SizedBox(height: 10),
                          if (progress != null)
                            Text("${progress.done}/${progress.total}"),
                        ],
                      );
                    },
                  );
                }

                if (status == OperationStatus.completed) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 50,
                      ),
                      const SizedBox(height: 10),
                      Text(op.resultMessage ?? "Completed"),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              op.dispose();
                            },
                            child: const Text("Close"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              op.dispose();
                              controller.sharePDF(op.resultMessage);
                            },
                            child: const Text("Share"),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 50),
                    const SizedBox(height: 10),
                    Text(op.errorMessage ?? "Operation failed"),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        op.dispose();
                      },
                      child: const Text("Close"),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCopyToAlbumDialog(AssetPathEntity album) {
    showOperationDialog(
      context: context,
      title: 'Copy ${controller.selectedCount.value} item(s) to ${album.name}?',
      confirmText: 'Copy',
      description: 'A copy of items will be saved to the new album.',
      onConfirm: (op) => controller.copySelectedToAlbum(album, op: op),
    );
  }

  void _showMoveToAlbumDialog(AssetPathEntity album) {
    showOperationDialog(
      context: context,
      title: 'Move ${controller.selectedCount.value} item(s) to ${album.name}?',
      confirmText: 'Move',
      description:
          'A copy of items will be saved to the new album and old one will be deleted.',
      onConfirm: (op) => controller.moveSelectedToAlbum(album, op: op),
    );
  }

  void _showHideDialog() {
    showOperationDialog(
      context: context,
      title: 'Hide ${controller.selectedCount.value} item(s)?',
      confirmText: 'Hide',
      description: 'These items can be seen from Settings > Hidden Album.',
      onConfirm: (op) async {
        final correctPassword = await controller.hasPassword()
            ? await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => PasswordEntryPage(
                    mode: PasswordEntryPageMode.checkPassword,
                  ),
                ),
              )
            : await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => PasswordEntryPage(
                    mode: PasswordEntryPageMode.setPassword,
                  ),
                ),
              );
        if (correctPassword == null) return;
        if (correctPassword) controller.hideSelected(op: op);
      },
    );
  }

  void _showDeleteDialog() {
    showOperationDialog(
      context: context,
      title: 'Delete ${controller.selectedCount.value} item(s)?',
      confirmText: 'Delete',
      description: controller.recycleBinEnabled
          ? 'The items will be visible in recycle bin.'
          : 'The items will be permanently removed from device.',
      onConfirm: (op) => controller.moveSelectedToTrash(op: op),
    );
  }
}
