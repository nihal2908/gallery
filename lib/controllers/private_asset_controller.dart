import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery/core/operations/operation_controller.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/private_asset_model.dart';
import '../services/authentication_service.dart';
import '../services/private_asset_service.dart';

class PrivateAssetController extends ChangeNotifier {
  final PrivateAssetService _privateAssetService;
  // ignore: unused_field
  final AuthenticationService _authService;
  final PrivateCategory category;

  PrivateAssetController(
    this._privateAssetService,
    this._authService,
    this.category,
  );

  List<PrivateAsset> _items = [];
  int get itemCount => _items.length;
  PrivateAsset item(int index) => _items[index];

  static const int pageSize = 50;

  final Map<String, Uint8List> _thumbnailCache = {};
  final Set<int> _loadingPages = {};

  Future<void> init() async {
    _items = await _privateAssetService.fetchByCategory(category);
    notifyListeners();

    _loadThumbnailPage(0);
  }

  void refresh() async {
    _items = await _privateAssetService.fetchByCategory(category);
    notifyListeners();
  }

  void _loadThumbnailPage(int page) {
    if (_loadingPages.contains(page)) return;

    _loadingPages.add(page);

    final start = page * pageSize;
    final end = (start + pageSize).clamp(0, _items.length);

    if (start >= end) {
      _loadingPages.remove(page);
      return;
    }

    final slice = _items.sublist(start, end);

    _preloadThumbnails(slice, page);
  }

  Future<void> _preloadThumbnails(List<PrivateAsset> assets, int page) async {
    await Future.wait(
      assets.map((asset) async {
        if (_thumbnailCache.containsKey(asset.id)) return;

        final bytes = await _privateAssetService.getDecryptedThumbnail(asset);
        if (bytes == null) return;

        _thumbnailCache[asset.id] = bytes;
      }),
    );

    _loadingPages.remove(page);
    notifyListeners();
  }

  void _onItemBuilt(int index) {
    final page = index ~/ pageSize;
    _loadThumbnailPage(page);
    _loadThumbnailPage(page + 1);
  }

  Uint8List? getThumbnailAt(int index) {
    _onItemBuilt(index);
    final thumbnail = _thumbnailCache[_items[index].id];
    if (thumbnail == null) return null;
    return thumbnail;
  }

  Set<PrivateAsset> _selectedItems = {};
  ValueNotifier<bool> isSelectionMode = ValueNotifier(false);
  ValueNotifier<int> selectedCount = ValueNotifier(0);

  bool get areAllSelected => selectedCount.value == _items.length;
  bool get hasSelection => selectedCount.value > 0;

  void toggleSelection(PrivateAsset item) {
    if (_selectedItems.contains(item)) {
      _selectedItems.remove(item);
      selectedCount.value--;
    } else {
      _selectedItems.add(item);
      selectedCount.value++;
    }
    isSelectionMode.value = true;
  }

  void enterSelectionMode() {
    isSelectionMode.value = true;
  }

  void clearSelections() {
    _selectedItems.clear();
    selectedCount.value = 0;
    isSelectionMode.value = false;
  }

  void selectAll() {
    _selectedItems = _items.toSet();
    selectedCount.value = _items.length;
  }

  void deselectAll() {
    _selectedItems.clear();
    selectedCount.value = 0;
  }

  List<PrivateAsset> get selectedItems => _selectedItems.toList();
  bool isSelected(PrivateAsset item) => _selectedItems.contains(item);

  Future<void> restoreCurrent() async {
    await _restore([currentItem]);
  }

  Future<void> restoreSelected({OperationController? op}) async {
    await _restore(selectedItems, op: op);
    clearSelections();
  }

  Future<void> unhideCurrent() async {
    await _unhide([currentItem]);
  }

  Future<void> unhideSelected({OperationController? op}) async {
    await _unhide(selectedItems, op: op);
    clearSelections();
  }

  Future<void> permanentlyDeleteCurrent() async {
    await _permanentlyDelete([currentItem]);
  }

  Future<void> permanentlyDeleteSelected({OperationController? op}) async {
    await _permanentlyDelete(selectedItems, op: op);
    clearSelections();
  }

  ValueNotifier<int> currentIndex = ValueNotifier(0);
  set setCurrentIndex(int index) => currentIndex.value = index;

  PrivateAsset get currentItem => _items[currentIndex.value];

  Future<File?> getFile(PrivateAsset item) async {
    final trashDirPath = await _privateAssetService.getTrashPath();
    final file = item.getLocalFile(trashDirPath);
    if (await file.exists()) return file;
    return null;
  }

  Future<void> _unhide(
    List<PrivateAsset> items, {
    OperationController? op,
  }) async {
    final hiddenDirPath = await _privateAssetService.getHiddenPath();

    if (op != null) op.status.value = OperationStatus.running;
    int total = items.length;
    int done = 0;

    for (final item in items) {
      final file = item.getLocalFile(hiddenDirPath);

      if (await file.exists()) {
        if (item.type == AssetMediaType.image) {
          await PhotoManager.editor.saveImage(
            await file.readAsBytes(),
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
          await PhotoManager.editor.saveVideo(
            file,
            title: item.title,
            desc: 'Originated from ${item.relativePath}',
            creationDate: item.createdAt,
            relativePath: 'Pictures/Unhidden',
            latitude: item.latitude,
            longitude: item.longitude,
            orientation: item.orientation,
          );
        }

        // Cleanup
        await file.delete();
        await _privateAssetService.deleteFromDb(item.id);
      }

      done++;
      if (op != null) op.updateProgress(done, total);
    }
    if (op != null) op.resultMessage = '$done item(s) unhidden successfully.';
    if (op != null) op.status.value = OperationStatus.completed;
    refresh();
  }

  Future<void> _restore(
    List<PrivateAsset> items, {
    OperationController? op,
  }) async {
    final trashDirPath = await _privateAssetService.getTrashPath();

    if (op != null) op.status.value = OperationStatus.running;
    int total = items.length;
    int done = 0;

    for (final item in items) {
      final file = item.getLocalFile(trashDirPath);

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

        // Cleanup
        await file.delete();
        await _privateAssetService.deleteFromDb(item.id);
      }

      done++;
      if (op != null) op.updateProgress(done, total);
    }
    if (op != null) op.resultMessage = '$done item(s) restored successfully.';
    if (op != null) op.status.value = OperationStatus.completed;
    refresh();
  }

  Future<void> _permanentlyDelete(
    List<PrivateAsset> items, {
    OperationController? op,
  }) async {
    final trashDirPath = await _privateAssetService.getTrashPath();

    if (op != null) op.status.value = OperationStatus.running;
    int total = items.length;
    int done = 0;

    for (final item in items) {
      final file = item.getLocalFile(trashDirPath);
      if (await file.exists()) await file.delete();

      await _privateAssetService.deleteFromDb(item.id);

      done++;
      if (op != null) op.updateProgress(done, total);
    }

    if (op != null) op.resultMessage = '$done item(s) deleted successfully.';
    if (op != null) op.status.value = OperationStatus.completed;
    refresh();
  }
}
