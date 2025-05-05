// import 'dart:convert';
// import 'dart:io';
//
// class TellTalePipeWriter {
//   static const String pipePath = r'C:\tmp\tell_tales';
//   File? _pipe;
//   IOSink? _writer;
//   Directory? _directory;
//
//   int _lastHighbeam = 0;
//   int _lastIndicators = 0;
//   int _lastDPads = 0;
//
//   Future<void> initialize() async {
//     try {
//       // Ensure the directory exists
//       _directory = Directory(r'C:\tmp');
//       if (!await _directory!.exists()) {
//         await _directory!.create(recursive: true);
//       }
//
//       // Create or open the file
//       _pipe = File(pipePath);
//       if (!await _pipe!.exists()) {
//         await _pipe!.create();
//       }
//
//       // Open in write mode to replace the previous value
//       _writer = _pipe!.openWrite(mode: FileMode.write);
//     } catch (e) {
//       print('Error initializing file: $e');
//       rethrow;
//     }
//   }
//
//   Future<void> updateHighbeam(int value) async {
//     print('HighBeam $value');
//     if (value == _lastHighbeam) return;
//     await _writeValue('highbeam', value);
//     _lastHighbeam = value;
//   }
//
//   Future<void> updateIndicators(int value) async {
//     print('Indicators $value');
//
//     if (value == _lastIndicators) return;
//     await _writeValue('indicators', value);
//     _lastIndicators = value;
//   }
//
//   Future<void> updateDPads(int value) async {
//     print('DPad $value');
//
//     if (value == _lastDPads) return;
//     await _writeValue('d_pads', value);
//     _lastDPads = value;
//   }
//
//   Future<void> _writeValue(String key, int value) async {
//     if (_writer == null) {
//       throw Exception('File writer not initialized. Call initialize() first.');
//     }
//
//     final data = {
//       'highbeam': _lastHighbeam,
//       'indicators': _lastIndicators,
//       'd_pads': _lastDPads,
//     };
//
//     data[key] = value;
//
//     try {
//       // Close the current writer to ensure the file is not locked
//       await _writer!.flush();
//       await _writer!.close();
//
//       // Reopen the file in write mode to overwrite the content
//       _writer = _pipe!.openWrite(mode: FileMode.write);
//
//       final jsonString = '${json.encode(data)}\n';
//       _writer!.write(jsonString);
//       await _writer!.flush();
//     } catch (e) {
//       print('Error writing to file: $e');
//       // If we lost the file connection, try to reestablish it
//       if (e is FileSystemException) {
//         await _reconnect();
//       }
//       rethrow;
//     }
//   }
//
//   Future<void> _reconnect() async {
//     try {
//       await dispose();
//       await initialize();
//     } catch (e) {
//       print('Error reconnecting: $e');
//     }
//   }
//
//   Future<void> dispose() async {
//     try {
//       await _writer?.flush();
//       await _writer?.close();
//     } catch (e) {
//       print('Error disposing file writer: $e');
//     }
//   }
// }