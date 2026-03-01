import 'package:flutter/material.dart';
import 'package:gallery/ui/private/password_entry_page.dart';
import 'package:photo_manager/photo_manager.dart';

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
                  onPressed: () {
                    _showDeleteDialog(context);
                  },
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
                      child: Text('Generate PDF'),
                      onTap: () async {
                        controller.convertSelectedToPDF().then(
                          (value) => _showPDFResultDialog(context, value),
                        );
                      },
                    ),
                  // copy to album
                  if (!controller.isNoSelected)
                    PopupMenuItem(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AlbumGridPage(
                            mode: AlbumGridMode.pick,
                            title: 'Copy to album',
                            onAlbumPicked: (album) => _showCopyToAlbumDialog(album),
                          ),
                        ),
                      ),
                      child: Text('Copy to Album'),
                    ),
                  // move to album
                  if (!controller.isNoSelected)
                    PopupMenuItem(
                      child: Text('Move to Album'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AlbumGridPage(
                            mode: AlbumGridMode.pick,
                            title: 'Move to album',
                            onAlbumPicked: (album) => _showMoveToAlbumDialog(album),
                          ),
                        ),
                      ),
                    ),
                  // hide button
                  if (!controller.isNoSelected)
                    PopupMenuItem(
                      onTap: _showHideDialog,
                      child: Text('Hide'),
                    ),
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

  void _showPDFResultDialog(BuildContext context, (bool, String?) result) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: result.$1
              ? const Text('PDF created successfully!')
              : const Text('PDF creation failed!'),
          content: result.$1
              ? Text('The file is saved at "${result.$2}".')
              : const Text("Please try again later"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: result.$1
                  ? () {
                      Navigator.of(context).pop();
                      controller.sharePDF(result.$2);
                    }
                  : null,
              child: const Text('Share'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete selected items?'),
          content: controller.recycleBinEnabled
              ? Text('The items will be visible in recycle bin.')
              : const Text(
                  "The items will be permanently removed from device.",
                ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                controller.moveSelectedToTrash();
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showCopyToAlbumDialog(AssetPathEntity album) {

  }

  void _showMoveToAlbumDialog(AssetPathEntity album) {

  }
  void _showHideDialog() {
    showOperationDialog(
      context: context,
      title: 'Hide ${controller.selectedCount.value} item(s)?',
      confirmText: 'Hide',
      description: 'These items can be seen from Settings > Hidden Album.',
      onConfirm: (op) => controller.hideSelected(op: op),
    );
  }
  void _showMoveToTrashDialog() {

  }
}
