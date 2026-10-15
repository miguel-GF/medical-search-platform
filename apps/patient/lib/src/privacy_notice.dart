import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'local_preferences.dart';

class PrivacyNoticeLink extends StatelessWidget {
  const PrivacyNoticeLink({super.key, required this.policyUri, this.compact = false});

  final Uri policyUri;
  final bool compact;

  Future<void> _open(BuildContext context) async {
    try {
      final opened = await launchUrl(
        policyUri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
        content: Text('No pudimos abrir el aviso. Visita pruevia.com.mx/privacidad.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => compact
      ? IconButton(
          tooltip: 'Aviso de privacidad',
          onPressed: () => _open(context),
          icon: const Icon(Icons.privacy_tip_outlined),
        )
      : TextButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(Icons.policy_outlined, size: 18),
          label: const Text('Aviso de privacidad'),
        );
}

class PrivacyNoticeReminder extends StatefulWidget {
  const PrivacyNoticeReminder({
    super.key,
    required this.preferences,
    required this.policyUri,
  });

  final PatientPreferences preferences;
  final Uri policyUri;

  @override
  State<PrivacyNoticeReminder> createState() => _PrivacyNoticeReminderState();
}

class _PrivacyNoticeReminderState extends State<PrivacyNoticeReminder>
    with WidgetsBindingObserver {
  Timer? _clock;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check an open session too, without recording navigation or usage.
    _clock = Timer.periodic(const Duration(hours: 1), (_) => _refresh());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _acknowledge() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.preferences.acknowledgePrivacyNotice();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos guardar esta preferencia. Puedes seguir usando Pruevia.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.preferences.privacyNoticeReminderDue()) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tu privacidad en Pruevia',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text(
              'Consulta cómo cuidamos tu información. «Entendido» oculta este recordatorio durante 180 días. Las autorizaciones para leer una orden o medir el uso se solicitan por separado.',
            ),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PrivacyNoticeLink(policyUri: widget.policyUri),
                TextButton(
                  onPressed: _saving ? null : _acknowledge,
                  child: Text(_saving ? 'Guardando…' : 'Entendido'),
                ),
              ],
            ),
            Text(
              'Puede aparecer de nuevo si cambia el aviso, borras los datos o usas otro navegador.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }
}
