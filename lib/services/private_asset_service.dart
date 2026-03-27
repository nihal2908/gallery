import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pointycastle/export.dart';
import 'package:sqflite/sqflite.dart';

import '../core/operations/operation_controller.dart';
import '../core/settings/app_settings.dart';
import '../models/private_asset_model.dart';
import '../services/native_crypto_service.dart';
import 'authentication_service.dart';

class PrivateAssetService {
  final AppSettings _appSettings;
  final AuthenticationService _authService;
  PrivateAssetService(this._appSettings, this._authService);

  late Database _db;
  String? _cachedTrashPath;
  String? _cachedHiddenPath;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'trash.db'),
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE private_assets(
          id TEXT PRIMARY KEY, title TEXT, relative_path TEXT,
          type TEXT, category TEXT, width INTEGER, height INTEGER, longitude REAL, 
          latitude REAL, orientation INTEGER, duration INTEGER, 
          created_at INTEGER, processed_at INTEGER
        )
      '''),
    );

    _cleanupExpiredTrash();
  }

  Future<void> _cleanupExpiredTrash() async {
    final trashLifeDays = _appSettings.trashLifeDays;

    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryMillis = trashLifeDays * 24 * 60 * 60 * 1000;
    final cutoff = now - expiryMillis;

    final expired = await _db.query(
      'private_assets',
      where: 'category = ? AND processed_at < ?',
      whereArgs: [PrivateCategory.trash.name, cutoff],
    );

    if (expired.isEmpty) return;

    await _db.delete(
      'private_assets',
      where: 'category = ? AND processed_at < ?',
      whereArgs: [PrivateCategory.trash.name, cutoff],
    );

    final expiredAssets = expired.map((e) => PrivateAsset.fromMap(e)).toList();
    for (final item in expiredAssets) {
      await _cleanupPrivateFiles(item);
    }
  }

  Future<int> getCount(PrivateCategory category) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) FROM private_assets WHERE category = ?',
      [category.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<String> _getTrashPath() async {
    if (_cachedTrashPath != null) return _cachedTrashPath!;
    final directory = await getApplicationDocumentsDirectory();
    _cachedTrashPath = p.join(directory.path, 'trash_bin');
    await Directory(_cachedTrashPath!).create(recursive: true);
    return _cachedTrashPath!;
  }

  Future<String> _getHiddenPath() async {
    if (_cachedHiddenPath != null) return _cachedHiddenPath!;
    final directory = await getApplicationDocumentsDirectory();
    _cachedHiddenPath = p.join(directory.path, 'hidden');
    await Directory(_cachedHiddenPath!).create(recursive: true);
    return _cachedHiddenPath!;
  }

  Future<bool> hasPassword() async {
    return await _authService.hasPassword();
  }

  Future<void> moveToTrash(
    List<AssetEntity> assets, {
    OperationController? op,
  }) async {
    List<String> assetIdsToDelete = [];

    if (op != null) op.status.value = OperationStatus.running;
    int total = assets.length;
    int done = 0;

    for (final asset in assets) {
      final file = await asset.originFile;
      if (file == null) return;

      final result = await Future.wait([
        _saveThumbnail(asset),
        _saveAsset(asset),
      ]);
      if (result.contains(false)) {
        done++;
        if (op != null) op.updateProgress(done, total);
        continue;
      }

      final item = PrivateAsset.fromAssetEntity(asset, PrivateCategory.trash);

      await _db.insert(
        'private_assets',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      assetIdsToDelete.add(asset.id);

      done++;
      if (op != null) op.updateProgress(done, total);
    }

    await PhotoManager.editor.deleteWithIds(assetIdsToDelete);
    if (op != null) op.resultMessage = '$done item(s) deleted successfully.';
    if (op != null) op.status.value = OperationStatus.completed;
  }

  Future<void> moveToHidden(
    List<AssetEntity> assets, {
    OperationController? op,
  }) async {
    if (op != null) op.status.value = OperationStatus.running;
    int total = assets.length;
    int done = 0;
    if (op != null) op.updateProgress(done, total);

    List<String> assetIdsToDelete = [];

    for (final asset in assets) {
      final file = await asset.originFile;
      if (file == null) continue;

      final result = (asset.type == AssetType.video)
          ? await Future.wait([
              _saveEncryptedThumbnail(asset),
              _saveEncryptedPreview(asset),
              _saveEncryptedVideo(asset),
            ])
          : await Future.wait([
              _saveEncryptedThumbnail(asset),
              _saveEncryptedImage(asset),
            ]);

      if (result.contains(false)) {
        done++;
        if (op != null) op.updateProgress(done, total);
        continue;
      }

      final item = PrivateAsset.fromAssetEntity(asset, PrivateCategory.hidden);
      await _db.insert(
        'private_assets',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      assetIdsToDelete.add(asset.id);

      done++;
      if (op != null) op.updateProgress(done, total);
    }

    await PhotoManager.editor.deleteWithIds(assetIdsToDelete);
    if (op != null) op.resultMessage = '$done item(s) hidden successfully.';
    if (op != null) op.status.value = OperationStatus.completed;
  }

  Uint8List _secureRandomBytes(int length) {
    final rnd = SecureRandom("Fortuna")
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List.generate(
              32,
              (i) => DateTime.now().millisecondsSinceEpoch % 256,
            ),
          ),
        ),
      );

    return rnd.nextBytes(length);
  }

  Uint8List _encryptBytes(Uint8List bytes) {
    final iv = _secureRandomBytes(16);

    final cipher = CTRStreamCipher(AESEngine())
      ..init(
        true,
        ParametersWithIV(KeyParameter(_appSettings.encryptionKey), iv),
      );

    final encrypted = cipher.process(bytes);

    return Uint8List.fromList(iv + encrypted);
  }

  Uint8List _decryptBytes(Uint8List bytes) {
    final iv = bytes.sublist(0, 16);
    final data = bytes.sublist(16);

    final cipher = CTRStreamCipher(AESEngine())
      ..init(
        false,
        ParametersWithIV(KeyParameter(_appSettings.encryptionKey), iv),
      );

    return cipher.process(data);
  }

  Future<Uint8List> _getPlaceholderBytes(String placeholder) async {
    final data = await rootBundle.load('assets/placeholder/$placeholder.jpg');
    return data.buffer.asUint8List();
  }

  Future<void> _saveThumbnail(AssetEntity asset) async {
    Uint8List thumbBytes;

    try {
      final data = await asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      );

      if (data != null) {
        thumbBytes = data;
      } else {
        thumbBytes = await _getPlaceholderBytes(
          asset.type == AssetType.image
              ? 'image_thumbnail_placeholder'
              : 'video_thumbnail_placeholder',
        );
      }
    } catch (e) {
      thumbBytes = await _getPlaceholderBytes(
        asset.type == AssetType.image
            ? 'image_thumbnail_placeholder'
            : 'video_thumbnail_placeholder',
      );
    }

    final hiddenDirPath = await _getTrashPath();

    await File(
      p.join(hiddenDirPath, "${asset.id}_thumb"),
    ).writeAsBytes(thumbBytes);
  }

  Future<Uint8List?> getThumbnail(PrivateAsset asset) async {
    final hiddenDirPath = await _getTrashPath();
    final thumbFile = File(p.join(hiddenDirPath, "${asset.id}_thumb"));
    if (!thumbFile.existsSync()) return null;
    return thumbFile.readAsBytesSync();
  }

  Future<bool> _saveAsset(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null) return false;

    try {
      final hiddenDirPath = await _getTrashPath();
      await file.copy(p.join(hiddenDirPath, asset.id));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<File?> getAsset(PrivateAsset asset) async {
    final hiddenDirPath = await _getTrashPath();
    final assetFile = File(p.join(hiddenDirPath, asset.id));
    if (!assetFile.existsSync()) return null;
    return assetFile;
  }

  Future<void> _saveEncryptedThumbnail(AssetEntity asset) async {
    Uint8List thumbBytes;

    try {
      final data = await asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      );

      if (data != null) {
        thumbBytes = data;
      } else {
        thumbBytes = await _getPlaceholderBytes(
          asset.type == AssetType.image
              ? 'image_thumbnail_placeholder'
              : 'video_thumbnail_placeholder',
        );
      }
    } catch (e) {
      thumbBytes = await _getPlaceholderBytes(
        asset.type == AssetType.image
            ? 'image_thumbnail_placeholder'
            : 'video_thumbnail_placeholder',
      );
    }

    final hiddenDirPath = await _getHiddenPath();
    final encryptedThumb = _encryptBytes(thumbBytes);

    await File(
      p.join(hiddenDirPath, "${asset.id}_thumb.enc"),
    ).writeAsBytes(encryptedThumb);
  }

  Future<Uint8List?> getDecryptedThumbnail(PrivateAsset asset) async {
    final hiddenDirPath = await _getHiddenPath();
    final thumbFile = File(p.join(hiddenDirPath, "${asset.id}_thumb.enc"));
    if (!thumbFile.existsSync()) return null;
    final encryptedThumb = thumbFile.readAsBytesSync();
    return _decryptBytes(encryptedThumb);
  }

  Future<void> _saveEncryptedPreview(AssetEntity asset) async {
    Uint8List previewBytes;

    try {
      final data = await asset.thumbnailDataWithSize(
        const ThumbnailSize(1080, 1080),
      );

      if (data != null) {
        previewBytes = data;
      } else {
        previewBytes = await _getPlaceholderBytes('video_preview_placeholder');
      }
    } catch (e) {
      previewBytes = await _getPlaceholderBytes('video_preview_placeholder');
    }

    final hiddenDirPath = await _getHiddenPath();
    final encryptedThumb = _encryptBytes(previewBytes);

    await File(
      p.join(hiddenDirPath, "${asset.id}_preview.enc"),
    ).writeAsBytes(encryptedThumb);
  }

  Future<Uint8List?> getDecryptedPreview(PrivateAsset asset) async {
    final hiddenDirPath = await _getHiddenPath();
    final previewFile = File(p.join(hiddenDirPath, "${asset.id}_preview.enc"));
    if (!previewFile.existsSync()) return null;
    final encrypted = previewFile.readAsBytesSync();
    return _decryptBytes(encrypted);
  }

  Future<bool> _saveEncryptedImage(AssetEntity asset) async {
    final bytes = await asset.originBytes;
    if (bytes == null) return false;

    try {
      final hiddenDirPath = await _getHiddenPath();
      final encryptedImage = _encryptBytes(bytes);

      await File(
        p.join(hiddenDirPath, "${asset.id}.enc"),
      ).writeAsBytes(encryptedImage);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Uint8List?> getDecryptedImage(PrivateAsset asset) async {
    final hiddenDirPath = await _getHiddenPath();
    final encFile = File(p.join(hiddenDirPath, "${asset.id}.enc"));
    if (!encFile.existsSync()) return null;
    final encryptedData = encFile.readAsBytesSync();
    return _decryptBytes(encryptedData);
  }

  Future<bool> _saveEncryptedVideo(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null) return false;

    try {
      final hiddenDirPath = await _getHiddenPath();
      final encFile = File(p.join(hiddenDirPath, "${asset.id}.enc"));

      await FileCryptoService.encryptFile(
        inputPath: file.path,
        outputPath: encFile.path,
        key: _appSettings.encryptionKey,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<File?> getDecryptedVideo(PrivateAsset asset) async {
    try {
      final hiddenDir = await _getHiddenPath();
      final encFile = File(p.join(hiddenDir, "${asset.id}.enc"));

      final tempDir = await getTemporaryDirectory();

      final cacheDir = Directory(p.join(tempDir.path, "vault_video_cache"));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final outFile = File(p.join(cacheDir.path, asset.title));

      // if (await outFile.exists()) {
      //   return outFile;
      // }

      await FileCryptoService.decryptFile(
        inputPath: encFile.path,
        outputPath: outFile.path,
        key: _appSettings.encryptionKey,
      );

      return outFile;
    } catch (e) {
      return null;
    }
  }

  Future<List<PrivateAsset>> fetchByCategory(PrivateCategory category) async {
    final maps = await _db.query(
      'private_assets',
      where: 'category = ?',
      whereArgs: [category.name],
      orderBy: 'processed_at DESC',
    );
    return maps.map((m) => PrivateAsset.fromMap(m)).toList();
  }

  Future<void> unhide(
    List<PrivateAsset> items, {
    OperationController? op,
  }) async {
    final hiddenDirPath = await _getHiddenPath();

    op?.status.value = OperationStatus.running;

    int total = items.length;
    int done = 0;

    for (final item in items) {
      final encFile = File(p.join(hiddenDirPath, "${item.id}.enc"));

      if (!await encFile.exists()) continue;

      if (item.type == AssetMediaType.image) {
        final decrypted = _decryptBytes(await encFile.readAsBytes());

        await PhotoManager.editor.saveImage(
          decrypted,
          filename: item.title,
          desc: 'Originated from ${item.relativePath}',
          creationDate: item.createdAt,
          relativePath: 'Pictures/Unhidden',
          title: item.title,
          latitude: item.latitude,
          longitude: item.longitude,
          orientation: item.orientation,
        );
      } else {
        final tempFile = await getDecryptedVideo(item);

        if (tempFile != null) {
          await PhotoManager.editor.saveVideo(
            tempFile,
            title: item.title,
            desc: 'Originated from ${item.relativePath}',
            creationDate: item.createdAt,
            relativePath: 'Pictures/Unhidden',
            latitude: item.latitude,
            longitude: item.longitude,
            orientation: item.orientation,
          );
        }
      }

      await _cleanupPrivateFiles(item);
      await _deleteFromDb(item.id);

      done++;
      op?.updateProgress(done, total);
    }

    op?.resultMessage = '$done item(s) unhidden successfully.';
    op?.status.value = OperationStatus.completed;
  }

  Future<void> restore(
    List<PrivateAsset> items, {
    OperationController? op,
  }) async {

    if (op != null) op.status.value = OperationStatus.running;
    int total = items.length;
    int done = 0;

    for (final item in items) {
      final file = await getAsset(item);
      if (file == null) {
        done++;
        if (op != null) op.updateProgress(done, total);
        continue;
      }

      if (await file.exists()) {
        if (item.type == AssetMediaType.image) {
          await PhotoManager.editor.saveImage(
            await file.readAsBytes(),
            filename: item.title,
            desc: 'Originated from ${item.relativePath}',
            creationDate: item.createdAt,
            relativePath: 'Pictures/Restored',
            title: item.title,
            latitude: item.latitude,
            longitude: item.longitude,
            orientation: item.orientation,
          );
        } else {
          await PhotoManager.editor.saveVideo(
            file,
            title: item.title,
            desc: 'Originated from ${item.relativePath}',
            creationDate: item.createdAt,
            relativePath: 'Pictures/Restored',
            latitude: item.latitude,
            longitude: item.longitude,
            orientation: item.orientation,
          );
        }

        await _cleanupPrivateFiles(item);
        await _deleteFromDb(item.id);
      }

      done++;
      if (op != null) op.updateProgress(done, total);
    }
    if (op != null) op.resultMessage = '$done item(s) restored successfully.';
    if (op != null) op.status.value = OperationStatus.completed;
  }

  Future<void> permanentlyDelete(
    List<PrivateAsset> items, {
    OperationController? op,
  }) async {
    if (op != null) op.status.value = OperationStatus.running;
    int total = items.length;
    int done = 0;

    for (final item in items) {
      await _deleteFromDb(item.id);
      await _cleanupPrivateFiles(item);

      done++;
      if (op != null) op.updateProgress(done, total);
    }

    if (op != null) op.resultMessage = '$done item(s) deleted successfully.';
    if (op != null) op.status.value = OperationStatus.completed;
  }

  Future<void> _deleteFromDb(String id) async {
    await _db.delete('private_assets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _cleanupPrivateFiles(PrivateAsset asset) async {
    final hiddenDir = await _getHiddenPath();

    final encFile = File(p.join(hiddenDir, "${asset.id}.enc"));
    final thumbFile = File(p.join(hiddenDir, "${asset.id}_thumb.enc"));
    final previewFile = File(p.join(hiddenDir, "${asset.id}_preview.enc"));

    if (await encFile.exists()) await encFile.delete();
    if (await thumbFile.exists()) await thumbFile.delete();
    if (await previewFile.exists()) await previewFile.delete();

    // delete cached decrypted video
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, "vault_video_cache"));

    final cachedVideo = File(p.join(cacheDir.path, asset.title));
    if (await cachedVideo.exists()) await cachedVideo.delete();

    final trashDir = await _getTrashPath();

    final trashFile = File(p.join(trashDir, asset.id));
    final trashThumb = File(p.join(trashDir, "${asset.id}_thumb"));

    if (await trashFile.exists()) await trashFile.delete();
    if (await trashThumb.exists()) await trashThumb.delete();
  }

  Future<void> clearAllTrash() async {
    await _db.delete('private_assets');
  }
}
