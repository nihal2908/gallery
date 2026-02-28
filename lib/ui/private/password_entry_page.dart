// import 'package:flutter/material.dart';

// import '../../dependency_injector.dart';
// import '../../services/authentication_service.dart';

// enum PasswordEntryPageMode { setPassword, changePassword, authenticate }

// class PasswordEntryPage extends StatefulWidget {
//   final PasswordEntryPageMode mode;
//   final bool popOnSuccess;
//   const PasswordEntryPage({
//     super.key,
//     required this.mode,
//     this.popOnSuccess = true,
//   });

//   @override
//   State<PasswordEntryPage> createState() => _PasswordEntryPageState();
// }

// class _PasswordEntryPageState extends State<PasswordEntryPage> {
//   final TextEditingController _passwordController = TextEditingController();
//   String status = '', title = '';
//   late final AuthenticationService _authenticationService;
//   late final PasswordEntryPageMode mode;
//   int counter = 0;
//   String? prevPass;

//   @override
//   void initState() {
//     mode = widget.mode;
//     _authenticationService = sl<AuthenticationService>();
//     if (mode == PasswordEntryPageMode.setPassword) {
//       title = 'Set Password for hidden photos and videos.';
//     } else if (mode == PasswordEntryPageMode.changePassword) {
//       title = 'Change Password for hidden photos and videos.';
//       status = 'Enter old password';
//     } else {
//       title = 'Enter Password to view hidden photos and videos.';
//     }
//     setState(() {});
//     super.initState();
//   }

//   void submit(String password) async {
//     print('Called submit');
//     if (widget.mode == PasswordEntryPageMode.setPassword) {
//       if (counter == 0) {
//         prevPass = password;
//         status = 'Re-enter the password.';
//         counter++;
//         _passwordController.clear();
//       } else if (counter == 1 && password == prevPass) {
//         await _authenticationService.setPassword(password);
//         if (widget.popOnSuccess) Navigator.pop(context, true);
//       } else {
//         counter = 0;
//         status = 'Password didn\'t match. Please retry.';
//         _passwordController.clear();
//       }
//     } else if (widget.mode == PasswordEntryPageMode.changePassword) {
//       if (counter == 0) {
//         if (await _authenticationService.isPasswordCorrect(password)) {
//           status = 'Enter new password';
//           counter++;
//         } else {
//           status = 'Incorrect password, try again.';
//           counter = 0;
//         }
//         _passwordController.clear();
//       } else if (counter == 1) {
//         prevPass = password;
//         status = 'Re-enter new password.';
//         counter++;
//         _passwordController.clear();
//       } else if (counter == 2 && password == prevPass) {
//         await _authenticationService.setPassword(password);
//         if (widget.popOnSuccess) Navigator.pop(context, true);
//       } else {
//         counter--;
//         status = 'Password didn\'t match. Enter new password.';
//         _passwordController.clear();
//       }
//     } else {
//       final bool correct = await _authenticationService.authenticate(password);
//       if (!correct) {
//         status = 'Incorrect password, try again.';
//         _passwordController.clear();
//         setState(() {});
//       } else if (widget.popOnSuccess) {
//         Navigator.pop(context, true);
//       }
//     }
//     if (mounted) setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 60),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.end,
//           children: [
//             Text(status, style: TextStyle(fontWeight: FontWeight.bold)),
//             const SizedBox(height: 20),
//             const Text('Enter Password to Access Hidden Album'),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: TextField(
//                 controller: _passwordController,
//                 keyboardType: TextInputType.number,
//                 obscureText: true,
//                 maxLength: 6,
//                 onChanged: (value) => value.isNotEmpty && value.length == 6
//                     ? submit(value)
//                     : null,
//                 decoration: const InputDecoration(border: OutlineInputBorder()),
//               ),
//             ),
//             GridView.count(
//               shrinkWrap: true,
//               crossAxisCount: 3,
//               mainAxisSpacing: 8,
//               crossAxisSpacing: 8,
//               padding: const EdgeInsets.symmetric(horizontal: 32),
//               children: List.generate(12, (index) {
//                 final displayText = index < 9
//                     ? '${index + 1}'
//                     : (index == 9 ? 'Clear' : (index == 10 ? '0' : 'Back'));
//                 return ElevatedButton(
//                   onPressed: () {
//                     if (index == 9) {
//                       _passwordController.clear();
//                     } else if (index == 10) {
//                       _passwordController.text += '0';
//                     } else if (index == 11) {
//                       if (_passwordController.text.isNotEmpty) {
//                         _passwordController.text = _passwordController.text
//                             .substring(0, _passwordController.text.length - 1);
//                       }
//                     } else {
//                       _passwordController.text += (index + 1).toString();
//                     }
//                   },
//                   child: Text(displayText),
//                 );
//               }),
//             ),
//             SizedBox(height: 50),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import '../../dependency_injector.dart';
import '../../services/authentication_service.dart';

enum PasswordEntryPageMode { setPassword, changePassword, authenticate }

class PasswordEntryPage extends StatefulWidget {
  final PasswordEntryPageMode mode;
  final bool popOnSuccess;

  const PasswordEntryPage({
    super.key,
    required this.mode,
    this.popOnSuccess = true,
  });

  @override
  State<PasswordEntryPage> createState() => _PasswordEntryPageState();
}

class _PasswordEntryPageState extends State<PasswordEntryPage> {
  late final AuthenticationService _authenticationService;

  String _pin = "";
  String status = "";
  String title = "";
  int counter = 0;
  String? prevPass;

  @override
  void initState() {
    super.initState();
    _authenticationService = sl<AuthenticationService>();

    switch (widget.mode) {
      case PasswordEntryPageMode.setPassword:
        title = "Set Password for hidden photos and videos.";
        break;
      case PasswordEntryPageMode.changePassword:
        title = "Change Password for hidden photos and videos.";
        status = "Enter old password";
        break;
      case PasswordEntryPageMode.authenticate:
        title = "Enter Password to view hidden photos and videos.";
        break;
    }
  }

  void _addDigit(String digit) {
    if (_pin.length >= 6) return;

    setState(() {
      _pin += digit;
    });

    if (_pin.length == 6) {
      submit(_pin);
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;

    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _clearPin() {
    setState(() {
      _pin = "";
    });
  }

  Future<void> submit(String password) async {
    if (widget.mode == PasswordEntryPageMode.setPassword) {
      if (counter == 0) {
        prevPass = password;
        status = "Re-enter the password.";
        counter++;
        _clearPin();
      } else if (counter == 1 && password == prevPass) {
        await _authenticationService.setPassword(password);
        if (widget.popOnSuccess) Navigator.pop(context, true);
      } else {
        counter = 0;
        status = "Password didn't match. Please retry.";
        _clearPin();
      }
    } else if (widget.mode == PasswordEntryPageMode.changePassword) {
      if (counter == 0) {
        if (await _authenticationService.isPasswordCorrect(password)) {
          status = "Enter new password";
          counter++;
        } else {
          status = "Incorrect password, try again.";
        }
        _clearPin();
      } else if (counter == 1) {
        prevPass = password;
        status = "Re-enter new password.";
        counter++;
        _clearPin();
      } else if (counter == 2 && password == prevPass) {
        await _authenticationService.setPassword(password);
        if (widget.popOnSuccess) Navigator.pop(context, true);
      } else {
        counter = 1;
        status = "Password didn't match. Enter new password.";
        _clearPin();
      }
    } else {
      final bool correct = await _authenticationService.authenticate(password);

      if (!correct) {
        status = "Incorrect password, try again.";
        _clearPin();
      } else {
        if (widget.popOnSuccess) {
          Navigator.pop(context, true);
        }
      }
    }

    if (mounted) setState(() {});
  }

  Widget _buildPinBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        bool isFilled = index < _pin.length;

        return SizedBox.square(
          dimension: MediaQuery.of(context).size.width * 0.1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFilled ? Colors.blue : Colors.grey,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: isFilled
                ? const Icon(Icons.circle, size: 14)
                : const SizedBox(),
          ),
        );
      }),
    );
  }

  Widget _buildKeypadButton(String text, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
      ),
      onPressed: onTap,
      child: Text(text, style: const TextStyle(fontSize: 20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(status, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 30),
            _buildPinBoxes(),
            const SizedBox(height: 40),

            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              children: [
                ...List.generate(9, (index) {
                  return _buildKeypadButton(
                    "${index + 1}",
                    () => _addDigit("${index + 1}"),
                  );
                }),
                _buildKeypadButton("Clear", _clearPin),
                _buildKeypadButton("0", () => _addDigit("0")),
                _buildKeypadButton("Back", _removeDigit),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
