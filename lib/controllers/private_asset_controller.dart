import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/operations/operation_controller.dart';
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

  Uint8List? getThumbnailAt(int index) {
    _onItemBuilt(index);
    final thumbnail = _thumbnailCache[_items[index].id];
    if (thumbnail == null) return null;
    return thumbnail;
  }

  void _onItemBuilt(int index) {
    final page = index ~/ pageSize;
    _loadThumbnailPage(page);
    _loadThumbnailPage(page + 1);
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

        final bytes = category == PrivateCategory.hidden
            ? await _privateAssetService.getDecryptedThumbnail(asset)
            : await _privateAssetService.getThumbnail(asset);
        if (bytes == null) return;

        _thumbnailCache[asset.id] = bytes;
      }),
    );

    _loadingPages.remove(page);
    notifyListeners();
  }

  Future<Uint8List?> getCompleteImage(PrivateAsset asset) async {
    if (category == PrivateCategory.trash) {
      final file = await _privateAssetService.getAsset(asset);
      if (file == null) return null;
      return file.readAsBytesSync();
    }

    return await _privateAssetService.getDecryptedImage(asset);
  }

  Future<Uint8List?> getVideoPreview(PrivateAsset asset) async {
    if (category == PrivateCategory.trash) return null;

    return await _privateAssetService.getDecryptedPreview(asset);
  }

  Future<File?> getCompleteVideoFile(PrivateAsset asset) async {
    if (category == PrivateCategory.trash) {
      return await _privateAssetService.getAsset(asset);
    }

    return await _privateAssetService.getDecryptedVideo(asset);
  }

  ValueNotifier<int> currentIndex = ValueNotifier(0);
  set setCurrentIndex(int index) => currentIndex.value = index;
  PrivateAsset get currentItem => _items[currentIndex.value];

  ValueNotifier<bool> showControls = ValueNotifier(true);

  void toggleControls() {
    showControls.value = !showControls.value;
  }

  Set<PrivateAsset> _selectedItems = {};
  ValueNotifier<bool> isSelectionMode = ValueNotifier(false);
  ValueNotifier<int> selectedCount = ValueNotifier(0);
  List<PrivateAsset> get selectedItems => _selectedItems.toList();
  bool isSelected(PrivateAsset item) => _selectedItems.contains(item);
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

  bool _restoring = false;

  Future<void> restoreCurrent() async {
    if (_restoring) return;
    _restoring = true;
    try {
      await _privateAssetService.restore([currentItem]);
    } finally {
      _restoring = false;
    }
    refresh();
  }

  Future<void> restoreSelected({OperationController? op}) async {
    await _privateAssetService.restore(selectedItems, op: op);
    clearSelections();
    refresh();
  }

  bool _unhiding = false;

  Future<void> unhideCurrent() async {
    if (_unhiding) return;
    _unhiding = true;
    try {
      await _privateAssetService.unhide([currentItem]);
    } finally {
      _unhiding = false;
    }
    refresh();
  }

  Future<void> unhideSelected({OperationController? op}) async {
    await _privateAssetService.unhide(selectedItems, op: op);
    clearSelections();
    refresh();
  }

  bool _deleting = false;

  Future<void> permanentlyDeleteCurrent() async {
    if (_deleting) return;
    _deleting = true;
    try {
      await _privateAssetService.permanentlyDelete([currentItem]);
    } finally {
      _deleting = false;
    }
    refresh();
  }

  Future<void> permanentlyDeleteSelected({OperationController? op}) async {
    await _privateAssetService.permanentlyDelete(selectedItems, op: op);
    clearSelections();
    refresh();
  }
}
