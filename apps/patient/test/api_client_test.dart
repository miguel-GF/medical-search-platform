import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:pruevia_patient/src/api_client.dart';

class _RecordingClient extends http.BaseClient {
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    return http.StreamedResponse(
      Stream<List<int>>.value(<int>[]),
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

void main() {
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
            .having((error) => error.errorTag, 'error tag', 'API.SERVER.TIMEOUT')
            .having((error) => error.retryable, 'retryable', true)
            .having((error) => error.requestId, 'request id', 'test-request-1234')
            .having((error) => error.message, 'message', contains('tardó demasiado')),
      ),
    );
    api.close();
  });
}
