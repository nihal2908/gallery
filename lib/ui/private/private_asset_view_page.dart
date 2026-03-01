import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gallery/models/private_asset_model.dart';
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
                    '${controller.currentIndex.value + 1}/${controller.itemCount}',
                  ),
            actions: [
              if (controller.category == PrivateCategory.trash &&
                  !controller.isSelectionMode.value)
                IconButton(
                  onPressed: () {
                    _showRestoreConfirmation();
                  },
                  icon: Icon(Icons.restore),
                ),
              if (controller.category == PrivateCategory.hidden &&
                  !controller.isSelectionMode.value)
                IconButton(
                  onPressed: () {
                    _showUnhideConfirmation();
                  },
                  icon: Icon(Icons.visibility),
                ),
              if (!controller.isSelectionMode.value)
                IconButton(
                  onPressed: () {
                    _showDeleteConfirmation();
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
                  itemCount: controller.itemCount,
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

  void _showDeleteConfirmation() {
    showDialog(
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

  void _showUnhideConfirmation() {
    showDialog(
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
            onPressed: () {
              controller.unhideCurrent();
              Navigator.pop(context);
            },
            child: Text('Unhide'),
          ),
        ],
      ),
    );
  }

  void _showRestoreConfirmation() {
    showDialog(
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
            onPressed: () {
              controller.restoreCurrent();
              Navigator.pop(context);
            },
            child: Text('Restore'),
          ),
        ],
      ),
    );
  }
}
