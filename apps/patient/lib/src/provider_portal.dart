import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'package:file_selector/file_selector.dart';
import 'package:crypto/crypto.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'api_client.dart';
import 'provider_url_stub.dart'
    if (dart.library.js_interop) 'provider_url_web.dart';

const claimLabels = {
  'draft': 'Borrador',
  'pending': 'Solicitud recibida',
  'under_review': 'En revisión',
  'needs_information': 'Necesitamos información',
  'approved': 'Aprobada',
  'rejected': 'No aprobada',
  'cancelled': 'Cancelada',
  'revoked': 'Acceso revocado',
};

/// Restricts Auth/Storage requests to the configured origin, with bounded responses.
class ProviderAuthTransport extends http.BaseClient {
  ProviderAuthTransport(this.origin, {http.Client? client})
    : _client = client ?? http.Client();
  final Uri origin;
  final http.Client _client;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != origin.origin) {
      throw const FormatException('Destino no permitido');
    }
    request.followRedirects = false;
    request.maxRedirects = 0;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 300 && response.statusCode < 400) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('Redirección no permitida');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      if (bytes.length + chunk.length > 256 * 1024) {
        throw const FormatException('Respuesta demasiado grande');
      }
      bytes.addAll(chunk);
    }
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close() => _client.close();
}

Uri providerAuthOrigin(String value, String allowedHosts) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !['', '/'].contains(uri.path) ||
      (uri.port != 0 && uri.port != 443) ||
      !allowedHosts.split(',').map((s) => s.trim()).contains(uri.host)) {
    throw const FormatException('Configura el acceso seguro de proveedores.');
  }
  return uri;
}

class ProviderPortal extends StatefulWidget {
  const ProviderPortal({super.key});
  @override
  State<ProviderPortal> createState() => _ProviderPortalState();
}

class _ProviderPortalState extends State<ProviderPortal>
    with WidgetsBindingObserver {
  final api = PatientApiClient();
  SupabaseClient? client;
  ProviderAuthTransport? transport;
  final email = TextEditingController(),
      password = TextEditingController(),
      otp = TextEditingController(),
      totp = TextEditingController();
  final search = TextEditingController(),
      name = TextEditingController(),
      position = TextEditingController(),
      company = TextEditingController(),
      workEmail = TextEditingController(),
      message = TextEditingController();
  Map<String, dynamic>? info, detail, target;
  List<dynamic> rows = [], targets = [], privacy = [];
  String error = '',
      notice = '',
      factor = '',
      secret = '',
      qr = '',
      scope = 'location',
      method = 'email',
      privacyKind = 'access';
  bool busy = false, ready = false, accepted = false;
  int page = 0;
  Timer? timer;
  String? linkApplication, linkCode;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final values = Uri.splitQueryString(
      Uri.base.fragment.startsWith('application=') ? Uri.base.fragment : '',
    );
    linkApplication = values['application'];
    linkCode = values['code'];
    clearProviderLink();
    unawaited(initialize());
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && ready && !busy) unawaited(run(refresh));
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    api.close();
    client?.dispose();
    transport?.close();
    for (final c in [
      email,
      password,
      otp,
      totp,
      search,
      name,
      position,
      company,
      workEmail,
      message,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ready && !busy) {
      unawaited(run(refresh));
    }
  }

  Future<void> initialize() async {
    await run(() async {
      info = await api.providerCall('/api/v1/provider-intake');
      const url = String.fromEnvironment('SUPABASE_URL'),
          hosts = String.fromEnvironment('SUPABASE_ALLOWED_HOSTS'),
          key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
      if (key.isEmpty) {
        throw const FormatException(
          'El acceso de proveedores no está configurado.',
        );
      }
      final uri = providerAuthOrigin(url, hosts);
      transport = ProviderAuthTransport(uri);
      client = SupabaseClient(
        uri.origin,
        key,
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: true),
      );
    });
  }

  Future<void> run(Future<void> Function() operation) async {
    if (busy) return;
    if (mounted) {
      setState(() {
        busy = true;
        error = '';
      });
    }
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        error = e is PatientApiException
            ? e.message
            : e is FormatException
            ? e.message
            : 'No se pudo completar la acción. Revisa los datos e inténtalo de nuevo.';
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Map<String, dynamic>> call(
    String suffix, {
    Map<String, dynamic>? data,
  }) async {
    final token = client?.auth.currentSession?.accessToken;
    if (token == null) {
      throw const FormatException('Inicia sesión para continuar.');
    }
    return api.providerCall(
      '/api/v1/provider/applications$suffix',
      token: token,
      data: data,
    );
  }

  Future<void> signIn() async {
    await client!.auth.signInWithPassword(
      email: email.text.trim(),
      password: password.text,
    );
    password.clear();
    await prepareFactor();
  }

  Future<void> signUp() async {
    if (info?['enabled'] != true || !accepted) {
      throw const FormatException(
        'Consulta el aviso y espera la apertura del registro.',
      );
    }
    if (password.text.length < 12) {
      throw const FormatException(
        'Usa una contraseña de al menos 12 caracteres.',
      );
    }
    await client!.auth.signUp(
      email: email.text.trim(),
      password: password.text,
    );
    password.clear();
    notice =
        'Revisa tu correo y escribe el código de confirmación. Después podrás iniciar sesión.';
  }

  Future<void> prepareFactor() async {
    final factors = await client!.auth.mfa.listFactors();
    if (factors.totp.isNotEmpty) {
      factor = factors.totp.first.id;
    } else {
      final enrollment = await client!.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'Pruevia',
      );
      factor = enrollment.id;
      secret = enrollment.totp!.secret;
      qr = enrollment.totp!.qrCode;
      if (qr.startsWith('data:')) {
        final uri = UriData.parse(qr);
        qr = uri.contentAsString();
      }
    }
  }

  Future<void> verifyMfa() async {
    await client!.auth.mfa.challengeAndVerify(
      factorId: factor,
      code: totp.text.trim(),
    );
    totp.clear();
    secret = '';
    qr = '';
    ready = true;
    if (linkApplication != null && linkCode != null) {
      await call('/$linkApplication/verify', data: {'code': linkCode});
      linkCode = null;
      notice =
          'Correo de trabajo comprobado. Tu solicitud seguirá en revisión.';
    }
    await refresh();
  }

  Future<void> refresh() async {
    rows = (await call('?offset=${page * 50}'))['items'] as List;
    if (detail != null) detail = await call('/${detail!['id']}');
  }

  Future<void> open(String id) async {
    detail = await call('/$id');
    message.clear();
    name.text = detail!['name'];
    position.text = detail!['position'];
    company.text = detail!['organization_name'];
    workEmail.text = detail!['work_email'];
  }

  Future<void> create() async {
    if (target == null || !accepted) {
      throw const FormatException(
        'Selecciona el perfil y confirma tu autorización.',
      );
    }
    final result = await call(
      '',
      data: {
        'brand_id': target!['brand_id'],
        'location_id': scope == 'location' ? target!['location_id'] : null,
        'scope': scope,
        'name': name.text.trim(),
        'position': position.text.trim(),
        'organization_name': company.text.trim(),
        'work_email': workEmail.text.trim(),
        'method': method,
        'notice_version': info!['notice_version'],
        'authorized': true,
      },
    );
    await open(result['id'] as String);
    target = null;
    await refresh();
    notice = 'Borrador guardado. Revisa los datos y envía tu solicitud.';
  }

  Future<void> action(String action) async {
    await call(
      '/${detail!['id']}/$action',
      data: {'revision': detail!['revision'], 'message': message.text},
    );
    await refresh();
    message.clear();
    notice = 'Solicitud actualizada.';
  }

  Future<void> upload() async {
    final claim = detail?['legacy_claim_id'];
    if (claim == null) {
      throw const FormatException(
        'Primero revisaremos los datos del negocio para habilitar su expediente documental.',
      );
    }
    if (info?['documents_enabled'] != true) {
      throw const FormatException(
        'La recepción de documentos aún no está habilitada.',
      );
    }
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Documento',
          extensions: ['pdf', 'png', 'jpg', 'jpeg'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 10 * 1024 * 1024) {
      throw const FormatException('El archivo debe pesar hasta 10 MB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('Archivo vacío o demasiado grande.');
    }
    final extension = file.name.split('.').last.toLowerCase();
    if (!['pdf', 'png', 'jpg', 'jpeg'].contains(extension)) {
      throw const FormatException('Usa PDF, PNG o JPEG.');
    }
    final random = Random.secure();
    final hex = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final uuid =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    final path = '$claim/$uuid.$extension';
    await client!.storage
        .from('provider-claims')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: extension == 'pdf'
                ? 'application/pdf'
                : extension == 'png'
                ? 'image/png'
                : 'image/jpeg',
            upsert: false,
          ),
        );
    await api.providerCall(
      '/api/v1/provider/claims/$claim/documents',
      token: client!.auth.currentSession!.accessToken,
      data: {
        'document_type': 'other',
        'object_key': 'provider-claims/$path',
        'sha256': sha256.convert(bytes).toString(),
      },
    );
    notice = 'Documento recibido. Comprobaremos el archivo antes de revisarlo.';
    await refresh();
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    int max = 240,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      maxLength: max,
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
  Widget button(String text, Future<void> Function() task) => Padding(
    padding: const EdgeInsets.all(4),
    child: FilledButton(
      onPressed: busy ? null : () => run(task),
      child: Text(text),
    ),
  );
  Widget privacyNotice() => ExpansionTile(
    title: const Text('Aviso de privacidad de proveedores'),
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Responsable: ${info?['controller_name'] ?? 'Pendiente de definir'}. Domicilio: ${info?['controller_address'] ?? 'Pendiente de definir'}. Contacto: ${info?['privacy_email'] ?? 'Pendiente de definir'}.\n\n'
          'Usamos tus datos de cuenta, nombre, cargo, organización, correo y evidencia para verificar tu representación, gestionar accesos, atender solicitudes y prevenir abuso. Los datos del representante y sus documentos son privados; los datos comerciales que propongas sólo se publican después de revisión.\n\n'
          'Utilizamos proveedores de alojamiento y correo para prestar el servicio. No vendemos tus documentos ni los usamos para publicidad o entrenamiento de IA. Solicitamos únicamente evidencia necesaria; oculta datos ajenos al trámite y no adjuntes información de pacientes.\n\n'
          'Puedes solicitar acceso, rectificación, cancelación, oposición y revocación del consentimiento desde tu cuenta o mediante el contacto indicado. La cancelación puede requerir bloqueo por obligaciones legales. Los plazos de conservación y los encargados del tratamiento deben quedar publicados en el aviso integral antes de abrir este registro.\n\n'
          'Versión: ${info?['notice_version'] ?? 'Sin publicar'}. Los cambios se comunicarán aquí y, si afectan el tratamiento, mediante tu correo.',
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pruevia · Proveedores')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error.isNotEmpty)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (notice.isNotEmpty) Text(notice),
            if (client?.auth.currentSession == null) ...[
              const Text(
                'Administra el perfil de tu negocio',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              if (info?['enabled'] != true)
                const Text(
                  'El registro todavía no está abierto. Podrás enviar tu solicitud cuando esté disponible.',
                ),
              privacyNotice(),
              field('Correo de tu cuenta', email),
              field('Contraseña', password, obscure: true),
              CheckboxListTile(
                value: accepted,
                onChanged: (v) => setState(() => accepted = v ?? false),
                title: const Text(
                  'Leí el aviso de privacidad y autorizo el tratamiento necesario para mi solicitud.',
                ),
              ),
              if (client != null)
                Wrap(
                  children: [
                    button('Iniciar sesión', signIn),
                    if (info?['enabled'] == true)
                      button('Crear cuenta', signUp),
                  ],
                ),
              if (client != null)
                ExpansionTile(
                  title: const Text('Confirmar mi correo'),
                  children: [
                    field('Código recibido', otp),
                    button('Confirmar correo', () async {
                      await client!.auth.verifyOTP(
                        email: email.text.trim(),
                        token: otp.text.trim(),
                        type: OtpType.signup,
                      );
                      otp.clear();
                      await prepareFactor();
                    }),
                    button('Reenviar confirmación', () async {
                      await client!.auth.resend(
                        type: OtpType.signup,
                        email: email.text.trim(),
                      );
                      notice = 'Revisa tu correo.';
                    }),
                  ],
                ),
            ] else if (!ready) ...[
              const Text(
                'Confirma tu identidad',
                style: TextStyle(fontSize: 26),
              ),
              const Text(
                'Usa un código de seis dígitos de tu aplicación autenticadora.',
              ),
              if (qr.isNotEmpty)
                QrImageView(data: qr, size: 220, backgroundColor: Colors.white),
              if (secret.isNotEmpty)
                ExpansionTile(
                  title: const Text('Usar clave manual'),
                  children: [SelectableText(secret)],
                ),
              field('Código del autenticador', totp, max: 6),
              button('Entrar', verifyMfa),
            ] else ...[
              const Text(
                'Mis solicitudes',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              button('Actualizar', refresh),
              if (rows.isEmpty) const Text('Todavía no tienes solicitudes.'),
              ...rows.map(
                (r) => Card(
                  child: ListTile(
                    title: Text(
                      '${r['provider_name']} · ${r['location_name'] ?? 'Toda la marca'}',
                    ),
                    subtitle: Text(claimLabels[r['status']] ?? r['status']),
                    onTap: busy ? null : () => run(() => open(r['id'])),
                  ),
                ),
              ),
              Wrap(
                children: [
                  if (page > 0)
                    button('Anterior', () async {
                      page--;
                      await refresh();
                    }),
                  if (rows.length == 50)
                    button('Siguiente', () async {
                      page++;
                      await refresh();
                    }),
                ],
              ),
              if (detail != null) ...[
                const Divider(),
                Text(
                  claimLabels[detail!['status']] ?? '',
                  style: const TextStyle(fontSize: 22),
                ),
                SelectableText('Folio: ${detail!['id']}'),
                Text(
                  '${detail!['organization_name']} · ${detail!['scope'] == 'brand' ? 'Toda la marca' : 'Esta sucursal'}',
                ),
                const Text(
                  'Puedes cerrar esta pantalla. Conservaremos tu solicitud y te avisaremos por correo cuando haya novedades.',
                ),
                if (['draft', 'needs_information'].contains(detail!['status']))
                  ExpansionTile(
                    title: const Text('Corregir mis datos'),
                    children: [
                      field('Nombre', name),
                      field('Cargo', position),
                      field('Empresa', company),
                      field('Correo de trabajo', workEmail),
                      button('Guardar correcciones', () async {
                        await call(
                          '/${detail!['id']}/save',
                          data: {
                            'revision': detail!['revision'],
                            'name': name.text,
                            'position': position.text,
                            'organization_name': company.text,
                            'work_email': workEmail.text,
                          },
                        );
                        await refresh();
                      }),
                    ],
                  ),
                if (detail!['status'] == 'draft')
                  button('Enviar solicitud', () => action('submit')),
                if ([
                  'needs_information',
                  'rejected',
                ].contains(detail!['status'])) ...[
                  field('Respuesta o nueva evidencia', message, max: 2000),
                  button('Enviar para revisión', () => action('submit')),
                ],
                if ([
                  'pending',
                  'under_review',
                  'needs_information',
                ].contains(detail!['status'])) ...[
                  Text(
                    detail!['contact_confirmed_at'] != null
                        ? 'Correo de trabajo comprobado.'
                        : 'Revisaremos el contacto oficial antes de enviar la comprobación.',
                  ),
                  if (detail!['contact_reviewed'] == true &&
                      detail!['contact_confirmed_at'] == null)
                    button(
                      'Reenviar comprobación',
                      () => action('send_verification'),
                    ),
                  button('Adjuntar evidencia alternativa', upload),
                ],
                if (detail!['status'] == 'approved')
                  const Text(
                    'Tu acceso está aprobado. Sólo puedes gestionar los perfiles comprendidos en la autorización.',
                  ),
                ...((detail!['documents'] ?? []) as List).map(
                  (d) => ListTile(
                    title: Text('Documento: ${d['type']}'),
                    subtitle: Text('${d['scan_status']} · ${d['status']}'),
                  ),
                ),
                const Text(
                  'Historial',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...((detail!['events'] ?? []) as List).map(
                  (e) => ListTile(
                    title: Text(
                      e['message'].toString().isEmpty
                          ? 'Solicitud actualizada'
                          : e['message'],
                    ),
                    subtitle: Text(e['created_at']),
                  ),
                ),
                if ([
                  'draft',
                  'pending',
                  'under_review',
                  'needs_information',
                ].contains(detail!['status']))
                  button('Cancelar solicitud', () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Cancelar esta solicitud?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Volver'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Cancelar solicitud'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) await action('cancel');
                  }),
              ],
              if (info?['enabled'] == true)
                ExpansionTile(
                  title: const Text('Solicitar otro perfil'),
                  children: [
                    field('Busca tu negocio o sucursal', search),
                    button('Buscar', () async {
                      targets = (await call(
                        '/targets?q=${Uri.encodeComponent(search.text)}',
                      ))['items'];
                    }),
                    ...targets.map(
                      (t) => ListTile(
                        selected:
                            target?['brand_id'] == t['brand_id'] &&
                            target?['location_id'] == t['location_id'],
                        onTap: () => setState(
                          () => target = Map<String, dynamic>.from(t),
                        ),
                        title: Text(
                          '${t['provider_name']} · ${t['location_name'] ?? 'Marca'}',
                        ),
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'location',
                          label: Text('Esta sucursal'),
                        ),
                        ButtonSegment(
                          value: 'brand',
                          label: Text('Toda la marca'),
                        ),
                      ],
                      selected: {scope},
                      onSelectionChanged: (v) =>
                          setState(() => scope = v.first),
                    ),
                    field('Tu nombre', name, max: 160),
                    field('Cargo o función', position, max: 160),
                    field('Nombre legal de la empresa', company),
                    field('Correo de trabajo', workEmail, max: 254),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'email',
                          label: Text('Correo corporativo'),
                        ),
                        ButtonSegment(
                          value: 'documents',
                          label: Text('Documentos'),
                        ),
                      ],
                      selected: {method},
                      onSelectionChanged: (v) =>
                          setState(() => method = v.first),
                    ),
                    privacyNotice(),
                    CheckboxListTile(
                      value: accepted,
                      onChanged: (v) => setState(() => accepted = v ?? false),
                      title: const Text(
                        'Represento a este negocio y autorizo el tratamiento necesario de mis datos.',
                      ),
                    ),
                    button('Guardar solicitud', create),
                  ],
                ),
              ExpansionTile(
                title: const Text('Mis datos y privacidad'),
                onExpansionChanged: (open) {
                  if (open) {
                    run(() async {
                      privacy = (await call('/privacy_list'))['items'];
                    });
                  }
                },
                children: [
                  privacyNotice(),
                  DropdownButton<String>(
                    value: privacyKind,
                    items: const [
                      DropdownMenuItem(
                        value: 'access',
                        child: Text('Acceso a mis datos'),
                      ),
                      DropdownMenuItem(
                        value: 'rectification',
                        child: Text('Corregir mis datos'),
                      ),
                      DropdownMenuItem(
                        value: 'cancellation',
                        child: Text('Cancelar mis datos'),
                      ),
                      DropdownMenuItem(
                        value: 'opposition',
                        child: Text('Oponerme al tratamiento'),
                      ),
                      DropdownMenuItem(
                        value: 'withdrawal',
                        child: Text('Revocar consentimiento'),
                      ),
                    ],
                    onChanged: (v) => setState(() => privacyKind = v!),
                  ),
                  field('Explica tu solicitud', message, max: 2000),
                  button('Enviar solicitud de privacidad', () async {
                    await call(
                      '/privacy_request',
                      data: {'kind': privacyKind, 'message': message.text},
                    );
                    message.clear();
                    privacy = (await call('/privacy_list'))['items'];
                  }),
                  ...privacy.map(
                    (p) => ListTile(
                      title: Text('${p['kind']} · ${p['status']}'),
                      subtitle: Text(p['response'] ?? 'Solicitud recibida'),
                    ),
                  ),
                ],
              ),
            ],
            if (client?.auth.currentSession != null)
              button('Cerrar sesión', () async {
                await client!.auth.signOut();
                ready = false;
                rows = [];
                detail = null;
                privacy = [];
                secret = '';
                qr = '';
                factor = '';
                message.clear();
                notice = 'Sesión cerrada.';
              }),
          ],
        ),
      ),
    ),
  );
}
