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

/// 등록된 상품. (서버 ProductResponse 와 1:1)
class Product {
  final int productId;
  final String name;
  final String? brand;
  final String? imageUrl;
  final int pointCost;
  final int stock; // 미사용(AVAILABLE) 코드 재고 수량
  final int processing; // 처리중(RESERVED) 코드 수량

  const Product({
    required this.productId,
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.pointCost,
    required this.stock,
    required this.processing,
  });

  /// 재고/처리중이 모두 0일 때만 삭제 가능.
  bool get deletable => stock == 0 && processing == 0;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    productId: (json['productId'] as num).toInt(),
    name: json['name'] as String,
    brand: json['brand'] as String?,
    imageUrl: json['imageUrl'] as String?,
    pointCost: (json['pointCost'] as num).toInt(),
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    processing: (json['processing'] as num?)?.toInt() ?? 0,
  );
}

/// 기프티콘 재고 상태. (서버 GiftInventoryStatus enum 과 1:1)
enum GiftStatus {
  available('AVAILABLE', '미사용'),
  reserved('RESERVED', '예약'),
  issued('ISSUED', '지급완료'),
  unknown('UNKNOWN', '알수없음');

  const GiftStatus(this.wire, this.label);

  final String wire;
  final String label;

  static GiftStatus fromWire(String? wire) =>
      GiftStatus.values.firstWhere((s) => s.wire == wire,
          orElse: () => GiftStatus.unknown);
}

/// 기프티콘 재고 단건. (서버 GiftInventoryResponse 와 1:1 — 상태/유효기간만 노출)
class GiftInventory {
  final int giftInventoryId;
  final GiftStatus status;
  final DateTime? validUntil; // yyyy-MM-dd

  const GiftInventory({
    required this.giftInventoryId,
    required this.status,
    required this.validUntil,
  });

  factory GiftInventory.fromJson(Map<String, dynamic> json) => GiftInventory(
    giftInventoryId: (json['giftInventoryId'] as num).toInt(),
    status: GiftStatus.fromWire(json['status'] as String?),
    validUntil: (json['validUntil'] as String?) == null
        ? null
        : DateTime.parse(json['validUntil'] as String),
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

  /// 등록된 전체 상품 목록 조회. (GET /api/admin/products)
  Future<List<Product>> fetchProducts() async {
    final res = await _client.get(Uri.parse('$apiBaseUrl/api/admin/products'));
    if (res.statusCode != 200) {
      throw Exception(_error(res, '상품 목록 조회 실패'));
    }
    final decoded =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final body = decoded['body'] as List<dynamic>;
    return body
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
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

  /// 상품 정보 수정. (PUT /api/admin/products/{id}) 모든 필드 수정 가능.
  Future<void> updateProduct(
    int productId, {
    required String name,
    String? brand,
    String? imageUrl,
    required int pointCost,
  }) async {
    final res = await _client.put(
      Uri.parse('$apiBaseUrl/api/admin/products/$productId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'brand': brand,
        'imageUrl': imageUrl,
        'pointCost': pointCost,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_error(res, '상품 수정 실패'));
    }
  }

  /// 상품 삭제. (DELETE /api/admin/products/{id})
  /// 서버에서 재고/처리중이 0이 아니면 409로 거부된다.
  Future<void> deleteProduct(int productId) async {
    final res = await _client
        .delete(Uri.parse('$apiBaseUrl/api/admin/products/$productId'));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_error(res, '상품 삭제 실패'));
    }
  }

  /// 상품의 기프티콘 재고 목록 조회. (GET /api/admin/products/{id}/codes)
  Future<List<GiftInventory>> fetchCodes(int productId) async {
    final res = await _client
        .get(Uri.parse('$apiBaseUrl/api/admin/products/$productId/codes'));
    if (res.statusCode != 200) {
      throw Exception(_error(res, '기프티콘 목록 조회 실패'));
    }
    final decoded =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final body = decoded['body'] as List<dynamic>;
    return body
        .map((e) => GiftInventory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 기프티콘 수정. (PATCH /api/admin/products/{id}/codes/{codeId}) 유효기간만 변경.
  Future<void> updateCode(
    int productId,
    int codeId, {
    String? validUntil, // yyyy-MM-dd, null이면 유효기간 해제
  }) async {
    final res = await _client.patch(
      Uri.parse('$apiBaseUrl/api/admin/products/$productId/codes/$codeId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'validUntil': validUntil}),
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_error(res, '기프티콘 수정 실패'));
    }
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
