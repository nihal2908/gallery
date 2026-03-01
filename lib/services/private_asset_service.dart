import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:gallery/core/operations/operation_controller.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:sqflite/sqflite.dart';

import '../core/settings/app_settings.dart';
import '../models/private_asset_model.dart';
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

    await cleanupExpiredTrash();
  }

  Future<void> cleanupExpiredTrash() async {
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

    final trashPath = await getTrashPath();

    for (final item in expired) {
      final id = item['id'] as String;

      final file = File(p.join(trashPath, id));

      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<int> getCount(PrivateCategory category) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) FROM private_assets WHERE category = ?',
      [category.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<String> getTrashPath() async {
    if (_cachedTrashPath != null) return _cachedTrashPath!;
    final directory = await getApplicationDocumentsDirectory();
    _cachedTrashPath = p.join(directory.path, 'trash_bin');
    await Directory(_cachedTrashPath!).create(recursive: true);
    return _cachedTrashPath!;
  }

  Future<String> getHiddenPath() async {
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
    final trashDirPath = await getTrashPath();

    if (op != null) op.status.value = OperationStatus.running;
    int total = assets.length;
    int done = 0;

    for (final asset in assets) {
      final file = await asset.originFile;
      if (file == null) return;

      final targetPath = p.join(trashDirPath, asset.id);
      await file.copy(targetPath);

      final item = PrivateAsset.fromAssetEntity(asset, PrivateCategory.trash);

      await _db.insert(
        'private_assets',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      done++;
      if (op != null) op.updateProgress(done, total);
    }

    await PhotoManager.editor.deleteWithIds(assets.map((a) => a.id).toList());
    if (op != null) op.resultMessage = '$done item(s) deleted successfully.';
    if (op != null) op.status.value = OperationStatus.completed;
  }

  Future<void> moveToHidden(
    List<AssetEntity> assets, {
    OperationController? op,
  }) async {
    final hiddenDirPath = await getHiddenPath();

    if (op != null) op.status.value = OperationStatus.running;
    int total = assets.length;
    int done = 0;

    for (final asset in assets) {
      final file = await asset.originFile;
      if (file == null) continue;

      final originalBytes = await file.readAsBytes();

      final thumbBytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(150, 150),
      );

      if (thumbBytes == null) continue;

      final encryptedOriginal = encryptBytes(originalBytes);
      final encryptedThumb = encryptBytes(thumbBytes);

      await File(
        p.join(hiddenDirPath, "${asset.id}.enc"),
      ).writeAsBytes(encryptedOriginal);

      await File(
        p.join(hiddenDirPath, "${asset.id}_thumb.enc"),
      ).writeAsBytes(encryptedThumb);

      final item = PrivateAsset.fromAssetEntity(asset, PrivateCategory.hidden);
      await _db.insert(
        'private_assets',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      done++;
      if (op != null) op.updateProgress(done, total);
    }

    await PhotoManager.editor.deleteWithIds(assets.map((a) => a.id).toList());
    if (op != null) op.resultMessage = '$done item(s) hidden successfully.';
    if (op != null) op.status.value = OperationStatus.completed;
  }

  Uint8List encryptBytes(Uint8List bytes) {
    final encrypter = Encrypter(AES(_appSettings.encryptionKey));
    final iv = IV.fromSecureRandom(16);
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);
    return Uint8List.fromList(iv.bytes + encrypted.bytes);
  }

  Uint8List decryptBytes(Uint8List bytes) {
    final iv = IV(bytes.sublist(0, 16));
    final encryptedData = bytes.sublist(16);
    final encrypter = Encrypter(AES(_appSettings.encryptionKey));
    return Uint8List.fromList(
      encrypter.decryptBytes(Encrypted(encryptedData), iv: iv),
    );
  }

  Future<Uint8List?> getDecryptedThumbnail(PrivateAsset asset) async {
    final hiddenDirPath = await getHiddenPath();
    final thumbFile = File(p.join(hiddenDirPath, "${asset.id}_thumb.enc"));
    if (!thumbFile.existsSync()) return null;
    final encryptedThumb = thumbFile.readAsBytesSync();
    return decryptBytes(encryptedThumb);
  }

  Future<Uint8List?> getDecryptedOriginal(PrivateAsset asset) async {
    final hiddenDirPath = await getHiddenPath();
    final encFile = File(p.join(hiddenDirPath, "${asset.id}.enc"));
    if (!encFile.existsSync()) return null;
    final encryptedData = encFile.readAsBytesSync();
    return decryptBytes(encryptedData);
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

  Future<void> deleteFromDb(String id) async {
    await _db.delete('private_assets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllTrash() async {
    await _db.delete('private_assets');
  }
}
