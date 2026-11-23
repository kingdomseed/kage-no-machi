import 'dart:io' show File, exit, stderr, stdout;

void captureWriteStdout(String line) => stdout.writeln(line);

void captureWriteStderr(String line) => stderr.writeln(line);

Future<void> captureFlushStdout() => stdout.flush();

Never captureExit(int code) => exit(code);

Future<void> captureWriteFileBytes(String filePath, List<int> bytes) async {
  await File(filePath).writeAsBytes(bytes, flush: true);
}
