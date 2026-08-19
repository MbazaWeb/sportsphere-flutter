import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'web_kv_stub.dart' if (dart.library.html) 'web_kv_web.dart';

class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ss_access_token';
  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    if (kIsWeb) return webKvGet(_key);
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return webKvGet(_key);
    }
  }

  Future<void> write(String token) async {
    if (kIsWeb) {
      webKvSet(_key, token);
      return;
    }
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      webKvSet(_key, token);
    }
  }

  Future<void> clear() async {
    if (kIsWeb) {
      webKvRemove(_key);
      return;
    }
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      webKvRemove(_key);
    }
  }
}
