import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewer extends StatelessWidget {
  final AssetEntity asset;

  const ImageViewer({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Aspect ratio calculation for the thumbnail
    final thumbnailSize = asset.height > asset.width
        ? ThumbnailSize(
            screenWidth.toInt(),
            (screenWidth * asset.height / asset.width).toInt(),
          )
        : ThumbnailSize(
            (screenWidth * asset.width / asset.height).toInt(),
            screenWidth.toInt(),
          );

    return PhotoView.customChild(
      heroAttributes: PhotoViewHeroAttributes(tag: asset.id),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 5,
      // We wrap the layers in a Stack so they zoom together
      child: Stack(
        alignment: Alignment.center,
        children: [
          // LAYER 1: The Zoomable Thumbnail (Instantly ready)
          AssetEntityImage(
            asset,
            thumbnailFormat: ThumbnailFormat.jpeg,
            thumbnailSize: thumbnailSize,
            fit: BoxFit.contain,
            isOriginal: false,
          ),

          // LAYER 2: The Original Image (Fades in over thumbnail)
          Image(
            image: AssetEntityImageProvider(asset, isOriginal: true),
            fit: BoxFit.contain,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: child,
              );
            },
          ),
        ],
      ),
    );
  }
}
