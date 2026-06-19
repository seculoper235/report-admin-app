import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:report_admin_app/api/admin_api.dart';

/// 상품 등록 화면. (POST /api/admin/products)
/// 필수: 상품명, 포인트 가격. 선택: 브랜드, 썸네일 이미지(공개 버킷 업로드).
class ProductRegisterPage extends StatefulWidget {
  const ProductRegisterPage({super.key});

  @override
  State<ProductRegisterPage> createState() => _ProductRegisterPageState();
}

class _ProductRegisterPageState extends State<ProductRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _pointCost = TextEditingController();

  String? _imageUrl; // 업로드 완료된 공개 URL
  String? _pickedName; // 선택한 파일명(표시용)
  bool _uploading = false;
  bool _submitting = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _pointCost.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _uploading = true;
      _message = null;
    });
    try {
      final bytes = await picked.readAsBytes();
      final result = await AdminApi.instance.uploadImage(
        UploadType.productImage,
        bytes,
        _contentType(picked.name),
      );
      setState(() {
        _imageUrl = result.publicUrl;
        _pickedName = picked.name;
      });
    } catch (e) {
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final id = await AdminApi.instance.createProduct(
        name: _name.text.trim(),
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        imageUrl: _imageUrl,
        pointCost: int.parse(_pointCost.text.trim()),
      );
      if (!mounted) return;
      _formKey.currentState!.reset();
      _name.clear();
      _brand.clear();
      _pointCost.clear();
      setState(() {
        _imageUrl = null;
        _pickedName = null;
        _message = '상품 등록 완료 (productId: $id)';
      });
    } catch (e) {
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _contentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '상품명 *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? '상품명을 입력하세요.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _brand,
              decoration: const InputDecoration(
                labelText: '브랜드',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pointCost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '포인트 가격 *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null) return '숫자를 입력하세요.';
                if (n <= 0) return '0보다 큰 값이어야 합니다.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image),
              label: Text(_pickedName ?? '썸네일 이미지 선택(선택)'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_submitting || _uploading) ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('상품 등록'),
            ),
          ],
        ),
      ),
    );
  }
}
