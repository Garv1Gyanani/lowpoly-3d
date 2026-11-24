import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _lsGetItem(JSString key);

@JS('window.localStorage.setItem')
external void _lsSetItem(JSString key, JSString value);

String? readStorage(String key) {
  try {
    return _lsGetItem(key.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

void writeStorage(String key, String value) {
  try {
    _lsSetItem(key.toJS, value.toJS);
  } catch (_) {
    // Ignore private-browsing quota errors gracefully.
  }
}
