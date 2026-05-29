import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Modi: 'choose' | 'email' | 'email_sent' | 'device'
  String _mode = 'choose';

  final _emailCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _plzCtrl   = TextEditingController();
  String _ageGroup = 'B';
  bool   _loading  = false;
  String? _sentToEmail;

  static const _ageGroups = [
    ('A', '18–29'), ('B', '30–39'), ('C', '40–49'),
    ('D', '50–59'), ('E', '60+'),
  ];

  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');

  // Google Sign-In: serverClientId muss mit dem Web-Client im Google Cloud Console übereinstimmen.
  // Placeholder → wird durch echten Client-ID ersetzt wenn google-services.json konfiguriert ist.
  static final _googleSignIn = GoogleSignIn(
    serverClientId: const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    ),
  );

  // ── Magic Link anfordern ──────────────────────────────────────────────────

  Future<void> _requestMagicLink() async {
    final email = _emailCtrl.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      _snack('Bitte gib eine gültige E-Mail-Adresse ein.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.requestMagicLink(email);
      setState(() { _sentToEmail = email; _mode = 'email_sent'; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Fehler beim Senden: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  // ── Magic Link Token verifizieren ────────────────────────────────────────

  Future<void> _verifyToken() async {
    final token = _tokenCtrl.text.trim();
    if (token.length != 64) {
      _snack('Der Code muss genau 64 Zeichen lang sein.');
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await ApiService.verifyMagicLink(token);
      await AuthService.saveAuth(
        jwt:      data['jwt'] as String,
        username: data['username'] as String,
        provider: data['provider'] as String,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
      }
    } catch (e) {
      setState(() => _loading = false);
      final msg = e.toString().replaceAll('Exception: ', '');
      _snack(switch (msg) {
        'token_already_used' =>
            'Dieser Link wurde bereits verwendet. Bitte fordere einen neuen an.',
        'token_expired' =>
            'Der Link ist abgelaufen (15 min). Bitte fordere einen neuen an.',
        'token_not_found' => 'Ungültiger Code. Bitte prüfe die Eingabe.',
        _ => 'Fehler: $msg',
      });
    }
  }

  // ── Google Sign-In ───────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await _googleSignIn.signOut(); // vorherigen Account vergessen
      final account = await _googleSignIn.signIn();
      if (account == null) { setState(() => _loading = false); return; }
      final auth    = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('google_no_id_token');
      final data = await ApiService.socialLogin('google', idToken);
      await AuthService.saveAuth(
        jwt:      data['jwt'] as String,
        username: data['username'] as String,
        provider: data['provider'] as String,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
      }
    } catch (e) {
      setState(() => _loading = false);
      final msg = e.toString().replaceAll('Exception: ', '');
      _snack(msg.contains('google_token') || msg.contains('10')
          ? 'Google-Anmeldung fehlgeschlagen. Bitte google-services.json konfigurieren.'
          : 'Google-Fehler: $msg');
    }
  }

  // ── Facebook Sign-In ─────────────────────────────────────────────────────

  Future<void> _signInWithFacebook() async {
    setState(() => _loading = true);
    try {
      final result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.cancelled) {
        setState(() => _loading = false);
        return;
      }
      if (result.status != LoginStatus.success || result.accessToken == null) {
        throw Exception(result.message ?? 'facebook_login_failed');
      }
      final token = result.accessToken!.tokenString;
      final data  = await ApiService.socialLogin('facebook', token);
      await AuthService.saveAuth(
        jwt:      data['jwt'] as String,
        username: data['username'] as String,
        provider: data['provider'] as String,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
      }
    } catch (e) {
      setState(() => _loading = false);
      final msg = e.toString().replaceAll('Exception: ', '');
      _snack(msg.contains('APP_ID') || msg.contains('Invalid')
          ? 'Facebook-App-ID nicht konfiguriert. Bitte strings.xml aktualisieren.'
          : 'Facebook-Fehler: $msg');
    }
  }

  // ── Gerät-only Registrierung (anonym, kein JWT) ───────────────────────────

  Future<void> _registerDevice() async {
    final plz = _plzCtrl.text.trim();
    if (plz.length < 4) {
      _snack('Bitte gib eine gültige Postleitzahl ein (mind. 4 Stellen).');
      return;
    }
    setState(() => _loading = true);
    try {
      final deviceToken = await StorageService.getOrCreateDeviceToken();
      await ApiService.register(deviceToken);
      await StorageService.saveUserProfile(ageGroup: _ageGroup, plz: plz);
      await StorageService.setRegistered();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
      }
    } catch (e) {
      setState(() => _loading = false);
      _snack('Fehler: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ShmTheme.no));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: switch (_mode) {
          'email'      => _buildEmailForm(),
          'email_sent' => _buildEmailSentScreen(),
          'device'     => _buildDeviceForm(),
          _            => _buildChooseScreen(),
        },
      ),
    );
  }

  // ── Startseite: Methode wählen ────────────────────────────────────────────

  Widget _buildChooseScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Icon(Icons.map_outlined, size: 64, color: ShmTheme.primary),
        const SizedBox(height: 16),
        const Text('Anmelden',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Wähle, wie du dich anmelden möchtest.\nDeine Abstimmungen bleiben immer anonym.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
        ),
        const SizedBox(height: 40),
        _ProviderButton(
          icon: Icons.email_outlined,
          label: 'Mit E-Mail anmelden',
          subtitle: 'Einmal-Link per Mail — kein Passwort nötig',
          onTap: () => setState(() => _mode = 'email'),
        ),
        const SizedBox(height: 12),
        _ProviderButton(
          icon: Icons.g_mobiledata_rounded,
          label: 'Mit Google anmelden',
          subtitle: 'Google-Konto verwenden',
          onTap: _loading ? null : _signInWithGoogle,
        ),
        const SizedBox(height: 12),
        _ProviderButton(
          icon: Icons.facebook_rounded,
          label: 'Mit Facebook anmelden',
          subtitle: 'Facebook- oder Instagram-Konto',
          onTap: _loading ? null : _signInWithFacebook,
        ),
        const SizedBox(height: 32),
        const Row(children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('oder', style: TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Divider()),
        ]),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => setState(() => _mode = 'device'),
          icon: const Icon(Icons.devices_other_outlined),
          label: const Text('Anonym ohne Konto fortfahren'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: Colors.grey.shade300),
            foregroundColor: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ohne Konto: Abstimmungen nur auf diesem Gerät. Kein Profil übertragbar.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        ),
      ]),
    );
  }

  // ── E-Mail-Formular ───────────────────────────────────────────────────────

  Widget _buildEmailForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _mode = 'choose')),
        const SizedBox(height: 16),
        const Text('E-Mail-Adresse',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Wir senden dir einen Einmal-Link. Deine E-Mail wird niemals gespeichert.',
          style: TextStyle(color: Colors.grey.shade600, height: 1.5),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'E-Mail-Adresse',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _loading ? null : _requestMagicLink(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 50,
          child: FilledButton(
            onPressed: _loading ? null : _requestMagicLink,
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Login-Link senden', style: TextStyle(fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  // ── E-Mail gesendet ───────────────────────────────────────────────────────

  Widget _buildEmailSentScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const SizedBox(height: 24),
        CircleAvatar(
          radius: 36,
          backgroundColor: Colors.green.shade50,
          child: Icon(Icons.mark_email_read_outlined,
              size: 36, color: Colors.green.shade600),
        ),
        const SizedBox(height: 24),
        const Text('Link gesendet!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(
          'Prüfe dein Postfach bei\n$_sentToEmail',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.6),
        ),
        const SizedBox(height: 4),
        Text(
          'Der Link ist 15 Minuten gültig.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        const SizedBox(height: 36),

        // Token manuell eingeben (Fallback bis Deep Links in Story #202 kommen)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Code aus dem Link eingeben',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
            const SizedBox(height: 4),
            Text(
              'Kopiere den 64-stelligen Code aus der URL des Login-Links (nach ?t=).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenCtrl,
              maxLength: 64,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                hintText: 'abc123...',
                border: const OutlineInputBorder(),
                counterText: '',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_outlined),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _tokenCtrl.text = data!.text!.trim();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _verifyToken,
                child: _loading
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Anmelden'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() { _mode = 'email'; _tokenCtrl.clear(); }),
          child: const Text('Anderen Link anfordern'),
        ),
      ]),
    );
  }

  // ── Gerät-only (anonym) ───────────────────────────────────────────────────

  Widget _buildDeviceForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _mode = 'choose')),
        const SizedBox(height: 16),
        const Text('Anonym fortfahren',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Ohne Konto: Abstimmungen werden nur auf diesem Gerät gespeichert.',
          style: TextStyle(color: Colors.grey.shade600, height: 1.5),
        ),
        const SizedBox(height: 28),
        const Text('Altersgruppe',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _ageGroups.map((ag) => ChoiceChip(
            label: Text(ag.$2),
            selected: _ageGroup == ag.$1,
            selectedColor: ShmTheme.primary,
            labelStyle: TextStyle(
                color: _ageGroup == ag.$1 ? Colors.white : null),
            onSelected: (_) => setState(() => _ageGroup = ag.$1),
          )).toList(),
        ),
        const SizedBox(height: 24),
        const Text('Postleitzahl',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 4),
        Text(
          'Wird sofort in einen Landkreis umgewandelt und verworfen — nie gespeichert.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _plzCtrl,
          keyboardType: TextInputType.number,
          maxLength: 5,
          decoration: const InputDecoration(
            labelText: 'Postleitzahl',
            prefixIcon: Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity, height: 50,
          child: FilledButton(
            onPressed: _loading ? null : _registerDevice,
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Loslegen', style: TextStyle(fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}

// ── Provider-Button Widget ─────────────────────────────────────────────────────

class _ProviderButton extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final String        subtitle;
  final VoidCallback? onTap;
  final bool          disabled;

  const _ProviderButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
                color: disabled ? Colors.grey.shade200 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon,
                size: 26,
                color: disabled ? Colors.grey : ShmTheme.primary),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: disabled ? Colors.grey : Colors.black87)),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            Icon(Icons.chevron_right,
                color: disabled
                    ? Colors.grey.shade300
                    : Colors.grey.shade400),
          ]),
        ),
      ),
    );
  }
}
