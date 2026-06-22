import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:report_admin_app/api/admin_api.dart';
import 'package:report_admin_app/widgets/app_toast.dart';

/// 기프티콘(코드) 등록 화면. (POST /api/admin/products/{id}/codes)
/// 필수: 상품 선택, 코드. 선택: 바코드 이미지(비공개 버킷), 유효기간.
///
/// 상품은 등록된 상품 목록 드롭다운에서 선택한다. (productName 표시 / productId 전송)
/// [initialProduct] 가 주어지면 해당 상품을 미리 선택한 상태로 진입한다.
class GiftRegisterPage extends StatefulWidget {
  const GiftRegisterPage({super.key, this.initialProduct});

  /// 상품 카드에서 진입한 경우 미리 선택할 상품.
  final Product? initialProduct;

  @override
  State<GiftRegisterPage> createState() => _GiftRegisterPageState();
}

class _GiftRegisterPageState extends State<GiftRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  Future<List<Product>>? _productsFuture;
  int? _selectedProductId;

  String? _barcodeObjectKey; // 업로드 완료된 비공개 object key
  String? _pickedName;
  DateTime? _validUntil;
  bool _uploading = false;
  bool _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.initialProduct?.productId;
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _productsFuture = AdminApi.instance.fetchProducts();
    });
  }

  @override
  void dispose() {
    _code.dispose();
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

      // 바코드/QR 디코딩 → 코드 자동입력. 인식 결과는 보정 가능하도록 채워만 둔다.
      final scanned = await _scanBarcode(picked.path);
      if (scanned != null) _code.text = scanned;

      final result = await AdminApi.instance.uploadImage(
        UploadType.barcodeImage,
        bytes,
        _contentType(picked.name),
      );
      setState(() {
        _barcodeObjectKey = result.objectKey;
        _pickedName = picked.name;
        _message = scanned == null
            ? '바코드를 자동 인식하지 못했어요. 코드를 직접 입력해 주세요.'
            : null;
      });
    } catch (e) {
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// 선택한 이미지에서 첫 번째 바코드/QR 값을 디코딩한다. 없으면 null.
  Future<String?> _scanBarcode(String path) async {
    final scanner = BarcodeScanner();
    try {
      final barcodes = await scanner.processImage(InputImage.fromFilePath(path));
      for (final b in barcodes) {
        final value = b.rawValue;
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    } finally {
      await scanner.close();
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final count = await AdminApi.instance.addCodes(
        _selectedProductId!,
        code: _code.text.trim(),
        barcodeImageUrl: _barcodeObjectKey,
        validUntil: _validUntil == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_validUntil!),
      );
      if (!mounted) return;
      AppToast.success('기프티콘이 등록되었습니다 (적재 $count건)');
      Navigator.of(context).pop(true); // 목록으로 돌아가 갱신
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
    return Scaffold(
      appBar: AppBar(title: const Text('기프티콘 등록')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProductDropdown(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: '코드 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? '코드를 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(
                  _validUntil == null
                      ? '유효기간 선택(선택)'
                      : DateFormat('yyyy-MM-dd').format(_validUntil!),
                ),
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
                    : const Icon(Icons.qr_code),
                label: Text(_pickedName ?? '바코드 이미지 선택(선택)'),
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
                    : const Text('기프티콘 등록'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDropdown() {
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: '상품 *',
              border: OutlineInputBorder(),
            ),
            child: Row(
              children: [
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('상품 목록 불러오는 중...'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return InputDecorator(
            decoration: const InputDecoration(
              labelText: '상품 *',
              border: OutlineInputBorder(),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('상품 목록을 불러오지 못했습니다.')),
                TextButton(onPressed: _loadProducts, child: const Text('재시도')),
              ],
            ),
          );
        }

        final products = snapshot.data ?? const <Product>[];
        // 미리 선택된 ID가 현재 목록에 없으면 무효화.
        final ids = products.map((p) => p.productId).toSet();
        final value = ids.contains(_selectedProductId) ? _selectedProductId : null;

        return DropdownButtonFormField<int>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '상품 *',
            helperText: '코드를 적재할 상품을 선택하세요',
            border: OutlineInputBorder(),
          ),
          items: products
              .map((p) => DropdownMenuItem<int>(
                    value: p.productId,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedProductId = v),
          validator: (v) => v == null ? '상품을 선택하세요.' : null,
        );
      },
    );
  }
}
