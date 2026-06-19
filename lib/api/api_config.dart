/// 관리자 API 서버 base URL.
/// 빌드/실행 시 --dart-define=API_BASE_URL=... 로 주입한다. 미지정 시 로컬 개발 기본값 사용.
///
/// - 로컬(시뮬레이터/데스크톱): 기본값 http://localhost:8080
/// - 운영(실기기 → 클라우드 VM): Tailscale tailnet IP로 주입
///   예) flutter run --dart-define=API_BASE_URL=http://100.x.x.x:8080
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);
