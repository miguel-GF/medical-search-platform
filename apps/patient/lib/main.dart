import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/api_client.dart';
import 'src/local_preferences.dart';
import 'src/models.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A malformed remote payload must never leave patients with Flutter's red
  // debug error surface. Network/API errors are handled inline; this is the
  // last-resort UI fallback for an unexpected rendering failure.
  ErrorWidget.builder = (_) => const _AppErrorFallback();
  final preferences = await PatientPreferences.load();
  runApp(PatientApp(preferences: preferences));
}

class _AppErrorFallback extends StatelessWidget {
  const _AppErrorFallback();

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF0B1220),
    child: Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.refresh, size: 28),
              const SizedBox(height: 12),
              Text(
                'Algo no salió como esperábamos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Recarga esta pantalla para intentarlo de nuevo. Tu búsqueda no se envía ni se guarda por este error.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PatientApp extends StatefulWidget {
  const PatientApp({super.key, required this.preferences});
  final PatientPreferences preferences;
  @override
  State<PatientApp> createState() => _PatientAppState();
}

class _PatientAppState extends State<PatientApp> {
  late ThemeMode _themeMode = widget.preferences.themeMode;
  late final PatientApiClient _api = PatientApiClient();

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _setTheme(ThemeMode mode) async {
    await widget.preferences.setThemeMode(mode);
    if (mounted) setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pruevia',
    debugShowCheckedModeBanner: false,
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
    ),
    theme: buildPrueviaTheme(Brightness.light),
    darkTheme: buildPrueviaTheme(Brightness.dark),
    themeMode: _themeMode,
    home: widget.preferences.consentGiven
        ? PatientShell(
            api: _api,
            preferences: widget.preferences,
            themeMode: _themeMode,
            onThemeChanged: _setTheme,
          )
        : ConsentScreen(
            onAccept: () async {
              await widget.preferences.grantConsent();
              await _api.recordEvent(
                'consent_granted',
                consentGiven: true,
                anonymousId: widget.preferences.anonymousId,
                metadata: const {'surface': 'pwa'},
              );
              if (mounted) setState(() {});
            },
          ),
  );
}

class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.onAccept});
  final Future<void> Function() onAccept;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PrueviaLogo(compact: false),
                const SizedBox(height: 42),
                Text(
                  'Encuentra dónde hacer tus estudios',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Compara estudios y sucursales con información publicada y trazable de cada proveedor.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                const _InfoCard(
                  icon: Icons.verified_outlined,
                  title: 'Información transparente',
                  text:
                      'Mostramos precio, fecha y fuente cuando están disponibles. Nunca inventamos un precio.',
                ),
                const SizedBox(height: 12),
                const _InfoCard(
                  icon: Icons.lock_outline,
                  title: 'Privacidad desde el inicio',
                  text:
                      'La receta y las imágenes no se guardan. El uso anónimo sólo mide qué pantallas funcionan.',
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Continuar'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Puedes borrar tus preferencias del navegador en cualquier momento.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PatientShell extends StatefulWidget {
  const PatientShell({
    super.key,
    required this.api,
    required this.preferences,
    required this.themeMode,
    required this.onThemeChanged,
  });
  final PatientApiClient api;
  final PatientPreferences preferences;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode) onThemeChanged;
  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;
  void _openOrder() => setState(() => _index = 1);

  Future<void> _openProviderAccess() async {
    await widget.api.recordEvent(
      'provider_contact_clicked',
      consentGiven: widget.preferences.consentGiven,
      anonymousId: widget.preferences.anonymousId,
      metadata: const {'surface': 'pwa'},
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const ProviderAccessSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        api: widget.api,
        preferences: widget.preferences,
        onOpenOrder: _openOrder,
        onOpenProviderAccess: _openProviderAccess,
      ),
      OrderScreen(api: widget.api, preferences: widget.preferences),
      SettingsScreen(
        preferences: widget.preferences,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const PrueviaLogo(compact: true),
        actions: [
          IconButton(
            tooltip: 'Cambiar tema',
            onPressed: () => widget.onThemeChanged(
              Theme.of(context).brightness == Brightness.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            ),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.search),
                  label: Text('Buscar'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.description_outlined),
                  label: Text('Receta'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.tune),
                  label: Text('Ajustes'),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: 'Buscar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  label: 'Receta',
                ),
                NavigationDestination(icon: Icon(Icons.tune), label: 'Ajustes'),
              ],
            ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.preferences,
    required this.onOpenOrder,
    required this.onOpenProviderAccess,
  });
  final PatientApiClient api;
  final PatientPreferences preferences;
  final VoidCallback onOpenOrder;
  final VoidCallback onOpenProviderAccess;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _query = TextEditingController();
  SearchResponse? _response;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Escribe al menos dos caracteres para buscar.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.search(query);
      if (!mounted) return;
      setState(() => _response = response);
      await widget.api.recordEvent(
        'search_completed',
        consentGiven: widget.preferences.consentGiven,
        anonymousId: widget.preferences.anonymousId,
        metadata: {'result_count': response.services.length},
      );
    } on PatientApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos conectar con Pruevia. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('BÚSQUEDA DE ESTUDIOS'),
        Text(
          'Compara antes de ir',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'Escribe el estudio tal como aparece en tu orden. Mostraremos coincidencias verificables y su sucursal concreta.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: widget.onOpenProviderAccess,
            icon: const Icon(Icons.business_center_outlined, size: 18),
            label: const Text('Acceso para proveedores'),
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 560;
            final field = TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                labelText: '¿Qué estudio necesitas?',
                hintText: 'Ej. biometría hemática',
                prefixIcon: Icon(Icons.search),
              ),
            );
            final button = FilledButton(
              onPressed: _loading ? null : _search,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(_loading ? 'Buscando…' : 'Buscar'),
              ),
            );
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [field, const SizedBox(height: 10), button],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: field),
                      const SizedBox(width: 10),
                      button,
                    ],
                  );
          },
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: widget.onOpenOrder,
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Tengo una receta con varios estudios'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          _ErrorBanner(message: _error!),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loading && _response != null) ...[
          const SizedBox(height: 30),
          _ResultHeader(
            query: _response!.query,
            count: _response!.services.length,
          ),
          const SizedBox(height: 14),
          if (_response!.services.isEmpty)
            const _EmptyState(
              title: 'No encontramos una coincidencia segura',
              text:
                  'Prueba con el nombre completo o revisa la sección de receta para confirmar cada renglón.',
            ),
          ..._response!.services.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ServiceCard(service: service),
            ),
          ),
        ],
        if (_response == null && !_loading)
          const Padding(
            padding: EdgeInsets.only(top: 38),
            child: _InfoCard(
              icon: Icons.fact_check_outlined,
              title: 'Resultados trazables',
              text:
                  'Los precios se muestran con su fuente y fecha. Si un proveedor no publica precio, lo indicaremos como “Cotizar”.',
            ),
          ),
      ],
    ),
  );
}

/// Keeps the provider entry visible without turning the public patient flow
/// into a role-selection or registration wall. Authentication is handled by
/// the provider identity flow; this sheet intentionally never collects
/// credentials or clinical data.
class ProviderAccessSheet extends StatelessWidget {
  const ProviderAccessSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.business_center_outlined,
                  color: colors.primary,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Acceso para proveedores',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Administra un perfil de empresa o sucursal que ya esté en Pruevia. La búsqueda de pacientes no requiere cuenta.',
                ),
                const SizedBox(height: 18),
                const _ProviderSecurityNote(
                  icon: Icons.verified_user_outlined,
                  title: 'Cuenta y alcance verificados',
                  text:
                      'Solo podrás editar las empresas y sucursales que estén aprobadas para tu cuenta.',
                ),
                const SizedBox(height: 10),
                const _ProviderSecurityNote(
                  icon: Icons.phonelink_lock_outlined,
                  title: 'Segundo factor',
                  text:
                      'Las acciones sensibles requieren un código temporal de una aplicación autenticadora.',
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Continuar al acceso seguro'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Si aún no tienes un perfil, el reclamo se inicia después de autenticarte y siempre requiere revisión.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderSecurityNote extends StatelessWidget {
  const _ProviderSecurityNote({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(text),
    ),
  );
}

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.api, required this.preferences});
  final PatientApiClient api;
  final PatientPreferences preferences;
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  PackageObjective _objective = PackageObjective.allInOne;
  PackageResponse? _response;
  Uint8List? _selectedImage;
  String? _mimeType;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _resolveText() async {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = 'Pega o escribe al menos un estudio.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.resolvePackage(
        text: _text.text,
        objective: _objective,
      );
      if (!mounted) return;
      setState(() => _response = response);
      await widget.api.recordEvent(
        'package_resolved',
        consentGiven: widget.preferences.consentGiven,
        anonymousId: widget.preferences.anonymousId,
        metadata: {
          'item_count': response.items.length,
          'status': response.packageStatus,
        },
      );
    } on PatientApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos resolver la receta. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2500,
        maxHeight: 2500,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(
          () => _error =
              'La imagen supera el límite de 5 MiB. Elige una foto más ligera.',
        );
        return;
      }
      final mime = _mimeFor(file.name);
      setState(() {
        _selectedImage = bytes;
        _mimeType = mime;
        _error = null;
        _loading = true;
      });
      final response = await widget.api.resolveImage(
        bytes,
        mime,
        objective: _objective,
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        if (response.ocr != null) _text.text = response.ocr!.text;
      });
      await widget.api.recordEvent(
        'package_resolved_from_image',
        consentGiven: widget.preferences.consentGiven,
        anonymousId: widget.preferences.anonymousId,
        metadata: {
          'item_count': response.items.length,
          'review_required': response.ocr?.reviewRequired ?? false,
        },
      );
    } on PatientApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos leer esa imagen. Puedes escribir los estudios manualmente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('RECETA / VARIOS ESTUDIOS'),
        Text(
          'Resuelve tu orden completa',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'Cada renglón se revisa por separado. Si algo es ambiguo, te lo pediremos confirmar antes de mostrar opciones.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _text,
                  minLines: 5,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Escribe o pega los estudios',
                    hintText:
                        '1. B H\n2. Q S completa\n3. EGO\n4. Perfil tiroideo',
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _loading ? null : _resolveText,
                      icon: const Icon(Icons.search),
                      label: const Text('Resolver estudios'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _pickImage(
                              kIsWeb ? ImageSource.gallery : ImageSource.camera,
                            ),
                      icon: Icon(
                        kIsWeb
                            ? Icons.upload_file
                            : Icons.photo_camera_outlined,
                      ),
                      label: Text(kIsWeb ? 'Subir receta' : 'Tomar foto'),
                    ),
                    if (!kIsWeb)
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PackageObjective>(
                  initialValue: _objective,
                  decoration: const InputDecoration(
                    labelText: 'Cómo quieres comparar',
                  ),
                  items: PackageObjective.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value != null) setState(() => _objective = value);
                        },
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Imagen lista para OCR (${_mimeType ?? 'imagen'})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          _ErrorBanner(message: _error!),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_response?.ocr != null) ...[
          const SizedBox(height: 22),
          OcrReviewCard(
            response: _response!,
            controller: _text,
            onResolve: _resolveText,
          ),
        ],
        if (_response != null) ...[
          const SizedBox(height: 22),
          PackageResultView(response: _response!),
        ],
      ],
    ),
  );
}

class OcrReviewCard extends StatelessWidget {
  const OcrReviewCard({
    super.key,
    required this.response,
    required this.controller,
    required this.onResolve,
  });
  final PackageResponse response;
  final TextEditingController controller;
  final VoidCallback onResolve;
  @override
  Widget build(BuildContext context) {
    final review = response.ocr!.reviewRequired;
    return Card(
      color: review
          ? Theme.of(context).colorScheme.tertiaryContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  review
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    review
                        ? 'Revisa la transcripción antes de continuar'
                        : 'Transcripción lista para revisar',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'El texto se puede editar. Pruevia no corrige ni inventa palabras automáticamente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Texto reconocido'),
            ),
            if (response.ocr!.lowConfidenceLines.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Líneas para verificar: ${response.ocr!.lowConfidenceLines.join(' · ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onResolve,
              icon: const Icon(Icons.refresh),
              label: const Text('Resolver texto corregido'),
            ),
          ],
        ),
      ),
    );
  }
}

class PackageResultView extends StatelessWidget {
  const PackageResultView({super.key, required this.response});
  final PackageResponse response;
  @override
  Widget build(BuildContext context) {
    final tone = response.packageStatus == 'ready'
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.tertiaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: tone,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  response.packageStatus == 'ready'
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _packageMessage(response),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...response.items.map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(child: Text('${item.index}')),
              title: Text(item.input),
              subtitle: Text(_itemMessage(item)),
              trailing: _StatusChip(status: item.status),
            ),
          ),
        ),
        if (response.solutions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Opciones de cobertura',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...response.solutions.asMap().entries.map(
            (entry) => SolutionCard(
              solution: entry.value,
              recommended: entry.key == 0,
            ),
          ),
        ],
        if (response.solutions.isEmpty && response.items.isNotEmpty)
          const _EmptyState(
            title: 'Aún no hay una combinación confirmada',
            text:
                'Confirma los estudios ambiguos o revisa los renglones sin coincidencia segura.',
          ),
      ],
    );
  }

  String _packageMessage(
    PackageResponse value,
  ) => switch (value.packageStatus) {
    'ready' => 'Encontramos una opción completa para tu orden.',
    'partial' =>
      'Encontramos parte de tu orden; algunos estudios faltan o requieren cotización.',
    'needs_clarification' =>
      'Necesitamos confirmar uno o más estudios antes de comparar sucursales.',
    _ => 'No encontramos coincidencias seguras para esta orden.',
  };
  String _itemMessage(PackageItem item) {
    if (item.status == 'resolved') {
      return item.candidates.isNotEmpty
          ? 'Coincide con ${item.candidates.first.displayName}'
          : 'Coincidencia confirmada';
    }
    if (item.candidates.isNotEmpty) {
      return 'Posibles coincidencias: ${item.candidates.map((candidate) => candidate.displayName).join(', ')}';
    }
    return 'Necesita revisión manual';
  }
}

class SolutionCard extends StatelessWidget {
  const SolutionCard({
    super.key,
    required this.solution,
    required this.recommended,
  });
  final PackageSolution solution;
  final bool recommended;
  @override
  Widget build(BuildContext context) {
    final price = solution.totalAmountMinor == null
        ? 'Precio a cotizar'
        : '${_money(solution.totalAmountMinor!, solution.currency ?? 'MXN')} total';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recommended ? 'Mejor coincidencia' : 'Alternativa',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (recommended) const _StatusChip(status: 'recomendado'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${solution.coveragePercent.toStringAsFixed(0)}% cubierto · ${solution.locationCount} sucursal${solution.locationCount == 1 ? '' : 'es'} · $price',
            ),
            if (solution.requiresQuote) ...[
              const SizedBox(height: 8),
              Text(
                'Algún precio no está publicado; confirma directamente con el proveedor.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            ...solution.locations.map(
              (location) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(location.name),
                subtitle: Text(
                  location.providerName +
                      (location.distanceMeters == null
                          ? ''
                          : ' · ${_distance(location.distanceMeters!)}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service});
  final SearchService service;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    service.displayName,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                _StatusChip(
                  status: service.resolutionStatus == 'ambiguous'
                      ? 'ambiguous'
                      : '${(service.confidence * 100).toStringAsFixed(0)}% match',
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (service.offers.isEmpty)
              const Text('No hay una oferta comercial vigente para mostrar.'),
            ...service.offers.map((offer) => _OfferRow(offer: offer)),
          ],
        ),
      ),
    ),
  );
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer});
  final SearchOffer offer;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(13),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = _OfferIdentity(offer: offer);
          final pricing = _OfferPricing(offer: offer);
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Align(alignment: Alignment.centerRight, child: pricing),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 16),
              Expanded(
                child: Align(alignment: Alignment.topRight, child: pricing),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _OfferIdentity extends StatelessWidget {
  const _OfferIdentity({required this.offer});
  final SearchOffer offer;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(offer.providerName, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(
        offer.locationName ?? 'Sin sucursal vinculada',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (offer.distanceMeters != null)
        Text(_distance(offer.distanceMeters!), style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _OfferPricing extends StatelessWidget {
  const _OfferPricing({required this.offer});
  final SearchOffer offer;

  @override
  Widget build(BuildContext context) {
    final priceLabel = _priceTypeLabel(offer.priceType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          offer.amountMinor == null
              ? 'Cotizar'
              : _money(offer.amountMinor!, offer.currency ?? 'MXN'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (offer.amountMinor != null && priceLabel != null)
          Text(priceLabel, style: Theme.of(context).textTheme.bodySmall),
        if (offer.amountMinor != null && offer.locationName == null)
          Text(
            'Precio no asociado a una sucursal',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (offer.prices.length > 1)
          ...offer.prices
              .where(
                (price) =>
                    price.amountMinor != null &&
                    (price.amountMinor != offer.amountMinor ||
                        price.type != offer.priceType),
              )
              .map(
                (price) => Text(
                  '${_priceTypeLabel(price.type) ?? 'Precio'}: ${_money(price.amountMinor!, price.currency ?? offer.currency ?? 'MXN')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
        if (offer.lastSeenAt != null)
          Text(
            'Fuente actualizada ${_date(offer.lastSeenAt!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (offer.sourceUrl != null)
          TextButton.icon(
            onPressed: () => _open(offer.sourceUrl!),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(
              offer.locationName == null
                  ? 'Ver fuente del proveedor'
                  : 'Ver fuente de sucursal',
            ),
          )
        else
          Text(
            'Fuente no disponible',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

String? _priceTypeLabel(String? value) => switch (value) {
  'online' => 'Precio en línea',
  'regular' => 'Precio regular',
  null || '' => null,
  _ => value,
};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.preferences,
    required this.themeMode,
    required this.onThemeChanged,
  });
  final PatientPreferences preferences;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode) onThemeChanged;
  @override
  Widget build(BuildContext context) => _PageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('PRIVACIDAD Y PREFERENCIAS'),
        Text(
          'Ajustes',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 22),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Apariencia'),
                subtitle: const Text(
                  'Se aplica a la PWA y a futuras apps móviles',
                ),
                leading: const Icon(Icons.palette_outlined),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Sistema'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Claro'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Oscuro'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onThemeChanged(value);
                  },
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('Datos sensibles'),
                subtitle: Text(
                  'Pruevia no guarda recetas, fotos OCR ni resultados en este dispositivo.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Consentimiento anónimo'),
                subtitle: Text(
                  preferences.consentGiven
                      ? 'Activo para mejorar el producto sin guardar texto médico.'
                      : 'No concedido.',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PageFrame extends StatefulWidget {
  const _PageFrame({required this.child});
  final Widget child;
  @override
  State<_PageFrame> createState() => _PageFrameState();
}

class _PageFrameState extends State<_PageFrame> {
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Browser buttons and text fields can keep primary focus after a search.
    // A hardware-key handler lets page navigation still reach this page's
    // scroll controller without stealing arrow keys from an editable field.
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollBy(double factor) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + position.viewportDimension * factor)
        .clamp(0.0, position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  void _scrollTo(double value) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _scrollController.animateTo(
      value.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (!_focusNode.hasFocus || event is! KeyDownEvent) return false;
    final primaryContext = FocusManager.instance.primaryFocus?.context;
    if (primaryContext?.widget is EditableText ||
        primaryContext?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.pageDown:
        _scrollBy(.9);
        return true;
      case LogicalKeyboardKey.pageUp:
        _scrollBy(-.9);
        return true;
      case LogicalKeyboardKey.arrowDown:
        _scrollBy(.15);
        return true;
      case LogicalKeyboardKey.arrowUp:
        _scrollBy(-.15);
        return true;
      case LogicalKeyboardKey.home:
        _scrollTo(0);
        return true;
      case LogicalKeyboardKey.end:
        if (_scrollController.hasClients) {
          _scrollTo(_scrollController.position.maxScrollExtent);
        }
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.pageDown):
            () => _scrollBy(.9),
        const SingleActivator(LogicalKeyboardKey.pageUp):
            () => _scrollBy(-.9),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            () => _scrollBy(.15),
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            () => _scrollBy(-.15),
        const SingleActivator(LogicalKeyboardKey.home): () => _scrollTo(0),
        const SingleActivator(LogicalKeyboardKey.end):
            () => _scrollTo(_scrollController.hasClients ? _scrollController.position.maxScrollExtent : 0),
      },
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: kIsWeb,
          interactive: kIsWeb,
          child: SingleChildScrollView(
            controller: _scrollController,
            primary: false,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PrueviaLogo extends StatelessWidget {
  const PrueviaLogo({super.key, required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 30 : 40,
          height: compact ? 30 : 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(compact ? 9 : 12),
          ),
          child: Icon(
            Icons.add_location_alt_outlined,
            color: Theme.of(context).colorScheme.onPrimary,
            size: compact ? 19 : 25,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Pruevia',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(text, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.text});
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.search_off, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(text),
        ],
      ),
    ),
  );
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.query, required this.count});
  final String query;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Resultados para “$query”',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      _StatusChip(status: '$count servicio${count == 1 ? '' : 's'}'),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = _statusTone(status, scheme);
    return Chip(
      label: Text(tone.label),
      visualDensity: VisualDensity.compact,
      backgroundColor: tone.color.withValues(alpha: .16),
      side: BorderSide(color: tone.color.withValues(alpha: .55)),
      labelStyle: TextStyle(
        color: tone.color,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

({String label, Color color}) _statusTone(String status, ColorScheme scheme) {
  final confidence = RegExp(r'^(\d+)% match$').firstMatch(status);
  if (confidence != null) {
    return (
      label: '${confidence.group(1)}% coincidencia',
      color: scheme.primary,
    );
  }
  final dark = scheme.brightness == Brightness.dark;
  return switch (status) {
    'resolved' => (
      label: 'Encontrado',
      color: dark ? const Color(0xFF86EFAC) : PrueviaColors.success,
    ),
    'ambiguous' => (
      label: 'Revisión necesaria',
      color: dark ? const Color(0xFFFCD34D) : PrueviaColors.warning,
    ),
    'no_match' => (
      label: 'Sin coincidencia',
      color: dark ? const Color(0xFFFCA5A5) : PrueviaColors.danger,
    ),
    'recomendado' => (label: 'Recomendado', color: scheme.primary),
    'ready' => (label: 'Listo', color: PrueviaColors.success),
    'partial' => (label: 'Parcial', color: PrueviaColors.warning),
    _ => (label: status, color: scheme.outline),
  };
}

String _money(int minor, String currency) =>
    '${currency == 'MXN' ? '\$' : '$currency '}${(minor / 100).toStringAsFixed(2)}';
String _distance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';
String _date(String value) =>
    value.length >= 10 ? value.substring(0, 10) : value;

Future<void> _open(String value) async {
  final uri = Uri.tryParse(value);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}
