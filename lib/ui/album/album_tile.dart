import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class AlbumTile extends StatelessWidget {
  final AssetPathEntity album;
  final VoidCallback onTap;

  const AlbumTile({super.key, required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                12,
              ),
              child: Container(
                color: Colors.grey[300],
                child: FutureBuilder<List<AssetEntity>>(
                  future: album.getAssetListRange(start: 0, end: 1),
                  builder: (context, snapshot) {
                    final asset = snapshot.data?.isNotEmpty == true
                        ? snapshot.data!.first
                        : null;

                    if (asset == null) {
                      return const Icon(
                        Icons.photo_library,
                        color: Colors.grey,
                      );
                    }

                    return AssetEntityImage(
                      asset,
                    thumbnailFormat: ThumbnailFormat.jpeg,
                      thumbnailSize: const ThumbnailSize(300, 300),
                      fit: BoxFit.cover,
                      isOriginal: false,
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            album.name,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),

          FutureBuilder<int>(
            future: album.assetCountAsync,
            builder: (context, countSnapshot) {
              return Text(
                "${countSnapshot.data ?? 0} items",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }
}
