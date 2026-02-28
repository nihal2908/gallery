// services/native_media_service.dart
import 'package:flutter/services.dart';

class NativeMediaService {
  final _channel = MethodChannel('native_media');

  Future<bool> setAsWallpaper(String path) async {
    try{ 
      _channel.invokeMethod('setAsWallpaper', {'path': path});
      return true;
    } catch(e) {
      return false;
    }
  }

  // move, copy, rename, hide...
}