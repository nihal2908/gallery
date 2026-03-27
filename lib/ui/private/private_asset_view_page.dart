import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

import '../../controllers/private_asset_controller.dart';
import '../../models/private_asset_model.dart';

class PrivateAssetViewPage extends StatefulWidget {
  final Uint8List? thumbnail;
  final PrivateAssetController controller;

  const PrivateAssetViewPage({
    super.key,
    required this.thumbnail,
    required this.controller,
  });

  @override
  State<PrivateAssetViewPage> createState() => _PrivateAssetViewPageState();
}

class _PrivateAssetViewPageState extends State<PrivateAssetViewPage> {
  late final PrivateAssetController controller;

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
                    itemCount: controller.itemCount,
                    itemBuilder: (_, index) {
                      final item = controller.item(index);
                      return item.type == AssetMediaType.image
                          ? _ImageViewer(
                              controller: controller,
                              item: item,
                              thumbnail: widget.thumbnail,
                            )
                          : _VideoViewer(
                              controller: controller,
                              item: item,
                              thumbnail: widget.thumbnail,
                            );
                    },
                  ),
                ),
              ),
              _TopBar(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final PrivateAssetController controller;
  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.showControls,
        controller.currentIndex,
        controller.selectedCount,
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
                          '${controller.currentIndex.value + 1}/${controller.itemCount}',
                        ),
                  actions: [
                    if (controller.category == PrivateCategory.trash &&
                        !controller.isSelectionMode.value)
                      IconButton(
                        onPressed: () {
                          _showRestoreConfirmation(context);
                        },
                        icon: Icon(Icons.restore),
                      ),
                    if (controller.category == PrivateCategory.hidden &&
                        !controller.isSelectionMode.value)
                      IconButton(
                        onPressed: () {
                          _showUnhideConfirmation(context);
                        },
                        icon: Icon(Icons.visibility),
                      ),
                    if (!controller.isSelectionMode.value)
                      IconButton(
                        onPressed: () {
                          _showDeleteConfirmation(context);
                        },
                        icon: Icon(Icons.delete),
                      ),

                    if (controller.isSelectionMode.value)
                      IconButton(
                        onPressed: () {
                          controller.toggleSelection(controller.currentItem);
                        },
                        icon: controller.isSelected(controller.currentItem)
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

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete item?'),
        content: Text('The item will be permanently removed from the device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.permanentlyDeleteCurrent();
              Navigator.pop(context);
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showUnhideConfirmation(BuildContext context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unhide this item?'),
        content: Text('The item will be moved to Pictures/Unhidden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await controller.unhideCurrent();
              Navigator.pop(context);
            },
            child: Text('Unhide'),
          ),
        ],
      ),
    );
  }

  void _showRestoreConfirmation(BuildContext context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore this item?'),
        content: Text('The item will be moved to Pictures/Restored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await controller.restoreCurrent();
              Navigator.pop(context);
            },
            child: Text('Restore'),
          ),
        ],
      ),
    );
  }
}

class _ImageViewer extends StatefulWidget {
  final PrivateAssetController controller;
  final PrivateAsset item;
  final Uint8List? thumbnail;

  const _ImageViewer({
    required this.item,
    this.thumbnail,
    required this.controller,
  });

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  Uint8List? _imageBytes;

  @override
  void initState() {
    _loadImage();
    super.initState();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.controller.getCompleteImage(widget.item);
    setState(() {
      _imageBytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PhotoView.customChild(
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 5,
      child: _imageBytes != null
          ? Image.memory(_imageBytes!, fit: BoxFit.contain)
          : Image.memory(widget.thumbnail!, fit: BoxFit.cover),
    );
  }
}

class _VideoViewer extends StatefulWidget {
  final PrivateAssetController controller;
  final PrivateAsset item;
  final Uint8List? thumbnail;

  const _VideoViewer({
    required this.item,
    this.thumbnail,
    required this.controller,
  });

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Uint8List? _preview;
  bool _error = false;

  Future<void> _loadPreview() async {
    _preview = await widget.controller.getVideoPreview(widget.item);
    setState(() {});
  }

  Future<void> _loadVideo() async {
    try {
      final file = await widget.controller.getCompleteVideoFile(widget.item);
      if (file == null) {
        setState(() {
          _error = true;
        });
        return;
      }
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        looping: true,
        allowFullScreen: false,
        allowPlaybackSpeedChanging: true,
        zoomAndPan: true,
      );

      setState(() {});
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      setState(() {
        _error = true;
      });
    }
  }

  @override
  void initState() {
    _loadPreview();
    _loadVideo();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: _chewieController != null
            ? Chewie(controller: _chewieController!)
            : Stack(
                alignment: Alignment.center,
                children: [
                  Image.memory(
                    _preview ?? widget.thumbnail!,
                    fit: BoxFit.cover,
                  ),
                  _error
                      ? Icon(Icons.warning_rounded, color: Colors.red, size: 50)
                      : CircularProgressIndicator(color: Colors.white),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }
}
