import 'package:flutter/material.dart';
import 'package:report_admin_app/api/admin_api.dart';
import 'package:report_admin_app/api/auth_api.dart';
import 'package:report_admin_app/main.dart';
import 'package:report_admin_app/pages/gift_list_page.dart';
import 'package:report_admin_app/pages/product_register_page.dart';
import 'package:report_admin_app/widgets/app_toast.dart';

/// 관리자 홈. 등록된 상품 + 재고를 카드형 리스트로 보여준다.
/// - 카드 탭: 해당 상품의 기프티콘 목록 화면으로 이동.
/// - 카드 길게 누르기: 상품 수정.
/// - 카드 오른쪽 스와이프: 상품 삭제(재고/처리중이 모두 0일 때만).
/// - 플로팅 버튼: 상품 등록 화면으로 이동.
class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  List<Product>? _products;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await AdminApi.instance.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (_products == null) {
        setState(() => _error = msg);
      } else {
        AppToast.error(msg);
      }
    }
  }

  Future<void> _logout() async {
    await AuthApi.instance.logout();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _openProductRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductRegisterPage()),
    );
    _load();
  }

  Future<void> _openGiftList(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GiftListPage(product: product)),
    );
    _load();
  }

  Future<void> _openProductEdit(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductRegisterPage(product: product)),
    );
    _load();
  }

  /// 스와이프 삭제 확정 여부. 재고/처리중이 0이 아니면 거부.
  Future<bool> _confirmDelete(Product product) async {
    if (!product.deletable) {
      AppToast.error('재고 또는 처리중인 기프티콘이 남아 있어 삭제할 수 없습니다.');
      return false;
    }
    try {
      await AdminApi.instance.deleteProduct(product.productId);
      return true;
    } catch (e) {
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  void _onDismissed(Product product) {
    setState(() {
      _products?.removeWhere((p) => p.productId == product.productId);
    });
    AppToast.success('${product.name}이(가) 삭제되었습니다');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상품'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openProductRegister,
        tooltip: '상품 등록',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_products == null && _error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    final products = _products;
    if (products == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (products.isEmpty) {
      return const _EmptyView();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        return Dismissible(
          key: ValueKey(product.productId),
          direction: DismissDirection.endToStart, // 왼쪽으로 스와이프
          background: const _DeleteBackground(),
          confirmDismiss: (_) => _confirmDelete(product),
          onDismissed: (_) => _onDismissed(product),
          child: _ProductCard(
            product: product,
            onTap: () => _openGiftList(product),
            onLongPress: () => _openProductEdit(product),
          ),
        );
      },
    );
  }
}

/// 스와이프 시 카드 뒤로 드러나는 삭제 배경(iOS 스타일).
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline,
              color: Theme.of(context).colorScheme.onError),
          const SizedBox(width: 8),
          Text(
            '삭제',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onError,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onLongPress,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumbnail(imageUrl: product.imageUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (product.brand?.isNotEmpty ?? false)
                          ? product.brand!
                          : '브랜드 미지정',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '재고 ${product.stock}개',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF41A343), // 연한 초록
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '처리중 ${product.processing}개',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final placeholder = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: (url == null || url.isEmpty)
          ? placeholder
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  width: size,
                  height: size,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 160),
        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Center(child: Text('등록된 상품이 없습니다.')),
        SizedBox(height: 8),
        Center(child: Text('+ 버튼으로 상품을 등록하세요.')),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 160),
        const Center(child: Icon(Icons.error_outline, size: 56, color: Colors.grey)),
        const SizedBox(height: 16),
        Center(child: Text(message, textAlign: TextAlign.center)),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('재시도'),
          ),
        ),
      ],
    );
  }
}
