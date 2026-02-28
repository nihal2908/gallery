import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/albums_controller.dart';
import 'core/app_settings.dart';
import 'services/authentication_service.dart';
import 'services/media_service.dart';
import 'services/native_media_service.dart';
import 'services/private_asset_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<AppSettings>(AppSettings(prefs));

  sl.registerLazySingleton<PrivateAssetService>(
    () => PrivateAssetService(sl<AppSettings>(), sl<AuthenticationService>())..init(),
  );

  sl.registerLazySingleton(() => AlbumsController(sl(), sl(), sl()));
  sl.registerLazySingleton(() => MediaService());
  sl.registerLazySingleton(() => NativeMediaService());
  sl.registerLazySingleton(() => AuthenticationService());
}
