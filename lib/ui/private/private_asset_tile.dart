import 'package:flutter/material.dart';
import 'package:gallery/models/private_asset_model.dart';

class PrivateAssetTile extends StatelessWidget {
  final PrivateAsset asset;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  const PrivateAssetTile({
    super.key,
    required this.asset,
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
          _Thumbnail(item: asset),
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
  final PrivateAsset item;

  const _Thumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.grey[400],
          // child: Hero(
          //         tag: item.id,
          //         child: Image.memory(
          //         ),
          //       )
        ),
        if (item.type == AssetMediaType.video)
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
                formatTime(item.duration!),
                style: TextStyle(color: Colors.white),
              ),
            ),
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
