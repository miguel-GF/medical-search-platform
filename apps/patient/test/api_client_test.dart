import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:pruevia_patient/src/api_client.dart';

class _RecordingClient extends http.BaseClient {
  int requests = 0;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    lastRequest = request;
    return http.StreamedResponse(
      Stream<List<int>>.value('{}'.codeUnits),
      202,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _ErrorClient extends http.BaseClient {
  _ErrorClient(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(body.codeUnits),
      statusCode,
      headers: const {
        'content-type': 'application/json; charset=utf-8',
        'x-request-id': 'test-request-1234',
      },
    );
  }
}

class _CompressedClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(<int>[]),
      200,
      headers: const {'content-encoding': 'gzip'},
    );
  }
}

void main() {
  test('rejects insecure or credential-bearing API origins', () {
    expect(
      () => PatientApiClient(baseUrl: 'http://api.example.test'),
      throwsArgumentError,
    );
    expect(
      () => PatientApiClient(baseUrl: 'https://user:pass@api.example.test'),
      throwsArgumentError,
    );
    expect(
      () => PatientApiClient(baseUrl: 'https://api.example.test:8443'),
      throwsArgumentError,
    );
    expect(
      () => PatientApiClient(baseUrl: 'https://api.example.test/prefix'),
      throwsArgumentError,
    );
    for (final host in [
      'https://localhost',
      'https://127.0.0.1',
      'https://10.0.0.7',
      'https://192.168.1.20',
      'https://[::1]',
    ]) {
      expect(() => PatientApiClient(baseUrl: host), throwsArgumentError);
    }
  });

  test('allows HTTP only for local development loopback', () {
    final api = PatientApiClient(baseUrl: 'http://127.0.0.1:8787');
    expect(api.baseUrl, 'http://127.0.0.1:8787');
    api.close();
  });

  test('telemetry is never sent without consent', () async {
    final client = _RecordingClient();
    final api = PatientApiClient(baseUrl: 'https://api.test', client: client);

    await api.recordEvent(
      'search_completed',
      consentGiven: false,
      anonymousId: '00000000-0000-0000-0000-000000000001',
    );

    expect(client.requests, 0);
    api.close();
  });

  test(
    'offer clicks send identifiers only when telemetry consent exists',
    () async {
      final client = _RecordingClient();
      final api = PatientApiClient(baseUrl: 'https://api.test', client: client);

      await api.recordOfferClick(
        consentGiven: true,
        anonymousId: '00000000-0000-0000-0000-000000000001',
        offerId: '00000000-0000-0000-0000-000000000002',
        serviceId: '00000000-0000-0000-0000-000000000003',
        providerBrandId: '00000000-0000-0000-0000-000000000004',
        providerLocationId: '00000000-0000-0000-0000-000000000005',
        linkType: 'booking',
        surface: 'pwa',
      );

      final request = client.lastRequest as http.Request;
      expect(request.url.path, '/api/v1/events/offer-click');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['service_id'], '00000000-0000-0000-0000-000000000003');
      expect(body['link_type'], 'booking');
      expect(body, isNot(contains('query')));
      expect(body, isNot(contains('recipe')));

      await api.recordOfferClick(
        consentGiven: false,
        anonymousId: '',
        offerId: '00000000-0000-0000-0000-000000000002',
        serviceId: '00000000-0000-0000-0000-000000000003',
        providerBrandId: '00000000-0000-0000-0000-000000000004',
        linkType: 'study',
        surface: 'pwa',
      );
      expect(client.requests, 1);
      api.close();
    },
  );

  test('never follows API redirects', () async {
    final client = _RecordingClient();
    final api = PatientApiClient(baseUrl: 'https://api.test', client: client);

    await api.recordEvent(
      'search_completed',
      consentGiven: true,
      anonymousId: '00000000-0000-0000-0000-000000000001',
    );

    expect(client.lastRequest, isA<http.Request>());
    expect(client.lastRequest!.followRedirects, isFalse);
    expect(client.lastRequest!.maxRedirects, 0);
    api.close();
  });

  test('explicit feedback sends only the bounded product context', () async {
    final client = _RecordingClient();
    final api = PatientApiClient(baseUrl: 'https://api.test', client: client);

    await api.submitFeedback(
      experience: 'yes',
      helpful: 'partly',
      expected: 'yes',
      reasons: const ['missing_price'],
      surface: 'android',
      channel: 'public',
      resultState: 'results',
      resultCount: 2,
      appVersion: '1.0.0+1',
    );

    final request = client.lastRequest as http.Request;
    expect(request.url.path, '/api/v1/feedback');
    expect(request.body, contains('"helpful":"partly"'));
    expect(request.body, isNot(contains('query')));
    expect(request.followRedirects, isFalse);
    api.close();
  });

  test('surfaces tagged API failures as safe Spanish messages', () async {
    final api = PatientApiClient(
      baseUrl: 'https://api.test',
      client: _ErrorClient(
        504,
        '{"error":{"code":"upstream_timeout","type":"timeout","error_tag":"API.SERVER.TIMEOUT","severity":"medium","retryable":true,"request_id":"test-request-1234","message":"internal detail"}}',
      ),
    );

    expect(
      () => api.search('mastografia'),
      throwsA(
        isA<PatientApiException>()
            .having((error) => error.code, 'code', 'upstream_timeout')
            .having(
              (error) => error.errorTag,
              'error tag',
              'API.SERVER.TIMEOUT',
            )
            .having((error) => error.retryable, 'retryable', true)
            .having(
              (error) => error.requestId,
              'request id',
              'test-request-1234',
            )
            .having(
              (error) => error.message,
              'message',
              contains('tardó demasiado'),
            ),
      ),
    );
    api.close();
  });

  test('does not expose unknown upstream error details', () async {
    final api = PatientApiClient(
      baseUrl: 'https://api.test',
      client: _ErrorClient(
        500,
        '{"error":{"code":"unexpected","message":"stack trace and PHI"}}',
      ),
    );
    expect(
      () => api.search('glucosa'),
      throwsA(
        isA<PatientApiException>().having(
          (error) => error.message,
          'message',
          isNot(contains('stack trace')),
        ),
      ),
    );
    api.close();
  });

  test('rejects oversized or non-object API responses', () async {
    final oversized = PatientApiClient(
      baseUrl: 'https://api.test',
      client: _ErrorClient(200, 'x' * (2 * 1024 * 1024 + 1)),
    );
    expect(
      () => oversized.search('glucosa'),
      throwsA(
        isA<PatientApiException>().having(
          (error) => error.code,
          'code',
          'invalid_response',
        ),
      ),
    );
    oversized.close();

    final compressed = PatientApiClient(
      baseUrl: 'https://api.test',
      client: _CompressedClient(),
    );
    expect(
      () => compressed.search('glucosa'),
      throwsA(
        isA<PatientApiException>().having(
          (error) => error.code,
          'code',
          'invalid_response',
        ),
      ),
    );
    compressed.close();

    final array = PatientApiClient(
      baseUrl: 'https://api.test',
      client: _ErrorClient(200, '[]'),
    );
    expect(
      () => array.search('glucosa'),
      throwsA(
        isA<PatientApiException>().having(
          (error) => error.code,
          'code',
          'invalid_response',
        ),
      ),
    );
    array.close();
  });
}
