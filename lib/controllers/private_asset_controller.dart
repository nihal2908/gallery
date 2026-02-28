import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/private_asset_model.dart';
import '../services/authentication_service.dart';
import '../services/private_asset_service.dart';

class PrivateAssetController extends ChangeNotifier {
  final PrivateAssetService _privateAssetService;
  final AuthenticationService _authService;
  final PrivateCategory category;

  PrivateAssetController(
    this._privateAssetService,
    this._authService,
    this.category,
  );

  List<PrivateAsset> _items = [];
  List<PrivateAsset> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Set<PrivateAsset> _selectedItems = {};
  ValueNotifier<bool> isSelectionMode = ValueNotifier(false);
  ValueNotifier<int> selectedCount = ValueNotifier(0);

  bool get areAllSelected => selectedCount.value == _items.length;
  bool get hasSelection => selectedCount.value > 0;

  void toggleSelection(PrivateAsset item) {
    _selectedItems.add(item);
    isSelectionMode.value = true;
    selectedCount.value++;
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

  Future<void> restoreSelected() async {
    await restore(selectedItems);
    clearSelections();
  }

  Future<void> unhideSelected() async {
    await unhide(selectedItems);
    clearSelections();
  }

  Future<void> permanentlyDeleteSelected() async {
    await permanentlyDelete(selectedItems);
    clearSelections();
  }

  ValueNotifier<int> currentIndex = ValueNotifier(0);
  set setCurrentIndex(int index) => currentIndex.value = index;

  PrivateAsset get currentItem => items[currentIndex.value];

  Future<void> loadTrash() async {
    _isLoading = true;
    notifyListeners();
    _items = await _privateAssetService.fetchByCategory(PrivateCategory.trash);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadHidden() async {
    _isLoading = true;
    notifyListeners();

    _items = await _privateAssetService.fetchByCategory(PrivateCategory.hidden);
    _isLoading = false;
    notifyListeners();
  }

  Future<File?> getFile(PrivateAsset item) async {
    final trashDirPath = await _privateAssetService.getTrashPath();
    final file = item.getLocalFile(trashDirPath);
    if (await file.exists()) return file;
    return null;
  }

  Future<void> unhide(List<PrivateAsset> items) async {
    final hiddenDirPath = await _privateAssetService.getHiddenPath();
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
      await loadHidden();
    }
  } 

  Future<void> restore(List<PrivateAsset> items) async {
    final trashDirPath = await _privateAssetService.getTrashPath();
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
      await loadTrash();
    }
  }

  Future<void> permanentlyDelete(List<PrivateAsset> items) async {
    final trashDirPath = await _privateAssetService.getTrashPath();
    for (final item in items) {
      final file = item.getLocalFile(trashDirPath);
      if (await file.exists()) await file.delete();

      await _privateAssetService.deleteFromDb(item.id);
    }
    await loadTrash();
  }
}
