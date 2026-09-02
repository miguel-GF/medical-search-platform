import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class PatientApiException implements Exception {
  const PatientApiException(
    this.statusCode,
    this.code,
    this.message, {
    this.type = 'request',
    this.errorTag = 'CLIENT.REQUEST',
    this.severity = 'medium',
    this.retryable = false,
    this.requestId,
  });

  final int statusCode;
  final String code;
  final String message;
  final String type;
  final String errorTag;
  final String severity;
  final bool retryable;
  final String? requestId;

  @override
  String toString() => message;
}

class PatientApiClient {
  PatientApiClient({String? baseUrl, http.Client? client, Duration? timeout})
    : baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://localhost:8787',
                  ))
              .replaceFirst(RegExp(r'/*$'), ''),
      _client = client ?? http.Client(),
      timeout = timeout ?? const Duration(seconds: 15);

  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

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
    final response = await _request(
      () => _client.get(
        Uri.parse('$baseUrl/api/v1/search').replace(queryParameters: params),
      ),
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
    final response = await _request(
      () => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: const {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Future<http.Response> _request(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw PatientApiException(
        504,
        'client_timeout',
        'La solicitud tardó demasiado. Inténtalo de nuevo.',
        type: 'timeout',
        errorTag: 'CLIENT.TIMEOUT',
        retryable: true,
      );
    } on http.ClientException {
      throw PatientApiException(
        503,
        'client_connection_error',
        'No pudimos conectar con Pruevia. Revisa tu conexión e inténtalo de nuevo.',
        type: 'connection',
        errorTag: 'CLIENT.CONNECTION',
        retryable: true,
      );
    } catch (error) {
      throw PatientApiException(
        503,
        'client_connection_error',
        'No pudimos conectar con Pruevia. Revisa tu conexión e inténtalo de nuevo.',
        type: 'connection',
        errorTag: 'CLIENT.CONNECTION',
        retryable: true,
      );
    }
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
        type: 'protocol',
        errorTag: 'CLIENT.PROTOCOL',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'] is JsonMap
          ? payload['error'] as JsonMap
          : <String, dynamic>{};
      final code = _string(error['code']) ?? 'request_failed';
      throw PatientApiException(
        response.statusCode,
        code,
        _localizedMessage(
          code,
          _string(error['message']) ?? 'No se pudo completar la solicitud.',
        ),
        type: _string(error['type']) ?? 'request',
        errorTag: _string(error['error_tag']) ?? 'API.REQUEST',
        severity: _string(error['severity']) ?? 'medium',
        retryable: error['retryable'] == true,
        requestId: _string(error['request_id']) ?? response.headers['x-request-id'],
      );
    }
    return payload;
  }

  String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  String _localizedMessage(String code, String fallback) => switch (code) {
    'service_not_configured' =>
      'El servicio de búsqueda no está configurado. Inténtalo más tarde.',
    'upstream_timeout' || 'client_timeout' =>
      'El servicio tardó demasiado en responder. Inténtalo de nuevo en unos segundos.',
    'upstream_connection_error' || 'client_connection_error' =>
      'No pudimos conectar con el servicio. Revisa tu conexión e inténtalo de nuevo.',
    'upstream_rate_limited' =>
      'Hay muchas solicitudes en este momento. Inténtalo de nuevo en unos segundos.',
    'upstream_rpc_error' || 'internal_error' =>
      'No pudimos completar la consulta en este momento. Inténtalo de nuevo.',
    'payload_too_large' => 'El archivo o la solicitud es demasiado grande.',
    'invalid_query' => 'Escribe un nombre de estudio válido para buscar.',
    'invalid_body' => 'La solicitud no tiene un formato válido.',
    'invalid_json' => 'La solicitud no pudo leerse. Inténtalo de nuevo.',
    'invalid_coordinates' => 'La ubicación proporcionada no es válida.',
    'invalid_location_id' => 'La sucursal seleccionada no es válida.',
    'invalid_domain' => 'La búsqueda solicitada no es válida.',
    'not_found' => 'No encontramos esa información.',
    'route_requires_id' => 'Falta seleccionar un elemento.',
    'unauthorized' || 'mfa_required' =>
      'Necesitas autenticarte para realizar esta acción.',
    'forbidden' => 'No tienes permisos para realizar esta acción.',
    'ocr_unavailable' => 'La lectura de recetas no está disponible en este momento.',
    'ocr_failed' || 'ocr_unusable' =>
      'No pudimos leer la receta con suficiente seguridad. Revisa el texto e inténtalo de nuevo.',
    _ => fallback,
  };

  void close() => _client.close();
}
