import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:report_admin_app/api/api_client.dart';
import 'package:report_admin_app/api/api_config.dart';
import 'package:report_admin_app/api/token_storage.dart';

/// 인증 API. (`/api/auth/*`)
///
/// 관리자 계정은 DB에서 role=ADMIN 으로 승격된 계정이어야 관리자 API 호출이 가능하다.
class AuthApi {
  AuthApi._();

  static final AuthApi instance = AuthApi._();

  final http.Client _client = http.Client();

  /// 로그인. (POST /api/auth/login) 성공 시 access/refresh 토큰을 저장한다.
  Future<void> login(String email, String password) async {
    final res = await _client.post(
      Uri.parse('$apiBaseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, '로그인 실패'));
    }

    final decoded =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final tokens = decoded['body'] as Map<String, dynamic>;
    await TokenStorage.instance.save(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
  }

  /// 로그아웃. (POST /api/auth/logout) 서버 블랙리스트 등록 후 로컬 토큰을 비운다.
  Future<void> logout() async {
    try {
      await ApiClient.instance.post(Uri.parse('$apiBaseUrl/api/auth/logout'));
    } catch (_) {
      // 네트워크 오류여도 로컬 로그아웃은 진행.
    } finally {
      await TokenStorage.instance.clear();
    }
  }

  String _errorMessage(http.Response res, String fallback) {
    try {
      final decoded =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final message = decoded['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {
      // 본문 파싱 실패 시 fallback 사용.
    }
    return '$fallback (HTTP ${res.statusCode})';
  }
}
