import 'package:flutter/material.dart';

import '../../controllers/private_asset_controller.dart';
import '../../core/operations/operation_dialog.dart';
import '../../dependency_injector.dart';
import '../../models/private_asset_model.dart';
import '../../services/authentication_service.dart';
import '../../services/private_asset_service.dart';
import 'private_asset_tile.dart';
import 'private_asset_view_page.dart';

class PrivateGridPage extends StatefulWidget {
  final PrivateCategory category;
  const PrivateGridPage({super.key, required this.category});

  @override
  State<PrivateGridPage> createState() => _PrivateGridPageState();
}

class _PrivateGridPageState extends State<PrivateGridPage> {
  late final PrivateAssetController controller;

  @override
  void initState() {
    controller = PrivateAssetController(
      sl<PrivateAssetService>(),
      sl<AuthenticationService>(),
      widget.category,
    );
    controller.init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        controller.isSelectionMode,
        controller.selectedCount,
      ]),
      builder: (_, __) {
        return PopScope(
          canPop: !controller.isSelectionMode.value,
          onPopInvokedWithResult: (didPop, _) => controller.clearSelections(),
          child: Scaffold(
            appBar: AppBar(
              leading: controller.isSelectionMode.value
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controller.clearSelections();
                      },
                    )
                  : null,
              title: controller.isSelectionMode.value
                  ? Text(
                      '${controller.selectedCount.value}/${controller.itemCount} selected',
                    )
                  : widget.category == PrivateCategory.trash
                  ? Text('Recycle Bin (${controller.itemCount})')
                  : Text('Hidden (${controller.itemCount})'),
              actions: [
                if (!controller.isSelectionMode.value)
                  IconButton(
                    icon: const Icon(Icons.check_box),
                    onPressed: () {
                      controller.enterSelectionMode();
                    },
                  ),
                if (widget.category == PrivateCategory.trash &&
                    controller.hasSelection)
                  IconButton(
                    icon: const Icon(Icons.restore),
                    onPressed: () {
                      _showRestoreConfirmation();
                    },
                  ),
                if (widget.category == PrivateCategory.hidden &&
                    controller.hasSelection)
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () {
                      _showUnhideConfirmation();
                    },
                  ),
                if (controller.hasSelection)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      _showDeleteConfirmation();
                    },
                  ),
                if (controller.isSelectionMode.value &&
                    controller.areAllSelected)
                  IconButton(
                    icon: const Icon(Icons.check_box_outline_blank),
                    onPressed: () {
                      controller.deselectAll();
                    },
                  ),
                if (controller.isSelectionMode.value &&
                    !controller.areAllSelected)
                  IconButton(
                    icon: const Icon(Icons.check_box),
                    onPressed: () {
                      controller.selectAll();
                    },
                  ),
              ],
            ),

            body: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: controller.itemCount,
              itemBuilder: (_, index) {
                final item = controller.item(index);
                final thumbnail = controller.getThumbnailAt(index);
                return PrivateAssetTile(
                  item: item,
                  thumbnail: thumbnail,
                  isSelected: controller.selectedItems.contains(item),
                  isSelectionMode: controller.isSelectionMode.value,
                  onOpen: () {
                    if (controller.isSelectionMode.value) {
                      controller.toggleSelection(item);
                    } else {
                      controller.setCurrentIndex = index;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrivateAssetViewPage(
                            thumbnail: thumbnail,
                            controller: controller,
                          ),
                        ),
                      );
                    }
                  },
                  onSelect: () => controller.toggleSelection(item),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    showOperationDialog(
      context: context,
      title: 'Delete ${controller.selectedCount.value} item(s)?',
      confirmText: 'Delete',
      description: 'These items will be permanently removed from the device.',
      onConfirm: (op) => controller.permanentlyDeleteSelected(op: op),
    );
  }

  void _showUnhideConfirmation() {
    showOperationDialog(
      context: context,
      title: 'Unhide ${controller.selectedCount.value} item(s)?',
      confirmText: 'Unhide',
      description: 'These items will be moved to Pictures/Unhidden.',
      onConfirm: (op) => controller.unhideSelected(op: op),
    );
  }

  void _showRestoreConfirmation() {
    showOperationDialog(
      context: context,
      title: 'Restore ${controller.selectedCount.value} item(s)?',
      confirmText: 'Restore',
      description: 'These items will be moved to Pictures/Restored.',
      onConfirm: (op) => controller.restoreSelected(op: op),
    );
  }
}
