import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

class _ResponseTooLargeException implements Exception {}

class _ResponseEncodingException implements Exception {}

class _ResponseLengthMismatchException implements Exception {}

class PatientApiClient {
  PatientApiClient({String? baseUrl, http.Client? client, Duration? timeout})
    : baseUrl = _secureBaseUrl(
        baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:8787',
            ),
      ),
      _client = client ?? http.Client(),
      timeout = timeout ?? const Duration(seconds: 15);

  final String baseUrl;
  final http.Client _client;
  final Duration timeout;
  static const int _maxResponseBytes = 2 * 1024 * 1024;

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
      () => _sendRequest(
        http.Request(
          'GET',
          Uri.parse('$baseUrl/api/v1/search').replace(queryParameters: params),
        ),
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
    final response = await _request(() {
      final request = http.Request('POST', Uri.parse('$baseUrl$path'))
        ..headers.addAll(const {
          'content-type': 'application/json',
          'accept': 'application/json',
        })
        ..body = jsonEncode(body);
      return _sendRequest(request);
    });
    return _decode(response);
  }

  Future<http.Response> _sendRequest(http.BaseRequest request) async {
    // Never forward clinical queries or images to a redirect target. The API
    // base is configured at build time, but an unexpected redirect (or a
    // compromised edge) must fail closed instead of leaking the request.
    request.followRedirects = false;
    request.maxRedirects = 0;
    final streamed = await _client.send(request);
    final encoding =
        streamed.headers['content-encoding']?.trim().toLowerCase() ?? '';
    if (encoding != '' && encoding != 'identity') {
      await streamed.stream.listen((_) {}).cancel();
      throw _ResponseEncodingException();
    }
    final declaredLength = streamed.contentLength;
    if (declaredLength != null &&
        (declaredLength < 0 || declaredLength > _maxResponseBytes)) {
      await streamed.stream.listen((_) {}).cancel();
      throw _ResponseTooLargeException();
    }
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in streamed.stream) {
      total += chunk.length;
      if (total > _maxResponseBytes) throw _ResponseTooLargeException();
      builder.add(chunk);
    }
    if (declaredLength != null && total != declaredLength) {
      throw _ResponseLengthMismatchException();
    }
    return http.Response.bytes(
      builder.takeBytes(),
      streamed.statusCode,
      headers: streamed.headers,
      request: streamed.request,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase,
    );
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
    } on _ResponseTooLargeException {
      throw PatientApiException(
        502,
        'invalid_response',
        'El servicio devolviÃ³ una respuesta invÃ¡lida.',
        type: 'protocol',
        errorTag: 'CLIENT.PROTOCOL',
      );
    } on _ResponseEncodingException {
      throw PatientApiException(
        502,
        'invalid_response',
        'El servicio devolviÃ³ una respuesta invÃ¡lida.',
        type: 'protocol',
        errorTag: 'CLIENT.PROTOCOL',
      );
    } on _ResponseLengthMismatchException {
      throw PatientApiException(
        502,
        'invalid_response',
        'El servicio devolviÃ³ una respuesta invÃ¡lida.',
        type: 'protocol',
        errorTag: 'CLIENT.PROTOCOL',
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
      if (response.bodyBytes.length > _maxResponseBytes) {
        throw const FormatException('response too large');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! JsonMap) {
        throw const FormatException('response must be an object');
      }
      payload = decoded;
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
        _localizedMessage(code),
        type: _string(error['type']) ?? 'request',
        errorTag: _string(error['error_tag']) ?? 'API.REQUEST',
        severity: _string(error['severity']) ?? 'medium',
        retryable: error['retryable'] == true,
        requestId:
            _string(error['request_id']) ?? response.headers['x-request-id'],
      );
    }
    return payload;
  }

  String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  String _localizedMessage(String code) => switch (code) {
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
    'unauthorized' ||
    'mfa_required' => 'Necesitas autenticarte para realizar esta acción.',
    'forbidden' => 'No tienes permisos para realizar esta acción.',
    'ocr_unavailable' =>
      'La lectura de recetas no está disponible en este momento.',
    'ocr_failed' || 'ocr_unusable' =>
      'No pudimos leer la receta con suficiente seguridad. Revisa el texto e inténtalo de nuevo.',
    // Never display an upstream message verbatim: it can contain stack traces,
    // internal URLs or medical text. Diagnostics use the request ID instead.
    _ => 'No se pudo completar la solicitud. Inténtalo de nuevo.',
  };

  void close() => _client.close();
}

const _apiAllowedHosts = String.fromEnvironment('API_ALLOWED_HOSTS');

String _secureBaseUrl(String value) {
  final candidate = value.trim().replaceFirst(RegExp(r'/*$'), '');
  final uri = Uri.tryParse(candidate);
  final loopback =
      uri != null &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1');
  final secure =
      uri != null &&
      uri.isAbsolute &&
      uri.host.isNotEmpty &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      _isPublicHost(uri.host) &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      (uri.port == 443 || uri.port == 0);
  final localDevelopment =
      kDebugMode &&
      uri != null &&
      uri.isAbsolute &&
      uri.scheme == 'http' &&
      loopback &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment;
  final productionHostAllowed = kDebugMode ||
      _apiAllowedHosts
          .split(',')
          .map((host) => host.trim().toLowerCase())
          .where((host) => host.isNotEmpty)
          .contains(uri?.host.toLowerCase());
  if (!secure && !localDevelopment) {
    throw ArgumentError.value(
      value,
      'baseUrl',
      'must be an HTTPS origin (HTTP is allowed only for loopback development)',
    );
  }
  if (secure && !productionHostAllowed) {
    throw ArgumentError.value(
      value,
      'baseUrl',
      'must use a host declared in API_ALLOWED_HOSTS outside debug builds',
    );
  }
  return candidate;
}

bool _isPublicHost(String hostname) {
  final host = hostname.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (host.isEmpty ||
      host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.endsWith('.internal') ||
      host.endsWith('.home.arpa') ||
      host.codeUnits.any((unit) => unit > 0x7f)) {
    return false;
  }
  final ipv4 = RegExp(r'^(\d+)\.(\d+)\.(\d+)\.(\d+)$').firstMatch(host);
  if (ipv4 == null) return !host.contains(':');
  final octets = [1, 2, 3, 4]
      .map((index) => int.tryParse(ipv4.group(index) ?? '') ?? -1)
      .toList(growable: false);
  if (octets.any((part) => part < 0 || part > 255)) return false;
  final first = octets[0], second = octets[1];
  return first != 0 &&
      first != 10 &&
      first != 127 &&
      first != 169 &&
      !(first == 172 && second >= 16 && second <= 31) &&
      !(first == 192 && (second == 0 || second == 168)) &&
      !(first == 100 && second >= 64 && second <= 127) &&
      !(first == 198 && (second == 18 || second == 19 || second == 51)) &&
      !(first == 203 && second == 0) &&
      first < 224;
}
