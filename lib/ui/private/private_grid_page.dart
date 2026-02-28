import 'package:flutter/material.dart';
import 'package:gallery/services/authentication_service.dart';

import '../../controllers/private_asset_controller.dart';
import '../../dependency_injector.dart';
import '../../models/private_asset_model.dart';
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
    widget.category == PrivateCategory.trash
        ? controller.loadTrash()
        : controller.loadHidden();
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
        return Scaffold(
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
                    '${controller.selectedCount.value}/${controller.items.length} selected',
                  )
                : widget.category == PrivateCategory.trash ? Text('Recycle Bin (${controller.items.length})') : Text('Hidden (${controller.items.length})'),
            actions: [
              if (!controller.isSelectionMode.value)
                IconButton(
                  icon: const Icon(Icons.check_box),
                  onPressed: () {
                    controller.enterSelectionMode();
                  },
                ),
              if (widget.category == PrivateCategory.trash && controller.hasSelection)
                IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: () {
                    controller.restoreSelected();
                  },
                ),
                if (widget.category == PrivateCategory.hidden && controller.hasSelection)
                IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    controller.unhideSelected();
                  },
                ),
              if (controller.hasSelection)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    controller.permanentlyDeleteSelected();
                  },
                ),
              if (controller.isSelectionMode.value && controller.areAllSelected)
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
            itemCount: controller.items.length,
            itemBuilder: (_, index) {
              final item = controller.items[index];
              return PrivateAssetTile(
                asset: item,
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
                        builder: (context) =>
                            PrivateAssetViewPage(controller: controller),
                      ),
                    );
                  }
                },
                onSelect: () => controller.toggleSelection(item),
              );
            },
          ),
        );
      },
    );
  }
}
