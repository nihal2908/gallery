import 'package:photo_manager/photo_manager.dart';

enum AssetMediaType { image, video }

enum PrivateCategory { trash, hidden }

class PrivateAsset {
  final String id;
  final String title;
  final String? relativePath;
  final AssetMediaType type;
  final PrivateCategory category;
  final int width;
  final int height;
  final int orientation;
  final double? latitude;
  final double? longitude;
  final int? duration;
  final DateTime createdAt;
  final DateTime processedAt;

  PrivateAsset({
    required this.id,
    required this.title,
    required this.relativePath,
    required this.type,
    required this.category,
    required this.width,
    required this.height,
    required this.orientation,
    required this.latitude,
    required this.longitude,
    this.duration,
    required this.createdAt,
    required this.processedAt,
  });

  // Convert SQL Map to TrashItem Object
  factory PrivateAsset.fromMap(Map<String, dynamic> map) {
    return PrivateAsset(
      id: map['id'],
      title: map['title'],
      relativePath: map['relative_path'],
      type: map['type'] == 'image'
          ? AssetMediaType.image
          : AssetMediaType.video,
      category: map['category'] == 'trash'
          ? PrivateCategory.trash
          : PrivateCategory.hidden,
      width: map['width'],
      height: map['height'],
      orientation: map['orientation'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      duration: map['duration'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      processedAt: DateTime.fromMillisecondsSinceEpoch(map['processed_at']),
    );
  }

  factory PrivateAsset.fromAssetEntity(
    AssetEntity asset,
    PrivateCategory category,
  ) {
    return PrivateAsset(
      id: asset.id,
      title: asset.title ?? 'Unknown',
      relativePath: asset.relativePath,
      type: asset.type == AssetType.image
          ? AssetMediaType.image
          : AssetMediaType.video,
      category: category,
      width: asset.width,
      height: asset.height,
      orientation: asset.orientation,
      latitude: asset.latitude,
      longitude: asset.longitude,
      duration: asset.duration,
      createdAt: asset.createDateTime,
      processedAt: DateTime.now(),
    );
  }

  // Convert TrashItem Object to SQL Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'relative_path': relativePath,
      'type': type == AssetMediaType.image ? 'image' : 'video',
      'category': category.name,
      'width': width,
      'height': height,
      'orientation': orientation,
      'latitude': latitude,
      'longitude': longitude,
      'duration': duration,
      'created_at': createdAt.millisecondsSinceEpoch,
      'processed_at': processedAt.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrivateAsset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
