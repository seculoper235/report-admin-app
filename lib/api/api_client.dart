import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:report_admin_app/api/api_config.dart';
import 'package:report_admin_app/api/token_storage.dart';

/// 모든 인증 API 호출의 공통 진입점.
///
/// - 매 요청에 저장된 access 토큰을 `Authorization: Bearer ...` 헤더로 주입한다.
/// - 401 응답을 받으면 refresh 토큰으로 1회 재발급(`/api/auth/reissue`)을 시도하고
///   성공 시 원요청을 1회 재시도한다. 재발급도 실패하면 토큰을 비우고
///   [onUnauthorized] 콜백으로 로그인 화면 전환을 알린다.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();

  /// 재인증 불가(refresh 실패/만료) 시 호출. main.dart에서 로그인 화면 전환에 연결.
  void Function()? onUnauthorized;

  Future<bool>? _reissuing;

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) =>
      _send('GET', uri, headers: headers);

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _send('POST', uri, headers: headers, body: body);

  Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _send('PUT', uri, headers: headers, body: body);

  Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => _send('PATCH', uri, headers: headers, body: body);

  Future<http.Response> delete(Uri uri, {Map<String, String>? headers}) =>
      _send('DELETE', uri, headers: headers);

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    bool retryOn401 = true,
  }) async {
    final res = await _dispatch(method, uri, headers: headers, body: body);

    if (res.statusCode == 401 && retryOn401) {
      final refreshed = await _reissue();
      if (refreshed) {
        return _send(method, uri, headers: headers, body: body, retryOn401: false);
      }
      await TokenStorage.instance.clear();
      onUnauthorized?.call();
    }

    return res;
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final token = await TokenStorage.instance.accessToken();
    final merged = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    switch (method) {
      case 'GET':
        return _client.get(uri, headers: merged);
      case 'POST':
        return _client.post(uri, headers: merged, body: body);
      case 'PUT':
        return _client.put(uri, headers: merged, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: merged, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: merged);
      default:
        throw ArgumentError('지원하지 않는 메서드: $method');
    }
  }

  Future<bool> _reissue() {
    return _reissuing ??= _doReissue().whenComplete(() => _reissuing = null);
  }

  Future<bool> _doReissue() async {
    final refresh = await TokenStorage.instance.refreshToken();
    if (refresh == null) return false;

    try {
      final res = await _client.post(
        Uri.parse('$apiBaseUrl/api/auth/reissue'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (res.statusCode != 200) return false;

      final decoded =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final tokens = decoded['body'] as Map<String, dynamic>?;
      if (tokens == null) return false;

      await TokenStorage.instance.save(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
