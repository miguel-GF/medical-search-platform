import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class PatientApiException implements Exception {
  const PatientApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

class PatientApiClient {
  PatientApiClient({String? baseUrl, http.Client? client})
    : baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://localhost:8787',
                  ))
              .replaceFirst(RegExp(r'/*$'), ''),
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<SearchResponse> search(
    String query, {
    double? latitude,
    double? longitude,
    String domain = 'health_diagnostics',
  }) async {
    final params = <String, String>{
      'q': query.trim(),
      'domain': domain,
      'limit': '100',
    };
    if (latitude != null && longitude != null) {
      params['lat'] = '$latitude';
      params['lng'] = '$longitude';
    }
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/search').replace(queryParameters: params),
    );
    return SearchResponse.fromJson(await _decode(response));
  }

  Future<PackageResponse> resolvePackage({
    String? text,
    List<String>? items,
    PackageObjective objective = PackageObjective.allInOne,
    String domain = 'health_diagnostics',
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{
      ...?text == null ? null : {'text': text},
      ...?items == null ? null : {'items': items},
      'objective': objective.wireName,
      'domain': domain,
      'max_solutions': 10,
      ...?latitude == null ? null : {'latitude': latitude},
      ...?longitude == null ? null : {'longitude': longitude},
    };
    final response = await _post('/api/v1/resolve-batch', body);
    return PackageResponse.fromJson(response);
  }

  Future<PackageResponse> resolveImage(
    Uint8List bytes,
    String mimeType, {
    PackageObjective objective = PackageObjective.allInOne,
    String domain = 'health_diagnostics',
  }) async {
    final response = await _post('/api/v1/resolve-image', {
      'image': 'data:$mimeType;base64,${base64Encode(bytes)}',
      'mime_type': mimeType,
      'objective': objective.wireName,
      'domain': domain,
      'max_solutions': 10,
    });
    return PackageResponse.fromJson(response);
  }

  Future<void> recordEvent(
    String eventName, {
    required bool consentGiven,
    required String anonymousId,
    Map<String, Object?> metadata = const {},
  }) async {
    if (!consentGiven) return;
    try {
      await _post('/api/v1/events', {
        'event_name': eventName,
        'anonymous_id': anonymousId,
        'metadata': metadata,
      });
    } on Object {
      // Telemetry must never block or reveal an error in the patient flow.
    }
  }

  Future<JsonMap> _post(String path, JsonMap body) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: const {
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<JsonMap> _decode(http.Response response) async {
    JsonMap payload;
    try {
      final decoded = jsonDecode(response.body);
      payload = decoded is JsonMap ? decoded : <String, dynamic>{};
    } on FormatException {
      throw PatientApiException(
        response.statusCode,
        'invalid_response',
        'El servicio devolvió una respuesta inválida.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'] is JsonMap
          ? payload['error'] as JsonMap
          : <String, dynamic>{};
      throw PatientApiException(
        response.statusCode,
        _string(error['code']) ?? 'request_failed',
        _string(error['message']) ?? 'No se pudo completar la solicitud.',
      );
    }
    return payload;
  }

  String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  void close() => _client.close();
}
