import 'package:flutter/material.dart';
import 'package:gallery/ui/album/album_grid_page.dart';

import 'core/app_settings.dart';
import 'dependency_injector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = sl<AppSettings>();

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          home: AlbumGridPage(),
        );
      },
    );
  }
}
