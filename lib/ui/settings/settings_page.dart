import 'package:flutter/material.dart';
import 'package:gallery/ui/pdf_generation/pdf_manager_page.dart';

import '../../dependency_injector.dart';
import '../../models/private_asset_model.dart';
import '../../services/authentication_service.dart';
import '../../core/settings/app_settings.dart';
import '../private/password_entry_page.dart';
import '../private/private_grid_page.dart';
import '../private/secure_gate.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final settings = sl<AppSettings>();
  final authService = sl<AuthenticationService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            children: [
              // Theme Selection
              ListTile(
                title: const Text('Theme'),
                subtitle: Text(_getThemeName(settings.themeMode)),
                trailing: DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  underline: const SizedBox(),
                  onChanged: (ThemeMode? newMode) {
                    if (newMode != null) settings.updateTheme(newMode);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System Default'),
                    ),
                  ],
                ),
              ),

              // Recycle Bin Toggle
              _SettingTile(
                title: 'Recycle Bin',
                subtitle:
                    'Deleted items will be moved to the trash folder first',
                enabled: settings.recycleBinEnabled,
                onToggle: (value) => settings.toggleRecycleBin(value),
              ),

              // Keep Screen On
              _SettingTile(
                title: 'Keep Screen On',
                subtitle: 'Prevent screen dimming during slideshows',
                enabled: settings.keepScreenOnNotifier.value,
                onToggle: (value) => settings.toggleKeepScreenOn(value),
              ),

              // PDF Manager page
              ListTile(
                title: const Text('Generated PDFs'),
                subtitle: const Text('Show all previously generated PDFs.'),
                trailing: const Icon(Icons.picture_as_pdf),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PdfManagerPage()),
                  );
                },
              ),

              // Hidden Album Access
              ListTile(
                title: const Text('Hidden Album'),
                subtitle: const Text('Show hidden photos and videos'),
                trailing: const Icon(Icons.lock_outline),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SecureGate(
                        authService: authService,
                        child: const PrivateGridPage(
                          category: PrivateCategory.hidden,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Hidden Album Password Management
              ListTile(
                title: const Text('Hidden Album Password'),
                subtitle: const Text(
                  'Set, Change, or Remove password security',
                ),
                onTap: () => _showPasswordManagement(context),
              ),

              const Divider(),
              const ListTile(
                title: Text('About'),
                subtitle: Text('Gallery App v1.0.0'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  Future<void> _showPasswordManagement(BuildContext context) async {
    final hasPassword = await authService.hasPassword();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: hasPassword
                    ? Text('Change password')
                    : Text('Set Password'),
                subtitle: hasPassword
                    ? Text('Change password for the hidden album')
                    : Text('Set a new password for the hidden album'),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PasswordEntryPage(
                        mode: hasPassword
                            ? PasswordEntryPageMode.changePassword
                            : PasswordEntryPageMode.setPassword,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Remove Password'),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PasswordEntryPage(
                        mode: PasswordEntryPageMode.authenticate,
                        popOnSuccess: false,
                      ),
                    ),
                  ).then((value) async {
                    if (value == null || value == false) return;
                    if (!value) return;
                    await authService.removePasswordProtection();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool enabled;
  final ValueChanged<bool>? onToggle;

  const _SettingTile({
    required this.title,
    this.subtitle,
    required this.enabled,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: enabled,
      onChanged: onToggle,
    );
  }
}
