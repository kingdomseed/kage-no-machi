import 'package:flutter/foundation.dart' show debugPrint;

void captureWriteStdout(String line) => debugPrint(line);

void captureWriteStderr(String line) => debugPrint(line);

Future<void> captureFlushStdout() => Future<void>.value();

Never captureExit(int code) =>
    throw UnsupportedError('exit($code) is native-only.');

Future<void> captureWriteFileBytes(String filePath, List<int> bytes) =>
    Future<void>.error(UnsupportedError('File capture is native-only.'));
