import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:report_admin_app/api/admin_api.dart';

/// 기프티콘(코드) 등록 화면. (POST /api/admin/products/{id}/codes)
/// 필수: 상품 ID, 코드. 선택: 바코드 이미지(비공개 버킷), 유효기간.
class GiftRegisterPage extends StatefulWidget {
  const GiftRegisterPage({super.key});

  @override
  State<GiftRegisterPage> createState() => _GiftRegisterPageState();
}

class _GiftRegisterPageState extends State<GiftRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _productId = TextEditingController();
  final _code = TextEditingController();

  String? _barcodeObjectKey; // 업로드 완료된 비공개 object key
  String? _pickedName;
  DateTime? _validUntil;
  bool _uploading = false;
  bool _submitting = false;
  String? _message;

  @override
  void dispose() {
    _productId.dispose();
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
      final result = await AdminApi.instance.uploadImage(
        UploadType.barcodeImage,
        bytes,
        _contentType(picked.name),
      );
      setState(() {
        _barcodeObjectKey = result.objectKey;
        _pickedName = picked.name;
      });
    } catch (e) {
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
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
        int.parse(_productId.text.trim()),
        code: _code.text.trim(),
        barcodeImageUrl: _barcodeObjectKey,
        validUntil: _validUntil == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_validUntil!),
      );
      if (!mounted) return;
      _code.clear();
      setState(() {
        _barcodeObjectKey = null;
        _pickedName = null;
        _validUntil = null;
        _message = '기프티콘 등록 완료 (적재 $count건)';
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
              controller: _productId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '상품 ID *',
                helperText: '코드를 적재할 상품의 productId',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  int.tryParse((v ?? '').trim()) == null ? '숫자 상품 ID를 입력하세요.' : null,
            ),
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
    );
  }
}
