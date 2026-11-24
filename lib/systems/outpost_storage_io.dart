import 'dart:io';

File _resolveSaveFile(String key) {
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.systemTemp.path;
  return File('$home${Platform.pathSeparator}.$key.json');
}

String? readStorage(String key) {
  if (Platform.environment['FLUTTER_TEST'] == 'true') return null;
  try {
    final file = _resolveSaveFile(key);
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  } catch (_) {
    return null;
  }
}

void writeStorage(String key, String value) {
  if (Platform.environment['FLUTTER_TEST'] == 'true') return;
  try {
    final file = _resolveSaveFile(key);
    file.writeAsStringSync(value, flush: false);
  } catch (_) {
    // Ignore read-only filesystem errors gracefully.
  }
}
