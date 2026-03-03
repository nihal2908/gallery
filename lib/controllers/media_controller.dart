import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import './../core/operations/operation_controller.dart';
import '../core/settings/app_settings.dart';
import '../services/media_service.dart';
import '../services/native_media_service.dart';
import '../services/private_asset_service.dart';
import 'albums_controller.dart';

class MediaController extends ChangeNotifier {
  final MediaService _mediaService;
  final NativeMediaService _nativeMediaService;
  final PrivateAssetService _privateService;
  final AlbumsController _albumsController;
  final AppSettings _settings;
  AssetPathEntity album;

  MediaController(
    this._mediaService,
    this._nativeMediaService,
    this._privateService,
    this._albumsController,
    this._settings,
    this.album,
  );

  static const int pageSize = 100;

  final Map<int, List<AssetEntity>> _pages = {};
  final Set<int> _loadingPages = {};

  ValueNotifier<int> assetCount = ValueNotifier(0);

  ValueNotifier<bool> showControls = ValueNotifier(true);
  void toggleControls() {
    showControls.value = !showControls.value;
  }

  ValueNotifier<int> selectedCount = ValueNotifier(0);
  ValueNotifier<bool> isSelectionMode = ValueNotifier(false);
  ValueNotifier<int> currentIndex = ValueNotifier(0);
  ValueNotifier<bool> favoriteChanged = ValueNotifier(false);

  ValueNotifier<bool>? keepAwake;

  Future<void> init() async {
    assetCount.value = await album.assetCountAsync;
    notifyListeners();
    keepAwake = _settings.keepScreenOnNotifier;
    _albumsController.addListener(_handleGlobalAlbumsUpdate);
    // _mediaService.startListening(_onMediaChanged);

    loadPage(0);
  }

  @override
  void dispose() {
    _albumsController.removeListener(_handleGlobalAlbumsUpdate);
    // _mediaService.stopListening(_onMediaChanged);
    super.dispose();
  }

  void _handleGlobalAlbumsUpdate() {
    final updatedAlbum = _albumsController.albums.firstWhere(
      (element) => element.id == album.id,
    );
    album = updatedAlbum;
    _handleExternalChanges();
  }

  Future<void> _handleExternalChanges() async {
    await album.fetchPathProperties();

    final newCount = await album.assetCountAsync;
    // print(newCount);
    // print(assetCount.value);

    if (newCount != assetCount.value) {
      assetCount.value = newCount;
      _pages.clear();
      _loadingPages.clear();
      loadPage(0);
    }
  }

  AssetEntity? getAssetAt(int index) {
    _onItemIndexBuilt(index);
    final page = index ~/ pageSize;
    final indexInPage = index % pageSize;

    final assets = _pages[page];
    if (assets == null || indexInPage >= assets.length) return null;

    return assets[indexInPage];
  }

  void _onItemIndexBuilt(int index) {
    final page = index ~/ pageSize;

    loadPage(page);
    loadPage(page + 1);
  }

  Future<void> loadPage(int page) async {
    if (_pages.containsKey(page) || _loadingPages.contains(page)) return;

    _loadingPages.add(page);

    final assets = await album.getAssetListPaged(page: page, size: pageSize);

    if (assets.isNotEmpty) {
      _pages[page] = assets;
      notifyListeners();
    }

    _loadingPages.remove(page);
  }

  set setCurrentIndex(int value) {
    currentIndex.value = value;

    final page = value ~/ pageSize;
    loadPage(page);
  }

  AssetEntity? get currentAsset => getAssetAt(currentIndex.value);

  final Set<int> _selectedIndexes = {};

  bool get areAllSelected => selectedCount.value == assetCount.value;
  bool get isNoSelected => selectedCount.value == 0;

  bool isSelectedAt(int index) => _selectedIndexes.contains(index);

  void toggleSelectionAt(int index) {
    isSelectionMode.value = true;
    _selectedIndexes.contains(index)
        ? _selectedIndexes.remove(index)
        : _selectedIndexes.add(index);
    selectedCount.value = _selectedIndexes.length;
  }

  void enterSelectionMode() {
    isSelectionMode.value = true;
    selectedCount.value = 0;
    notifyListeners();
  }

  void selectAll() {
    _selectedIndexes.clear();
    for (int i = 0; i < assetCount.value; i++) {
      _selectedIndexes.add(i);
    }
    isSelectionMode.value = true;
    selectedCount.value = assetCount.value;
    notifyListeners();
  }

  void deselectAll() {
    _selectedIndexes.clear();
    selectedCount.value = 0;
    notifyListeners();
  }

  void clearSelection() {
    _selectedIndexes.clear();
    selectedCount.value = 0;
    isSelectionMode.value = false;
    notifyListeners();
  }

  Future<List<AssetEntity>> getSelectedAssets() async {
    final List<AssetEntity> result = [];

    for (final index in _selectedIndexes) {
      final asset = getAssetAt(index);
      if (asset != null) {
        result.add(asset);
      } else {
        // Ensure page is loaded if missing
        final page = index ~/ pageSize;
        await loadPage(page);

        final resolved = getAssetAt(index);
        if (resolved != null) {
          result.add(resolved);
        }
      }
    }

    return result;
  }

  void toggleFavorite() async {
    final index = currentIndex.value;
    final target = getAssetAt(index);
    if (target == null) return;
    final bool newStatus = !target.isFavorite;
    final updatedAsset = await PhotoManager.editor.android.favoriteAsset(
      entity: target,
      favorite: newStatus,
    );

    final page = index ~/ pageSize;
    final indexInPage = index % pageSize;
    final assets = _pages[page];
    if (assets == null || indexInPage >= assets.length) return;
    assets[indexInPage] = updatedAsset;

    favoriteChanged.value = !favoriteChanged.value;
  }

  Future<void> convertSelectedToPDF({
    String? filename,
    OperationController? op,
  }) async {
    final selected = await getSelectedAssets();
    if (selected.isEmpty) return;

    final pdfFile = await _mediaService.assetsToPdf(
      selected,
      fileName: filename,
      op: op,
    );
    if (pdfFile == null) return;

    clearSelection();
  }

  void sharePDF(pdfFilePath) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(pdfFilePath)]));
  }

  /// Core helper to handle Copy or Move for both Images and Videos
  Future<void> _processBatchTransfer({
    required List<AssetEntity> assets,
    required AssetPathEntity targetAlbum,
    required bool isMove,
    OperationController? op,
  }) async {
    final List<String> idsToDelete = [];
    final relativePath = await targetAlbum.relativePathAsync;
    if (relativePath == null) return;

    if (op != null) op.status.value = OperationStatus.running;
    int total = assets.length;
    int done = 0;

    for (var asset in assets) {
      try {
        final file = await asset.originFile;
        if (file == null) continue;

        AssetEntity? result;
        if (asset.type == AssetType.image) {
          final bytes = await asset.originBytes;
          if (bytes != null) {
            result = await PhotoManager.editor.saveImage(
              bytes,
              title: asset.title,
              filename:
                  asset.title ?? "IMG_${DateTime.now().millisecondsSinceEpoch}",
              relativePath: relativePath,
            );
          }
        } else if (asset.type == AssetType.video) {
          result = await PhotoManager.editor.saveVideo(
            file,
            title: asset.title,
            relativePath: relativePath,
          );
        }

        if (result != null && isMove) {
          idsToDelete.add(asset.id);
        }

        done++;
        if (op != null) op.updateProgress(done, total);
      } catch (e) {
        debugPrint("Transfer failed for ${asset.id}: $e");
      }
    }

    if (idsToDelete.isNotEmpty) {
      await PhotoManager.editor.deleteWithIds(idsToDelete);
    }

    if (op == null) return;
    op.resultMessage = isMove
        ? '$done item(s) moved to ${album.name} successfully.'
        : '$done item(s) copied to ${album.name} successfully.';
    op.status.value = OperationStatus.completed;

    return;
  }

  Future<void> copyCurrentToAlbum(AssetPathEntity targetAlbum) async {
    final asset = currentAsset;
    if (asset == null) return;
    await _processBatchTransfer(
      assets: [asset],
      targetAlbum: targetAlbum,
      isMove: false,
    );
  }

  Future<void> copySelectedToAlbum(
    AssetPathEntity targetAlbum, {
    OperationController? op,
  }) async {
    final selected = await getSelectedAssets();
    await _processBatchTransfer(
      assets: selected,
      targetAlbum: targetAlbum,
      isMove: false,
    );
    clearSelection();
  }

  Future<void> moveCurrentToAlbum(AssetPathEntity targetAlbum) async {
    final asset = currentAsset;
    if (asset == null) return;
    await _processBatchTransfer(
      assets: [asset],
      targetAlbum: targetAlbum,
      isMove: true,
    );
  }

  Future<void> moveSelectedToAlbum(
    AssetPathEntity targetAlbum, {
    OperationController? op,
  }) async {
    final selected = await getSelectedAssets();
    if (selected.isEmpty) return;
    await _processBatchTransfer(
      assets: selected,
      targetAlbum: targetAlbum,
      isMove: true,
    );
    clearSelection();
  }

  bool get recycleBinEnabled => _settings.recycleBinEnabled;

  Future<void> moveCurrentToTrash() async {
    if (_settings.recycleBinEnabled) {
      await _privateService.moveToTrash([currentAsset!]);
    } else {
      await PhotoManager.editor.deleteWithIds([currentAsset!.id]);
    }
  }

  Future<void> moveSelectedToTrash({OperationController? op}) async {
    final selected = await getSelectedAssets();
    if (selected.isEmpty) return;
    if (_settings.recycleBinEnabled) {
      await _privateService.moveToTrash(selected, op: op);
    } else {
      await PhotoManager.editor.deleteWithIds(
        selected.map((e) => e.id).toList(),
      );
    }
    clearSelection();
  }

  Future<bool> hasPassword() async => _privateService.hasPassword();

  Future<void> hideCurrent() async {
    final asset = currentAsset;
    if (asset == null) return;
    await _privateService.moveToHidden([asset]);
  }

  Future<void> hideSelected({OperationController? op}) async {
    final selected = await getSelectedAssets();
    if (selected.isEmpty) return;
    await _privateService.moveToHidden(selected, op: op);
    clearSelection();
  }

  Future<bool> setCurrentAsWallpaper() async {
    final file = await currentAsset?.originFile;
    if (file == null) {
      return false;
    }
    return await _nativeMediaService.setAsWallpaper(file.path);
  }

  void shareCurrent() async {
    final file = await currentAsset?.file;
    if (file == null) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  void shareSelected() async {
    List<XFile> files = [];
    final selected = await getSelectedAssets();
    for (var asset in selected) {
      final file = await asset.file;
      if (file != null) {
        files.add(XFile(file.path));
      }
    }
    if (files.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(files: files));
    }
    clearSelection();
  }
}
