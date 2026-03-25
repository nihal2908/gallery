// import 'dart:io';
// import 'dart:typed_data';

// import 'package:pointycastle/export.dart';

// class EncryptParams {
//   final String inputPath;
//   final String outputPath;
//   final Uint8List keyBytes;

//   EncryptParams({
//     required this.inputPath,
//     required this.outputPath,
//     required this.keyBytes,
//   });
// }

// // Future<void> encryptFileWorker(EncryptParams params) async {
// //   final inputFile = File(params.inputPath);
// //   final outputFile = File(params.outputPath);

// //   final key = Key(params.keyBytes);
// //   final iv = IV.fromSecureRandom(16);

// //   final encrypter = Encrypter(AES(key, mode: AESMode.ctr));

// //   // final input = await inputFile.open();
// //   // final output = outputFile.openWrite();

// //   // // write IV
// //   // output.add(iv.bytes);

// //   // const chunkSize = 256 * 1024;

// //   // while (true) {
// //   //   final chunk = await input.read(chunkSize);
// //   //   if (chunk.isEmpty) break;

// //   //   final encrypted = encrypter.encryptBytes(chunk, iv: iv).bytes;
// //   //   output.add(encrypted);
// //   // }

// //   // await input.close();
// //   // await output.close();
// //   final bytes = await inputFile.readAsBytes();

// //   final encrypted = encrypter.encryptBytes(bytes, iv: iv);

// //   await outputFile.writeAsBytes(Uint8List.fromList(iv.bytes + encrypted.bytes));
// // }

// Future<void> encryptFileWorker(EncryptParams params) async {
//   final inputFile = File(params.inputPath);
//   final outputFile = File(params.outputPath);

//   final iv = secureRandomBytes(16);

//   final cipher = CTRStreamCipher(AESEngine())
//     ..init(true, ParametersWithIV(KeyParameter(params.keyBytes), iv));

//   final input = await inputFile.open();
//   final output = outputFile.openWrite();

//   // write IV
//   output.add(iv);

//   final start = DateTime.now();

//   final chunkSize = 1024 * 1024;

//   while (true) {
//     final chunk = await input.read(chunkSize);
//     if (chunk.isEmpty) break;

//     final encrypted = cipher.process(chunk);
//     output.add(encrypted);
//   }

//   print(
//     'Encryption completed in ${DateTime.now().difference(start).inSeconds} seconds',
//   );

//   await output.close();
// }

// Uint8List secureRandomBytes(int length) {
//   final rnd = SecureRandom("Fortuna")
//     ..seed(
//       KeyParameter(
//         Uint8List.fromList(
//           List.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256),
//         ),
//       ),
//     );

//   return rnd.nextBytes(length);
// }
