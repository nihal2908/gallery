import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../controllers/private_asset_controller.dart';

class PrivateAssetViewPage extends StatefulWidget {
  final PrivateAssetController controller;

  const PrivateAssetViewPage({super.key, required this.controller});

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
          appBar: AppBar(
            title: controller.isSelectionMode.value
                ? Text('${controller.selectedCount.value} selected')
                : Text(
                    '${controller.currentIndex.value + 1}/${controller.items.length}',
                  ),
            actions: [
              if (!controller.isSelectionMode.value)
                IconButton(
                  onPressed: () {
                    controller.restore([controller.currentItem]);
                  },
                  icon: Icon(Icons.restore),
                ),
              if (!controller.isSelectionMode.value)
                IconButton(
                  onPressed: () {
                    controller.permanentlyDelete([controller.currentItem]);
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
          body: Stack(
            alignment: AlignmentGeometry.center,
            children: [
              PhotoViewGestureDetectorScope(
                axis: Axis.horizontal,
                child: PageView.builder(
                  controller: PageController(initialPage: currentIndex),
                  onPageChanged: (i) {
                    controller.setCurrentIndex = i;
                  },
                  dragStartBehavior: DragStartBehavior.down,
                  pageSnapping: true,
                  itemCount: controller.items.length,
                  itemBuilder: (_, index) {
                    // final item = controller.items[index];
                    // return item.type == AssetMediaType.image
                    //     ? ImageViewer(asset: item)
                    //     : VideoViewer(asset: item);
                    return null;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void showDeleteConfirmationDialog(
    BuildContext context,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this Media?'),
          content: const Text(
            'The item will be deleted permanently from the device.',
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
                onConfirm();
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
