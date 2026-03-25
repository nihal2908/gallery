import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  AppSettings(this._prefs) {
    _init();
  }

  static const _keyTheme = 'theme_mode';
  static const _keyRecycleBin = 'recycle_bin_enabled';
  static const _keyKeepScreen = 'keep_screen_on';
  static const _keyAutoRotate = 'auto_rotate_enabled';
  static const _keyTrashDuration = 'trash_duration_days';
  static const _keyStorageName = "vault_encryption_key";

  // ---------------- GLOBAL STATE ----------------
  ThemeMode _themeMode = ThemeMode.system;
  bool _recycleBinEnabled = true;
  int _trashLifeDays = 30;
  Uint8List? _encryptionKey;

  // ---------------- LOCAL PAGE STATE ----------------
  final ValueNotifier<bool> keepScreenOnNotifier = ValueNotifier(false);

  final ValueNotifier<bool> autoRotateNotifier = ValueNotifier(true);

  void _init() {
    final theme = _prefs.getString(_keyTheme);
    if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    }

    _recycleBinEnabled = _prefs.getBool(_keyRecycleBin) ?? true;
    _trashLifeDays = _prefs.getInt(_keyTrashDuration) ?? 30;

    keepScreenOnNotifier.value = _prefs.getBool(_keyKeepScreen) ?? false;

    autoRotateNotifier.value = _prefs.getBool(_keyAutoRotate) ?? true;

    _initializeEncryptionKey();
  }

  // ---------------- GLOBAL GETTERS ----------------
  ThemeMode get themeMode => _themeMode;
  bool get recycleBinEnabled => _recycleBinEnabled;
  int get trashLifeDays => _trashLifeDays;
  Uint8List get encryptionKey => _encryptionKey!;

  Uint8List _generateRandomKey() {
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

    return rnd.nextBytes(32);
  }

  Future<void> _initializeEncryptionKey() async {
    final storedKey = await _secureStorage.read(key: _keyStorageName);

    if (storedKey != null) {
      _encryptionKey = base64Decode(storedKey);
      return;
    }

    // Generate new key
    final newKeyBytes = _generateRandomKey();

    await _secureStorage.write(
      key: _keyStorageName,
      value: base64Encode(newKeyBytes),
    );

    _encryptionKey = newKeyBytes;
  }

  // ---------------- GLOBAL SETTERS ----------------
  void updateTheme(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _prefs.setString(_keyTheme, mode.name);
    notifyListeners();
  }

  void toggleRecycleBin(bool value) async {
    if (_recycleBinEnabled == value) return;
    _recycleBinEnabled = value;
    await _prefs.setBool(_keyRecycleBin, value);
    notifyListeners();
  }

  void updateTrashDuration(int days) {
    if (_trashLifeDays == days) return;
    _trashLifeDays = days;
    _prefs.setInt(_keyTrashDuration, days);
    notifyListeners();
  }

  // ---------------- MEDIA VIEW ONLY ----------------
  void toggleKeepScreenOn(bool value) {
    if (keepScreenOnNotifier.value == value) return;

    keepScreenOnNotifier.value = value;
    _prefs.setBool(_keyKeepScreen, value);
  }

  void toggleAutoRotate(bool value) {
    if (autoRotateNotifier.value == value) return;

    autoRotateNotifier.value = value;
    _prefs.setBool(_keyAutoRotate, value);
  }

  // ---------------- CLEANUP ----------------
  @override
  void dispose() {
    keepScreenOnNotifier.dispose();
    autoRotateNotifier.dispose();
    super.dispose();
  }
}
