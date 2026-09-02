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
}
