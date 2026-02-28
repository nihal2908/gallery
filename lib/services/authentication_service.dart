import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthenticationService {
  final _storage = const FlutterSecureStorage();
  static const _passKey = 'hidden_album_password';
  static const _protectionEnabledKey = 'is_protection_enabled';

  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  void grantAccess() {
    isAuthenticated.value = true;
  }

  void revokeAccess() {
    isAuthenticated.value = false;
  }

  Future<bool> isProtectionEnabled() async {
    String? enabled = await _storage.read(key: _protectionEnabledKey);
    return enabled == 'true';
  }

  Future<bool> hasPassword() async {
    String? storedPassword = await _storage.read(key: _passKey);
    return storedPassword != null;
  }

  Future<bool> isPasswordCorrect(String password) async {
    String? storedPassword = await _storage.read(key: _passKey);
    if (storedPassword == password) {
      return true;
    }
    return false;
  }

  Future<bool> authenticate(String input) async {
    if (!await isProtectionEnabled()) {
      grantAccess();
      return true;
    }

    String? storedPassword = await _storage.read(key: _passKey);
    if (storedPassword == input) {
      grantAccess();
      return true;
    } else {
      return false;
    }
  }

  Future<void> setPassword(String password) async {
    await _storage.write(key: _passKey, value: password);
    await _storage.write(key: _protectionEnabledKey, value: 'true');
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (await authenticate(oldPassword)) {
      await setPassword(newPassword);
      return true;
    }
    return false;
  }

  Future<void> removePasswordProtection() async {
    await _storage.write(key: _protectionEnabledKey, value: 'false');
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
