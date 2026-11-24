import 'dart:io';

File _resolveSaveFile(String key) {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    // On iOS/macOS sandboxes, $HOME itself can be read-only while $HOME/Documents is writable.
    if (Platform.isIOS || Platform.isMacOS) {
      final docs = Directory('$home/Documents');
      if (docs.existsSync()) {
        return File('${docs.path}${Platform.pathSeparator}.$key.json');
      }
    }
    return File('$home${Platform.pathSeparator}.$key.json');
  }
  return File('${Directory.systemTemp.path}${Platform.pathSeparator}.$key.json');
}

String? readStorage(String key) {
  try {
    final file = _resolveSaveFile(key);
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  } catch (_) {
    return null;
  }
}

void writeStorage(String key, String value) {
  try {
    final file = _resolveSaveFile(key);
    // Async write prevents 6-second autosaves from stalling the UI frame thread.
    file.writeAsString(value, flush: false).catchError((_) => file);
  } catch (_) {
    // Ignore read-only environments cleanly.
  }
}
