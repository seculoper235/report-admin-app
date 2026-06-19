import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:report_admin_app/api/admin_api.dart';
import 'package:report_admin_app/widgets/app_toast.dart';

/// 기프티콘 수정 화면. 유효기간만 수정 가능하며, 나머지 필드는 모두 비활성화 상태다.
/// (PATCH /api/admin/products/{id}/codes/{codeId})
class GiftEditPage extends StatefulWidget {
  const GiftEditPage({
    super.key,
    required this.product,
    required this.gift,
  });

  final Product product;
  final GiftInventory gift;

  @override
  State<GiftEditPage> createState() => _GiftEditPageState();
}

class _GiftEditPageState extends State<GiftEditPage> {
  DateTime? _validUntil;
  bool _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _validUntil = widget.gift.validUntil;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _validUntil ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      await AdminApi.instance.updateCode(
        widget.product.productId,
        widget.gift.giftInventoryId,
        validUntil: _validUntil == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_validUntil!),
      );
      if (!mounted) return;
      AppToast.success('기프티콘이 수정되었습니다');
      Navigator.of(context).pop(true); // 목록 갱신 신호
    } catch (e) {
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기프티콘 수정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 비활성화 — 상품
            TextFormField(
              enabled: false,
              initialValue: widget.product.name,
              decoration: const InputDecoration(
                labelText: '상품',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 비활성화 — 상태
            TextFormField(
              enabled: false,
              initialValue: widget.gift.status.label,
              decoration: const InputDecoration(
                labelText: '상태',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 수정 가능 — 유효기간 (기프티콘 등록 화면과 동일한 필드)
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(
                _validUntil == null
                    ? '유효기간 선택(선택)'
                    : DateFormat('yyyy-MM-dd').format(_validUntil!),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('유효기간 저장'),
            ),
          ],
        ),
      ),
    );
  }
}
