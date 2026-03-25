import 'dart:convert';
import 'package:flutter/services.dart';

class FileCryptoService {
  static const MethodChannel _platform = MethodChannel('file_crypto');

  static Future<void> encryptFile({
    required String inputPath,
    required String outputPath,
    required Uint8List key,
  }) async {
    await _platform.invokeMethod('encryptFile', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'key': base64Encode(key),
    });
  }

  static Future<void> decryptFile({
    required String inputPath,
    required String outputPath,
    required Uint8List key,
  }) async {
    await _platform.invokeMethod('decryptFile', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'key': base64Encode(key),
    });
  }
}
