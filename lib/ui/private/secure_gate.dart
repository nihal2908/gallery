import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

import '../../services/authentication_service.dart';
import 'password_entry_page.dart';

class SecureGate extends StatefulWidget {
  final Widget child;
  final AuthenticationService authService;

  const SecureGate({super.key, required this.child, required this.authService});

  @override
  State<SecureGate> createState() => _SecureGateState();
}

class _SecureGateState extends State<SecureGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ScreenProtector.preventScreenshotOn();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ScreenProtector.preventScreenshotOff();
    widget.authService.revokeAccess();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      widget.authService.revokeAccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.authService.isAuthenticated,
      builder: (context, authenticated, _) {
        if (authenticated) {
          return widget.child;
        } else {
          return PasswordEntryPage(
            mode: PasswordEntryPageMode.authenticate,
            popOnSuccess: false,
          );
        }
      },
    );
  }
}
