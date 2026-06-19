import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:report_admin_app/api/api_client.dart';
import 'package:report_admin_app/api/api_config.dart';

/// presigned 업로드 발급 결과. (UploadUrlResponse)
class UploadResult {
  final String objectKey;
  final String uploadUrl;
  final String? publicUrl;

  const UploadResult({
    required this.objectKey,
    required this.uploadUrl,
    required this.publicUrl,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) => UploadResult(
    objectKey: json['objectKey'] as String,
    uploadUrl: json['uploadUrl'] as String,
    publicUrl: json['publicUrl'] as String?,
  );
}

/// 업로드 대상 유형. (서버 UploadType enum 과 1:1)
enum UploadType {
  /// 상품 썸네일 — 공개 버킷. 등록 시 publicUrl 사용.
  productImage('PRODUCT_IMAGE'),

  /// 바코드 이미지 — 비공개 버킷. 등록 시 objectKey 사용.
  barcodeImage('BARCODE_IMAGE');

  const UploadType(this.wire);

  /// 서버로 전송되는 enum 문자열.
  final String wire;
}

/// 관리자 전용 API. (`/api/admin/*` — ROLE_ADMIN 필요)
///
/// - 업로드: presigned URL 발급 → S3로 직접 PUT(서버 거치지 않음)
///   → 썸네일은 publicUrl, 바코드는 objectKey 를 각각 등록 API에 전달.
/// - 상품 등록 / 코드(기프티콘) 적재.
class AdminApi {
  AdminApi._();

  static final AdminApi instance = AdminApi._();

  final ApiClient _client = ApiClient.instance;
  final http.Client _raw = http.Client();

  /// 이미지 업로드: presigned URL 발급 → S3 PUT → 결과 반환.
  Future<UploadResult> uploadImage(
    UploadType type,
    Uint8List bytes,
    String contentType,
  ) async {
    final result = await _requestUpload(type, contentType);
    await _putToS3(result.uploadUrl, bytes, contentType);
    return result;
  }

  Future<UploadResult> _requestUpload(UploadType type, String contentType) async {
    final res = await _client.post(
      Uri.parse('$apiBaseUrl/api/admin/uploads'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'type': type.wire, 'contentType': contentType}),
    );
    if (res.statusCode != 200) {
      throw Exception(_error(res, '업로드 URL 발급 실패'));
    }
    final decoded =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return UploadResult.fromJson(decoded['body'] as Map<String, dynamic>);
  }

  /// presigned PUT URL로 S3에 직접 업로드. 발급 때와 같은 Content-Type 을 보내야 서명이 일치한다.
  Future<void> _putToS3(String uploadUrl, Uint8List bytes, String contentType) async {
    final res = await _raw.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('S3 업로드 실패 (HTTP ${res.statusCode})');
    }
  }

  /// 상품 등록. (POST /api/admin/products) 생성된 productId 반환.
  Future<int> createProduct({
    required String name,
    String? brand,
    String? imageUrl,
    required int pointCost,
  }) async {
    final res = await _client.post(
      Uri.parse('$apiBaseUrl/api/admin/products'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'brand': brand,
        'imageUrl': imageUrl,
        'pointCost': pointCost,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_error(res, '상품 등록 실패'));
    }
    final decoded =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (decoded['body'] as num).toInt();
  }

  /// 코드(기프티콘) 재고 적재. (POST /api/admin/products/{id}/codes) 적재된 코드 수 반환.
  Future<int> addCodes(
    int productId, {
    required String code,
    String? barcodeImageUrl,
    String? validUntil, // yyyy-MM-dd
  }) async {
    final res = await _client.post(
      Uri.parse('$apiBaseUrl/api/admin/products/$productId/codes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'codes': [
          {
            'code': code,
            'barcodeImageUrl': barcodeImageUrl,
            'validUntil': validUntil,
          },
        ],
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_error(res, '코드 적재 실패'));
    }
    final decoded =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (decoded['body'] as num).toInt();
  }

  String _error(http.Response res, String fallback) {
    try {
      final decoded =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final message = decoded['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {
      // 파싱 실패 시 fallback.
    }
    return '$fallback (HTTP ${res.statusCode})';
  }
}
