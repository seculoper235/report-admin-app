import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:report_admin_app/api/admin_api.dart';
import 'package:report_admin_app/pages/gift_edit_page.dart';
import 'package:report_admin_app/pages/gift_register_page.dart';

/// 특정 상품의 기프티콘 재고 목록. 각 항목은 상태/유효기간만 표시한다.
/// - 항목 탭: 기프티콘 수정(유효기간만).
/// - 플로팅 버튼: 해당 상품의 기프티콘 등록.
class GiftListPage extends StatefulWidget {
  const GiftListPage({super.key, required this.product});

  final Product product;

  @override
  State<GiftListPage> createState() => _GiftListPageState();
}

class _GiftListPageState extends State<GiftListPage> {
  late Future<List<GiftInventory>> _codesFuture;

  Future<List<GiftInventory>> _loadCodes() =>
      AdminApi.instance.fetchCodes(widget.product.productId);

  @override
  void initState() {
    super.initState();
    _codesFuture = _loadCodes();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final future = _loadCodes();
    setState(() {
      _codesFuture = future;
    });
    await future;
  }

  Future<void> _openRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GiftRegisterPage(initialProduct: widget.product),
      ),
    );
    _refresh();
  }

  Future<void> _openEdit(GiftInventory gift) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GiftEditPage(product: widget.product, gift: gift),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product.name)),
      floatingActionButton: FloatingActionButton(
        onPressed: _openRegister,
        tooltip: '기프티콘 등록',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<GiftInventory>>(
          future: _codesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                message: snapshot.error
                    .toString()
                    .replaceFirst('Exception: ', ''),
                onRetry: _refresh,
              );
            }

            final codes = snapshot.data ?? const <GiftInventory>[];
            if (codes.isEmpty) {
              return const _EmptyView();
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: codes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _GiftTile(
                gift: codes[index],
                onTap: () => _openEdit(codes[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.gift, required this.onTap});

  final GiftInventory gift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final validText = gift.validUntil == null
        ? '유효기간 없음'
        : '유효기간 ${DateFormat('yyyy-MM-dd').format(gift.validUntil!)}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        // 상태 칩을 고정 폭으로 감싸 유효기간 텍스트 위치가 일정하도록 한다.
        leading: SizedBox(
          width: 76,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _StatusChip(status: gift.status),
          ),
        ),
        title: Text(validText),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final GiftStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (status) {
      GiftStatus.available => (scheme.primaryContainer, scheme.onPrimaryContainer),
      GiftStatus.reserved => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      GiftStatus.issued => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      GiftStatus.unknown => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
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
        Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Center(child: Text('등록된 기프티콘이 없습니다.')),
        SizedBox(height: 8),
        Center(child: Text('+ 버튼으로 기프티콘을 등록하세요.')),
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
