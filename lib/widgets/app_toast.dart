import 'package:flutter/material.dart';
import 'package:report_admin_app/main.dart';

/// 토스트 종류(색상/아이콘 결정).
enum ToastType { success, error, info }

/// 앱 공통 토스트.
///
/// 전역 네비게이터의 Overlay에 띄우므로 Scaffold 없이도, 화면 전환(pop) 직후에도 표시된다.
/// 사용: `AppToast.success('등록되었습니다')` / `AppToast.error('실패했습니다')`.
class AppToast {
  AppToast._();

  static OverlayEntry? _entry;

  static void success(String message) => _show(message, ToastType.success);
  static void error(String message) => _show(message, ToastType.error);
  static void info(String message) => _show(message, ToastType.info);

  static void _show(String message, ToastType type) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    // 이전 토스트가 떠 있으면 교체.
    _entry?.remove();
    final entry = OverlayEntry(
      builder: (_) => _ToastView(message: message, type: type),
    );
    _entry = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (_entry == entry) {
        entry.remove();
        _entry = null;
      }
    });
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message, required this.type});

  final String message;
  final ToastType type;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  (IconData, Color) get _style => switch (widget.type) {
    ToastType.success => (Icons.check_circle, const Color(0xFF2E7D32)),
    ToastType.error => (Icons.error, const Color(0xFFC62828)),
    ToastType.info => (Icons.info, const Color(0xFF37474F)),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style;
    final media = MediaQuery.of(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: media.padding.bottom + 40,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _controller,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            ),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
