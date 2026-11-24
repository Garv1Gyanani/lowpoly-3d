final Map<String, String> _mem = <String, String>{};

String? readStorage(String key) => _mem[key];

void writeStorage(String key, String value) {
  _mem[key] = value;
}
