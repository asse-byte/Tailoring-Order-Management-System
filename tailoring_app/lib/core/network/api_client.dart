import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Typed API failure carrying the HTTP status and the server's French
/// message. 403 never crashes the app — screens show the message.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

/// Central HTTP client: resolves the base URL, attaches the JWT from
/// secure storage, decodes JSON, maps errors, and signals session expiry
/// (401) so the app can return to the login screen.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  String? _token;
  bool _tokenLoaded = false;

  /// Called when the server answers 401 on an authenticated call —
  /// wired to AuthProvider so the router falls back to /login.
  VoidCallback? onSessionExpired;

  /// API origin. Override at build time: --dart-define=API_URL=https://…
  static String get baseUrl {
    const String fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000'; // Android emulator → host machine
    }
    return 'http://localhost:3000';
  }

  Future<String?> get token async {
    if (!_tokenLoaded) {
      _token = await _storage.read(key: _tokenKey);
      _tokenLoaded = true;
    }
    return _token;
  }

  Future<void> setToken(String? value) async {
    _token = value;
    _tokenLoaded = true;
    if (value == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: value);
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);
  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    Uri uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    final String? jwt = await token;
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      if (jwt != null) 'Authorization': 'Bearer $jwt',
    };

    http.Response res;
    try {
      final http.Request req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 15)));
    } on TimeoutException {
      throw ApiException(0, 'Le serveur ne répond pas. Vérifiez la connexion.');
    } catch (_) {
      throw ApiException(0, 'Connexion impossible au serveur.');
    }

    if (res.statusCode == 204) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode == 401 && path != '/api/auth/login') {
      await setToken(null);
      onSessionExpired?.call();
    }
    if (res.statusCode >= 400) {
      final String message = (decoded is Map && decoded['error'] is String)
          ? decoded['error'] as String
          : 'Erreur serveur (${res.statusCode}).';
      throw ApiException(res.statusCode, message);
    }
    return decoded;
  }
}
