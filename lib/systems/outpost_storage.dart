import 'outpost_storage_stub.dart'
    if (dart.library.js_interop) 'outpost_storage_web.dart'
    if (dart.library.io) 'outpost_storage_io.dart' as impl;

/// Zero-dependency cross-platform save storage (`localStorage` on Web, JSON file on IO).
class OutpostStorage {
  const OutpostStorage._();

  static const String _saveKey = 'desert_outpost_save_v1';

  static String? readSave() => impl.readStorage(_saveKey);

  static void writeSave(String json) => impl.writeStorage(_saveKey, json);
}
