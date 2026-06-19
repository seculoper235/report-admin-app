import 'package:flutter/material.dart';
import 'package:report_admin_app/api/auth_api.dart';
import 'package:report_admin_app/main.dart';
import 'package:report_admin_app/pages/gift_register_page.dart';
import 'package:report_admin_app/pages/product_register_page.dart';

/// 관리자 홈. 상품 등록 / 기프티콘 등록 탭.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthApi.instance.logout();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '상품 등록'),
            Tab(text: '기프티콘 등록'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ProductRegisterPage(),
          GiftRegisterPage(),
        ],
      ),
    );
  }
}
