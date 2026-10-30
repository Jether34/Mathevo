import 'package:mathevo/auth_api.dart';

class FakeAuthApi implements AuthApi {
  FakeAuthApi({bool registered = false}) : _registered = registered {
    if (registered) {
      _email = 'saved@example.com';
      _password = 'password123';
      _name = 'Saved learner';
    }
  }

  bool _registered;
  String? _email;
  String? _password;
  String? _name;

  CloudAuthSession _session() => CloudAuthSession(
    accessToken: 'access-test-token',
    refreshToken: 'refresh-test-token',
    expiresAt: DateTime.utc(2030),
    user: CloudUser(
      id: '00000000-0000-4000-8000-000000000001',
      email: _email!,
      username: 'learner_test',
      name: _name!,
    ),
  );

  @override
  Future<CloudAuthSession> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_registered && email.toLowerCase() == _email) {
      throw const AuthApiException(
        'An account with this email already exists. Log in instead.',
        statusCode: 409,
      );
    }
    _registered = true;
    _email = email.toLowerCase();
    _password = password;
    _name = name;
    return _session();
  }

  @override
  Future<CloudAuthSession> logIn({
    required String email,
    required String password,
  }) async {
    if (!_registered ||
        email.toLowerCase() != _email ||
        password != _password) {
      throw const AuthApiException(
        'Email or password is incorrect.',
        statusCode: 401,
      );
    }
    return _session();
  }

  @override
  Future<CloudAuthSession> refresh(String refreshToken) async => _session();

  @override
  Future<void> logOut(String refreshToken) async {}
}

class MemoryAuthTokenStore implements AuthTokenStore {
  MemoryAuthTokenStore({String? accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  String? _accessToken;
  String? _refreshToken;

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> save(CloudAuthSession session) async {
    _accessToken = session.accessToken;
    _refreshToken = session.refreshToken;
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}
