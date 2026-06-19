import 'package:flutter/material.dart';
import 'package:report_admin_app/api/api_client.dart';
import 'package:report_admin_app/api/token_storage.dart';
import 'package:report_admin_app/pages/login_page.dart';
import 'package:report_admin_app/pages/product_list_page.dart';

/// 전역 네비게이터 키. 토큰 만료(401) 시 어디서든 로그인 화면으로 전환하기 위해 사용.
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ApiClient.instance.onUnauthorized = () {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  };

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Report Admin',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routes: {
        '/login': (_) => LoginPage(
          onAuthenticated: () => navigatorKey.currentState!
              .pushNamedAndRemoveUntil('/home', (_) => false),
        ),
        '/home': (_) => const ProductListPage(),
      },
      home: const _AuthGate(),
    );
  }
}

/// 앱 시작 시 토큰 보유 여부로 홈/로그인 화면을 분기한다.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: TokenStorage.instance.hasToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data ?? false) return const ProductListPage();
        return LoginPage(
          onAuthenticated: () => navigatorKey.currentState!
              .pushNamedAndRemoveUntil('/home', (_) => false),
        );
      },
    );
  }
}
