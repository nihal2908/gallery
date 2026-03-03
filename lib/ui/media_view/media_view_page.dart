import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';

import '../../controllers/media_controller.dart';
import '../album/album_grid_page.dart';
import '../editor/editor_page.dart';
import '../private/password_entry_page.dart';
import 'image_viewer.dart';
import 'video_viewer.dart';

class MediaViewPage extends StatefulWidget {
  final MediaController controller;

  const MediaViewPage({super.key, required this.controller});

  @override
  State<MediaViewPage> createState() => _MediaViewPageState();
}

class _MediaViewPageState extends State<MediaViewPage> {
  late final MediaController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) {
        final currentIndex = controller.currentIndex.value;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            alignment: AlignmentGeometry.center,
            children: [
              GestureDetector(
                onTap: () {
                  controller.toggleControls();
                },
                child: PhotoViewGestureDetectorScope(
                  axis: Axis.horizontal,
                  child: PageView.builder(
                    controller: PageController(initialPage: currentIndex),
                    onPageChanged: (i) {
                      controller.setCurrentIndex = i;
                    },
                    dragStartBehavior: DragStartBehavior.down,
                    pageSnapping: true,
                    // allowImplicitScrolling: true,
                    itemCount: controller.assetCount.value,
                    itemBuilder: (_, index) {
                      final asset = controller.getAssetAt(index);
                      if (asset == null) return SizedBox.shrink();
                      return asset.type == AssetType.image
                          ? ImageViewer(asset: asset)
                          : VideoViewer(asset: asset);
                    },
                  ),
                ),
              ),
              _TopBar(controller: controller),
              _BottomBar(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final MediaController controller;
  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.showControls,
        controller.currentIndex,
        controller.selectedCount,
        controller.favoriteChanged,
      ]),
      builder: (_, __) {
        return controller.showControls.value
            ? Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: AppBar(
                  title: controller.isSelectionMode.value
                      ? Text('${controller.selectedCount.value} selected')
                      : Text(
                          '${controller.currentIndex.value + 1}/${controller.assetCount.value}',
                        ),
                  actions: [
                    if (!controller.isSelectionMode.value)
                      IconButton(
                        icon:
                            (controller.currentAsset != null
                                ? controller.currentAsset!.isFavorite
                                : false)
                            ? Icon(Icons.favorite, color: Colors.red)
                            : Icon(Icons.favorite_border),
                        onPressed: () {
                          controller.toggleFavorite();
                        },
                      ),
                    if (!controller.isSelectionMode.value)
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: controller.currentAsset != null
                            ? () {
                                showInfoDialog(
                                  context,
                                  controller.currentAsset!,
                                );
                              }
                            : null,
                      ),
                    if (controller.isSelectionMode.value)
                      IconButton(
                        onPressed: () {
                          controller.toggleSelectionAt(
                            controller.currentIndex.value,
                          );
                        },
                        icon:
                            controller.isSelectedAt(
                              controller.currentIndex.value,
                            )
                            ? Icon(Icons.check_box)
                            : Icon(Icons.check_box_outline_blank),
                      ),
                  ],
                ),
              )
            : SizedBox.shrink();
      },
    );
  }

  void showInfoDialog(BuildContext context, AssetEntity currentAsset) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(currentAsset.title ?? 'Info'),
          icon: const Icon(Icons.info),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: ${currentAsset.type.name}'),
              Text('Dimension: ${currentAsset.height} x ${currentAsset.width}'),
              if (currentAsset.type == AssetType.video)
                Text('Duration: ${currentAsset.videoDuration} seconds'),
              Text('Create Date: ${currentAsset.createDateTime}'),
              Text('Modified Date: ${currentAsset.modifiedDateTime}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  final MediaController controller;
  const _BottomBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.showControls,
      builder: (_, showControls, __) {
        return showControls
            ? Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.grey[200],
                  height: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.share),
                        onPressed: () {
                          // controller.shareCurrent();
                        },
                        color: Colors.black,
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EditorHomePage(
                                asset: controller.currentAsset!,
                                isVideo:
                                    controller.currentAsset!.type ==
                                    AssetType.video,
                              ),
                            ),
                          );
                        },
                        color: Colors.black,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          _showDeleteDialog(context);
                        },
                        color: Colors.black,
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) {
                          return [
                            PopupMenuItem(
                              onTap: controller.setCurrentAsWallpaper,
                              child: Text('Set as Wallpaper'),
                            ),
                            PopupMenuItem(
                              onTap: () async {
                                final album =
                                    await Navigator.push<AssetPathEntity>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AlbumGridPage(
                                          mode: AlbumGridMode.pick,
                                          title: 'Copy to album',
                                        ),
                                      ),
                                    );
                                if (album != null) {
                                  controller.copyCurrentToAlbum(album);
                                }
                              },
                              child: Text('Copy to Album'),
                            ),
                            PopupMenuItem(
                              onTap: () async {
                                final album =
                                    await Navigator.push<AssetPathEntity>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AlbumGridPage(
                                          mode: AlbumGridMode.pick,
                                          title: 'Move to album',
                                        ),
                                      ),
                                    );
                                if (album != null) {
                                  controller.moveCurrentToAlbum(album);
                                }
                              },
                              child: Text('Move to Album'),
                            ),
                            PopupMenuItem(
                              child: Text('Hide'),
                              onTap: () async {
                                if (await controller.hasPassword()) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PasswordEntryPage(
                                        mode:
                                            PasswordEntryPageMode.checkPassword,
                                      ),
                                    ),
                                  ).then((value) async {
                                    if (!value) return;
                                    await controller.hideCurrent();
                                  });
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PasswordEntryPage(
                                        mode: PasswordEntryPageMode.setPassword,
                                      ),
                                    ),
                                  ).then((value) async {
                                    if (!value) return;
                                    await controller.hideCurrent();
                                  });
                                }
                              },
                            ),
                            const PopupMenuItem(child: Text('Rename')),
                          ];
                        },
                        icon: Icon(Icons.more_vert),
                      ),
                    ],
                  ),
                ),
              )
            : SizedBox.shrink();
      },
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this item?'),
          content: controller.recycleBinEnabled
              ? const Text('The item will be visible in recycle bin.')
              : const Text(
                  'The item will be permanently removed from the device.',
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
                controller.moveCurrentToTrash();
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
