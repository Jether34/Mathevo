import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_api.dart';

class SecureAuthTokenStore implements AuthTokenStore {
  const SecureAuthTokenStore();

  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'mathverse.cloud.accessToken';
  static const _refreshKey = 'mathverse.cloud.refreshToken';

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> save(CloudAuthSession session) async {
    await _storage.write(key: _accessKey, value: session.accessToken);
    await _storage.write(key: _refreshKey, value: session.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
