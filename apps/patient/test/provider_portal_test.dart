import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pruevia_patient/src/provider_portal.dart';

void main() {
  test('provider auth origin accepts the default HTTPS port only', () {
    expect(providerAuthOrigin('https://project.supabase.co', 'project.supabase.co').host, 'project.supabase.co');
    expect(() => providerAuthOrigin('http://project.supabase.co', 'project.supabase.co'), throwsFormatException);
    expect(() => providerAuthOrigin('https://project.supabase.co:444', 'project.supabase.co'), throwsFormatException);
    expect(() => providerAuthOrigin('https://other.supabase.co', 'project.supabase.co'), throwsFormatException);
    expect(() => providerAuthOrigin('https://project.supabase.co/?token=secret', 'project.supabase.co'), throwsFormatException);
  });

  test('provider transport rejects redirects and bounds upstream responses', () async {
    final client = MockClient((request) async => http.Response('x', 302, headers: {'location': 'https://evil.example/'}));
    final transport = ProviderAuthTransport(Uri.parse('https://project.supabase.co'), client: client);
    await expectLater(transport.get(Uri.parse('https://project.supabase.co/auth/v1/user')), throwsFormatException);
    transport.close();

    final oversized = MockClient((request) async => http.Response('x' * (256 * 1024 + 1), 200));
    final bounded = ProviderAuthTransport(Uri.parse('https://project.supabase.co'), client: oversized);
    await expectLater(bounded.get(Uri.parse('https://project.supabase.co/auth/v1/user')), throwsFormatException);
    bounded.close();
  });
}
