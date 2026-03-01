import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/settings/app_settings.dart';
import '../models/private_asset_model.dart';
import '../services/media_service.dart';
import '../services/private_asset_service.dart';

class AlbumsController extends ChangeNotifier {
  final MediaService _mediaService;
  final PrivateAssetService _trashService;
  final AppSettings _settings;

  AlbumsController(this._mediaService, this._trashService, this._settings) {
    _settings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() async {
    final newValue = _settings.recycleBinEnabled;

    if (_showTrash == newValue) return;

    _showTrash = newValue;

    await _refreshAlbums();
    notifyListeners();
  }

  List<AssetPathEntity> albums = [];
  int trashCount = 0;
  bool _loading = false;
  bool get loading => _loading;
  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;
  bool _showTrash = false;
  bool get showTrash => _showTrash;

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    _permissionGranted = await _mediaService.requestPermission();
    if (!_permissionGranted) {
      _loading = false;
      notifyListeners();
      return;
    }

    _showTrash = _settings.recycleBinEnabled;

    await _refreshAlbums();

    _loading = false;
    notifyListeners();

    _mediaService.startListening(_onMediaChanged);
  }

  Future<void> _refreshAlbums() async {
    List<AssetPathEntity> physical = await _mediaService.fetchAlbums();
    AssetPathEntity? videos = await _mediaService.fetchVideoAlbum();
    AssetPathEntity? favorites = await _mediaService.fetchFavoritesAlbum();
    if (_showTrash) {
      trashCount = await _trashService.getCount(PrivateCategory.trash);
    }

    albums = [
      if (physical.isNotEmpty) physical.first,
      physical.where((album) => album.name == 'Camera').first,
      if (videos != null) videos,
      if (favorites != null) favorites,
      ...physical.skip(1).where((album) => album.name != 'Camera'),
    ];

    notifyListeners();
  }

  Future<void> _onMediaChanged(MethodCall _) async {
    await _refreshAlbums();
    notifyListeners();
  }

  Future<void> createAlbum(String name, [List<AssetEntity>? assets]) async {
    try {
      final String relativePath = 'Pictures/$name';
      final String absolutePath = '/storage/emulated/0/$relativePath';
      final directory = Directory(absolutePath);

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      if (assets != null && assets.isNotEmpty) {
        for (var asset in assets) {
          final originFile = await asset.originFile;
          if (originFile != null) {
            final bytes = await originFile.readAsBytes();
            await PhotoManager.editor.saveImage(
              bytes,
              filename:
                  asset.title ?? 'IMG_${DateTime.now().millisecondsSinceEpoch}',
              relativePath: relativePath,
            );
          }
        }
      } else {
        final Uint8List transparentPixel = Uint8List.fromList([
          ...[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00],
          ...[0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01],
          ...[0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F],
          ...[0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41],
          ...[0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00],
          ...[0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49],
          ...[0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82],
        ]);

        await PhotoManager.editor.saveImage(
          transparentPixel,
          filename: '.placeholder',
          relativePath: relativePath,
        );
      }
    } catch (e) {
      debugPrint("Error creating album: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _mediaService.stopListening(_onMediaChanged);
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
