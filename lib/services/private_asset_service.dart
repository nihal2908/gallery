import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:sqflite/sqflite.dart';

import '../core/app_settings.dart';
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

  Future<void> moveToTrash(List<AssetEntity> assets) async {
    for (final asset in assets) {
      final file = await asset.originFile;
      if (file == null) return;

      final trashDirPath = await getTrashPath();
      final targetPath = p.join(trashDirPath, asset.id);

      // 1. Physical move (Copy then Delete from MediaStore)
      await file.copy(targetPath);

      // 2. Map to Model
      final item = PrivateAsset.fromAssetEntity(asset, PrivateCategory.trash);

      // 3. Database entry
      await _db.insert(
        'private_assets',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 4. Final step: Remove from System Gallery
    await PhotoManager.editor.deleteWithIds(assets.map((a) => a.id).toList());
  }

  Future<void> moveToHidden(List<AssetEntity> assets) async {
    final hiddenDirPath = await getHiddenPath();
    // add print statement to check path
    print("Hidden Dir Path: $hiddenDirPath");

    for (final asset in assets) {
      final file = await asset.originFile;
      if (file == null) continue;
      print("Processing asset: ${asset.id}, file path: ${file.path}");

      // 1️⃣ Read original
      final originalBytes = await file.readAsBytes();
      print("Original size: ${originalBytes.length} bytes");

      // 2️⃣ Get native thumbnail
      final thumbBytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(150, 150),
      );

      if (thumbBytes == null) continue;

      print("Thumbnail size: ${thumbBytes.length} bytes");
      // 3️⃣ Encrypt both
      final encryptedOriginal = encryptBytes(originalBytes);

      print("Encrypted original size: ${encryptedOriginal.length} bytes");

      final encryptedThumb = encryptBytes(thumbBytes);

      print("Encrypted thumbnail size: ${encryptedThumb.length} bytes");

      // 4️⃣ Save
      await File(
        p.join(hiddenDirPath, "${asset.id}.enc"),
      ).writeAsBytes(encryptedOriginal);

      print(
        "Encrypted original saved at: ${p.join(hiddenDirPath, "${asset.id}.enc")}",
      );

      await File(
        p.join(hiddenDirPath, "${asset.id}_thumb.enc"),
      ).writeAsBytes(encryptedThumb);

      print(
        "Encrypted thumbnail saved at: ${p.join(hiddenDirPath, "${asset.id}_thumb.enc")}",
      );

      // 5️⃣ Save metadata
      final item = PrivateAsset.fromAssetEntity(asset, PrivateCategory.hidden);

      print("Mapped asset to model: ${item.id}, title: ${item.title}");
      await _db.insert(
        'private_assets',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("Metadata saved to DB for asset: ${item.id}");
    }

    // 6️⃣ Delete from gallery
    await PhotoManager.editor.deleteWithIds(assets.map((a) => a.id).toList());
  }

  Uint8List encryptBytes(Uint8List bytes) {
    print("Encrypting data of size: ${bytes.length} bytes");
    final encrypter = Encrypter(AES(_appSettings.encryptionKey));
    print("Encryption key: ${_appSettings.encryptionKey.base64}");
    final encrypted = encrypter.encryptBytes(
      bytes,
      iv: IV.fromSecureRandom(16),
    );
    print("Encrypted data size: ${encrypted.bytes.length} bytes");

    // Store IV at beginning of file
    return Uint8List.fromList(encrypted.bytes);
  }

  Uint8List decryptBytes(Uint8List bytes) {
    final encryptedData = bytes.sublist(16);

    final encrypter = Encrypter(AES(_appSettings.encryptionKey));

    return Uint8List.fromList(encrypter.decryptBytes(Encrypted(encryptedData)));
  }

  Future<List<PrivateAsset>> fetchByCategory(PrivateCategory category) async {
    final maps = await _db.query(
      'private_assets',
      // where: 'category = ?',
      // whereArgs: [category.name],
      orderBy: 'processed_at DESC',
    );
    print(maps);
    return maps.map((m) => PrivateAsset.fromMap(m)).toList();
  }

  Future<void> deleteFromDb(String id) async {
    await _db.delete('private_assets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllTrash() async {
    await _db.delete('private_assets');
  }
}
