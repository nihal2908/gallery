import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:photo_manager/photo_manager.dart';

import './../core/operations/operation_controller.dart';

class MediaService {
  Future<bool> requestPermission() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      await PhotoManager.openSetting();
    }
    return ps.isAuth || ps.hasAccess;
  }

  Future<List<AssetPathEntity>> fetchAlbums() async {
    return await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      filterOption: PMFilter.defaultValue(),
    );
  }

  Future<AssetPathEntity?> fetchVideoAlbum() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
      onlyAll: true,
      filterOption: PMFilter.defaultValue(),
    );
    return albums.isNotEmpty ? albums.first.copyWith(name: 'Videos') : null;
  }

  Future<AssetPathEntity?> fetchFavoritesAlbum() async {
    final favoriteFilter = CustomFilter.sql(
      where: "is_favorite = 1",
      orderBy: [OrderByItem(CustomColumns.android.generationAdded, false)],
    );
    List<AssetPathEntity> albums = [];
    try {
      albums = await PhotoManager.getAssetPathList(
        filterOption: favoriteFilter,
      );
    } catch (error) {
      if (kDebugMode) {
        print(error.toString());
      }
    }

    return albums.isNotEmpty ? albums.first.copyWith(name: 'Favorites') : null;
  }

  Future<List<AssetEntity>> fetchAssets(
    AssetPathEntity album, {
    required int page,
    required int size,
  }) async {
    return await album.getAssetListPaged(page: page, size: size);
  }

  Future<File?> assetsToPdf(
    List<AssetEntity> assets, {
    String? fileName,
    bool keepOriginal = false,
    int quality = 1088,
    OperationController? op,
  }) async {
    if (op != null) op.status.value = OperationStatus.running;
    int done = 0;
    int total = assets.length;

    if (fileName == null || fileName.isEmpty) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      fileName = 'DOC_$timestamp';
    }
    fileName = "$fileName.pdf";

    final pdf = pw.Document();

    for (final asset in assets) {
      if (asset.type == AssetType.video) {
        done++;
        if (op != null) op.updateProgress(done, total);
        continue;
      }
      try {
        final Uint8List? bytes = keepOriginal
            ? await asset.originBytes
            : await asset.thumbnailDataWithSize(
                ThumbnailSize(quality, quality),
              );

        if (bytes == null) continue;

        final image = pw.MemoryImage(bytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              );
            },
          ),
        );
      } catch (e) {
        continue;
      } finally {
        done++;
        if (op != null) op.updateProgress(done, total);
      }
    }

    final dir = await path_provider.getDownloadsDirectory();
    if (dir == null) {
      return null;
    }
    if (dir.existsSync() == false) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/$fileName');

    await file.writeAsBytes(await pdf.save());

    if (op != null) op.resultMessage = file.path;
    if (op != null) op.status.value = OperationStatus.completed;
    return file;
  }

  final Set<void Function(MethodCall)> _callbacks = {};

  void startListening(void Function(MethodCall) callback) {
    if (_callbacks.isEmpty) {
      PhotoManager.startChangeNotify();
    }

    _callbacks.add(callback);
    PhotoManager.addChangeCallback(callback);
  }

  void stopListening(void Function(MethodCall) callback) {
    if (!_callbacks.contains(callback)) return;

    PhotoManager.removeChangeCallback(callback);
    _callbacks.remove(callback);

    if (_callbacks.isEmpty) {
      PhotoManager.stopChangeNotify();
    }
  }

  void stopAll() {
    for (final cb in _callbacks) {
      PhotoManager.removeChangeCallback(cb);
    }

    _callbacks.clear();
    PhotoManager.stopChangeNotify();
  }
}
