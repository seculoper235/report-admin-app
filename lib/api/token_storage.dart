import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT access/refresh 토큰을 기기 보안 저장소에 보관한다.
/// 서버 인증(`/api/auth/*`)에서 받은 토큰의 단일 보관소.
class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> accessToken() => _storage.read(key: _accessKey);

  Future<String?> refreshToken() => _storage.read(key: _refreshKey);

  /// 로그인 상태 여부(access 토큰 보유 여부)로 앱 시작 분기에 사용.
  Future<bool> hasToken() async => (await accessToken()) != null;

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
