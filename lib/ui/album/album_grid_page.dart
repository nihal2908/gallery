import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../controllers/albums_controller.dart';
import '../../dependency_injector.dart';
import '../../models/private_asset_model.dart';
import '../media_grid/media_grid_page.dart';
import '../private/private_grid_page.dart';
import '../private/recycle_bin_tile.dart';
import '../settings/settings_page.dart';
import 'album_tile.dart';

enum AlbumGridMode {
  browse, // normal gallery
  pick, // select an album
}

class AlbumGridPage extends StatefulWidget {
  final AlbumGridMode mode;
  final ValueChanged<AssetPathEntity>? onAlbumPicked;
  final String? title;
  const AlbumGridPage({
    super.key,
    this.mode = AlbumGridMode.browse,
    this.onAlbumPicked,
    this.title,
  });

  @override
  State<AlbumGridPage> createState() => _AlbumGridPageState();
}

class _AlbumGridPageState extends State<AlbumGridPage> {
  final AlbumsController controller = sl<AlbumsController>();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    if (widget.mode == AlbumGridMode.browse) controller.init();
    super.initState();
  }

  void _showCreateAlbumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Album'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter album name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                controller.createAlbum(name);
                _nameController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ??
              (widget.mode == AlbumGridMode.pick ? 'Select Album' : 'Gallery'),
        ),
        actions: [
          IconButton(
            onPressed: _showCreateAlbumDialog,
            icon: Icon(Icons.add_to_photos),
          ),
          if (widget.mode == AlbumGridMode.browse)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
              icon: Icon(Icons.settings),
            ),
          SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (controller.loading) {
              return SizedBox.shrink();
            }
            return GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.75,
              ),
              itemCount:
                  widget.mode == AlbumGridMode.browse && controller.showTrash
                  ? controller.albums.length + 1
                  : controller.albums.length,
              itemBuilder: (context, index) {
                if (index == controller.albums.length) {
                  return TrashTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PrivateGridPage(category: PrivateCategory.trash),
                        ),
                      );
                    },
                    count: controller.trashCount,
                  );
                }
                return AlbumTile(
                  album: controller.albums[index],
                  onTap: () {
                    if (widget.mode == AlbumGridMode.pick) {
                      widget.onAlbumPicked?.call(controller.albums[index]);
                      Navigator.pop(context);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MediaGridPage(album: controller.albums[index]),
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
