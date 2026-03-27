import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class MediaTile extends StatelessWidget {
  final AssetEntity? asset;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  const MediaTile({
    super.key,
    this.asset,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onOpen,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSelectionMode ? onSelect : onOpen,
      onLongPress: onSelect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Thumbnail(asset: asset),
          _SelectionOverlay(
            isSelected: isSelected,
            isSelectionMode: isSelectionMode,
            onOpen: onOpen,
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final AssetEntity? asset;

  const _Thumbnail({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.grey[400],
          child: asset != null
              ? Hero(
                  tag: asset!.id,
                  child: AssetEntityImage(
                    asset!,
                    thumbnailFormat: ThumbnailFormat.jpeg,
                    thumbnailSize: const ThumbnailSize(150, 150),
                    fit: BoxFit.cover,
                    isOriginal: false,
                    errorBuilder: (_, _, _) {
                      return Image.asset(
                        asset!.type == AssetType.image
                            ? 'assets/placeholder/image_thumbnail_placeholder.jpg'
                            : 'assets/placeholder/video_thumbnail_placeholder.jpg',
                      );
                    },
                  ),
                )
              : null,
        ),
        if (asset != null && asset!.type == AssetType.video)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: 4, bottom: 2, left: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Text(
                formatTime(asset!.duration),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        if (asset != null && asset!.isFavorite)
          Positioned(
            left: 2,
            top: 2,
            child: Icon(Icons.favorite, color: Colors.white, size: 18),
          ),
      ],
    );
  }

  String formatTime(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else {
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
  }
}

class _SelectionOverlay extends StatelessWidget {
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onOpen;

  const _SelectionOverlay({
    required this.isSelected,
    required this.isSelectionMode,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSelectionMode) return const SizedBox.shrink();

    return Container(
      color: isSelected ? Colors.white.withValues(alpha: 0.4) : null,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          isSelected
              ? Icon(Icons.check_box, color: Colors.white)
              : Icon(Icons.check_box_outline_blank, color: Colors.white),

          Material(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.open_in_full, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
