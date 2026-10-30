import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class CloudUser {
  const CloudUser({
    required this.id,
    required this.email,
    required this.username,
    required this.name,
  });

  final String id;
  final String email;
  final String username;
  final String name;

  factory CloudUser.fromJson(Map<String, dynamic> json) => CloudUser(
    id: json['id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    name: json['name'] as String,
  );
}

class CloudAuthSession {
  const CloudAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final CloudUser user;

  factory CloudAuthSession.fromJson(Map<String, dynamic> json) =>
      CloudAuthSession(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        user: CloudUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

abstract interface class AuthApi {
  Future<CloudAuthSession> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<CloudAuthSession> logIn({
    required String email,
    required String password,
  });

  Future<CloudAuthSession> refresh(String refreshToken);

  Future<void> logOut(String refreshToken);
}

class HttpAuthApi implements AuthApi {
  const HttpAuthApi({this.baseUrl = _configuredBaseUrl});

  static const _configuredBaseUrl = String.fromEnvironment(
    'MATHVERSE_API_BASE_URL',
  );
  static const _pinnedCertificateAsset = String.fromEnvironment(
    'MATHVERSE_API_CERTIFICATE_ASSET',
  );

  final String baseUrl;

  Uri _endpoint(String path) {
    final value = baseUrl.trim();
    if (value.isEmpty) {
      throw const AuthApiException(
        'Cloud accounts are not configured for this app build.',
      );
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const AuthApiException(
        'The account service needs a valid HTTPS address.',
      );
    }
    return uri.replace(
      path: '${uri.path.replaceFirst(RegExp(r'/$'), '')}$path',
      query: null,
      fragment: null,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final client = await _createHttpClient();
    try {
      final request = await client
          .postUrl(_endpoint(path))
          .timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final text = await response.transform(utf8.decoder).join();
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map<String, dynamic>
            ? decoded['detail']
            : null;
        throw AuthApiException(
          detail is String
              ? detail
              : 'Could not connect to the account service.',
          statusCode: response.statusCode,
        );
      }
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const AuthApiException(
        'The account service returned an invalid response.',
      );
    } on AuthApiException {
      rethrow;
    } on SocketException {
      throw const AuthApiException(
        'Could not reach the account service. Check your connection and try again.',
      );
    } on TimeoutException {
      throw const AuthApiException(
        'The account service took too long to respond.',
      );
    } on FormatException {
      throw const AuthApiException(
        'The account service returned an invalid response.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpClient> _createHttpClient() async {
    if (_pinnedCertificateAsset.isEmpty) {
      return HttpClient()..connectionTimeout = const Duration(seconds: 12);
    }
    final certificate = await rootBundle.load(_pinnedCertificateAsset);
    final bytes = certificate.buffer.asUint8List(
      certificate.offsetInBytes,
      certificate.lengthInBytes,
    );
    final context = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(bytes);
    return HttpClient(context: context)
      ..connectionTimeout = const Duration(seconds: 12);
  }

  @override
  Future<CloudAuthSession> signUp({
    required String name,
    required String email,
    required String password,
  }) async => CloudAuthSession.fromJson(
    await _post('/v1/auth/signup', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
    }),
  );

  @override
  Future<CloudAuthSession> logIn({
    required String email,
    required String password,
  }) async => CloudAuthSession.fromJson(
    await _post('/v1/auth/login', {
      'email': email.trim(),
      'password': password,
    }),
  );

  @override
  Future<CloudAuthSession> refresh(String refreshToken) async =>
      CloudAuthSession.fromJson(
        await _post('/v1/auth/refresh', {'refresh_token': refreshToken}),
      );

  @override
  Future<void> logOut(String refreshToken) async {
    await _post('/v1/auth/logout', {'refresh_token': refreshToken});
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract interface class AuthTokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> save(CloudAuthSession session);
  Future<void> clear();
}
