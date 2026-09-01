import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_service.dart';

/// Result returned by the backend's Gemini-powered leaf detection endpoint.
class LeafDetectionResult {
  /// `true` if the image contains a plant, leaf, or seedling.
  final bool isPlant;

  /// Short human-readable label, e.g. "Tomato Leaf", "Rice Seedling", "Not a Plant".
  final String label;

  /// Confidence score 0–100.
  final int confidence;

  /// One-sentence reason from the AI explaining its decision.
  final String reason;

  const LeafDetectionResult({
    required this.isPlant,
    required this.label,
    required this.confidence,
    required this.reason,
  });

  factory LeafDetectionResult.fromMap(Map<String, dynamic> map) {
    return LeafDetectionResult(
      isPlant: map['isPlant'] == true,
      label: map['label']?.toString() ?? 'Unknown',
      confidence: (map['confidence'] as num?)?.toInt() ?? 0,
      reason: map['reason']?.toString() ?? '',
    );
  }
}

/// Service for plant / leaf detection using the SmartSpot backend which
/// proxies calls to Google Gemini Vision AI.
///
/// Only accepts images that are genuinely plants, leaves, or seedlings.
/// Non-plant images (walls, pens, random objects) are rejected with
/// `isPlant = false` and a descriptive `reason`.
class LeafDetectionService {
  LeafDetectionService._();
  static final LeafDetectionService instance = LeafDetectionService._();

  String get _baseUrl => AuthService.baseUrl;

  /// Analyse [imageBytes] and return a [LeafDetectionResult].
  ///
  /// [mimeType] should be one of: `image/jpeg`, `image/png`, `image/webp`.
  ///
  /// Throws [ApiException] on network / auth failures, or if the backend
  /// is not configured with a Gemini API key.
  Future<LeafDetectionResult> analyzeImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Authentication required', statusCode: 401);
    }

    final base64Image = base64Encode(imageBytes);

    try {
      final uri = Uri.parse('$_baseUrl/api/leaf-detect');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'imageBase64': base64Image,
              'mimeType': mimeType,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final responseData =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMsg = (responseData is Map &&
                responseData.containsKey('error'))
            ? responseData['error'].toString()
            : 'Leaf detection failed with status ${response.statusCode}';
        throw ApiException(errorMsg, statusCode: response.statusCode);
      }

      return LeafDetectionResult.fromMap(
          Map<String, dynamic>.from(responseData as Map));
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('LeafDetectionService error: $e');
      throw ApiException('Leaf detection failed: $e');
    }
  }
}
