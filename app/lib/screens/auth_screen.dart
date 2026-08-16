import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
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
  final _plzCtrl = TextEditingController();
  String _ageGroup = 'B';
  bool _loading = false;
  String? _sentToEmail;

  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
  static final _plzRegex = RegExp(r'^\d{5}$');

  // Google Sign-In: serverClientId muss mit dem Web-Client in der Google
  // Cloud Console übereinstimmen (per --dart-define gesetzt).
  static final _googleSignIn = GoogleSignIn(
    serverClientId: const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    ),
  );

  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _plzCtrl.dispose();
    super.dispose();
  }

  // ── Aktionen ──────────────────────────────────────────────────────────────

  Future<void> _requestMagicLink() async {
    final email = _emailCtrl.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      showShmSnack(context, 'Bitte gib eine gültige E-Mail-Adresse ein.',
          error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.requestMagicLink(email);
      setState(() {
        _sentToEmail = email;
        _mode = 'email_sent';
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showShmSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _verifyToken() async {
    final token = _tokenCtrl.text.trim();
    if (token.length != 64) {
      showShmSnack(context, 'Der Code muss genau 64 Zeichen lang sein.',
          error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await ApiService.verifyMagicLink(token);
      await AuthService.saveAuth(
        jwt: data['jwt'] as String,
        username: data['username'] as String,
        provider: data['provider'] as String,
      );
      _goHome();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showShmSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loading = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [], // bewusst keine Scopes — wir brauchen weder Name noch E-Mail
      );
      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('apple_no_id_token');
      final data = await ApiService.socialLogin('apple', idToken);
      await AuthService.saveAuth(
        jwt: data['jwt'] as String,
        username: data['username'] as String,
        provider: data['provider'] as String,
      );
      _goHome();
    } on SignInWithAppleAuthorizationException catch (e) {
      setState(() => _loading = false);
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (mounted) {
        showShmSnack(context, 'Apple-Anmeldung fehlgeschlagen. Bitte erneut versuchen.',
            error: true);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showShmSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await _googleSignIn.signOut(); // vorherigen Account vergessen
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('google_no_id_token');
      final data = await ApiService.socialLogin('google', idToken);
      await AuthService.saveAuth(
        jwt: data['jwt'] as String,
        username: data['username'] as String,
        provider: data['provider'] as String,
      );
      _goHome();
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      final msg = e.toString();
      showShmSnack(
        context,
        msg.contains('google_token') || msg.contains('10')
            ? 'Google-Anmeldung fehlgeschlagen. Konfiguration prüfen (google-services.json).'
            : errorMessage(e),
        error: true,
      );
    }
  }

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
      final data = await ApiService.socialLogin('facebook', token);
      await AuthService.saveAuth(
        jwt: data['jwt'] as String,
        username: data['username'] as String,
        provider: data['provider'] as String,
      );
      _goHome();
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      final msg = e.toString();
      showShmSnack(
        context,
        msg.contains('APP_ID') || msg.contains('Invalid')
            ? 'Facebook-App-ID nicht konfiguriert.'
            : errorMessage(e),
        error: true,
      );
    }
  }

  Future<void> _registerDevice() async {
    final plz = _plzCtrl.text.trim();
    if (!_plzRegex.hasMatch(plz)) {
      showShmSnack(
          context, 'Bitte gib eine gültige 5-stellige Postleitzahl ein.',
          error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final deviceToken = await StorageService.getOrCreateDeviceToken();
      await ApiService.register(deviceToken);
      await StorageService.saveUserProfile(ageGroup: _ageGroup, plz: plz);
      await StorageService.setRegistered();
      _goHome();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showShmSnack(context, errorMessage(e), error: true);
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_mode) {
          'email' => _buildEmailForm(),
          'email_sent' => _buildEmailSentScreen(),
          'device' => _buildDeviceForm(),
          _ => _buildChooseScreen(),
        },
      ),
    );
  }

  Widget _backButton() => Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _mode = 'choose'),
        ),
      );

  // ── Startseite: Methode wählen ────────────────────────────────────────────

  Widget _buildChooseScreen() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(ShmTheme.radiusXl),
            ),
            child: Icon(Icons.map_outlined,
                size: 44, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: ShmTheme.gapL),
          Text('Anmelden', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ShmTheme.gapS),
          Text(
            'Wähle, wie du dich anmelden möchtest.\nDeine Abstimmungen bleiben immer anonym.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 36),
          if (!kIsWeb && Platform.isIOS) ...[
            _ProviderButton(
              icon: Icons.apple,
              label: 'Mit Apple anmelden',
              subtitle: 'Apple-ID verwenden',
              onTap: _loading ? null : _signInWithApple,
            ),
            const SizedBox(height: ShmTheme.gapM),
          ],
          _ProviderButton(
            icon: Icons.email_outlined,
            label: 'Mit E-Mail anmelden',
            subtitle: 'Einmal-Link per Mail — kein Passwort nötig',
            onTap: _loading ? null : () => setState(() => _mode = 'email'),
          ),
          const SizedBox(height: ShmTheme.gapM),
          _ProviderButton(
            icon: Icons.g_mobiledata_rounded,
            label: 'Mit Google anmelden',
            subtitle: 'Google-Konto verwenden',
            onTap: _loading ? null : _signInWithGoogle,
          ),
          const SizedBox(height: ShmTheme.gapM),
          _ProviderButton(
            icon: Icons.facebook_rounded,
            label: 'Mit Facebook anmelden',
            subtitle: 'Facebook- oder Instagram-Konto',
            onTap: _loading ? null : _signInWithFacebook,
          ),
          const SizedBox(height: ShmTheme.gapXl + 8),
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ShmTheme.gapM),
              child: Text('oder',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: ShmTheme.gapXl - 4),
          OutlinedButton.icon(
            onPressed:
                _loading ? null : () => setState(() => _mode = 'device'),
            icon: const Icon(Icons.devices_other_outlined),
            label: const Text('Anonym ohne Konto fortfahren'),
          ),
          const SizedBox(height: ShmTheme.gapL),
          Text(
            'Ohne Konto: Abstimmungen nur auf diesem Gerät. Kein Profil übertragbar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
        ],
      ),
    );
  }

  // ── E-Mail-Formular ───────────────────────────────────────────────────────

  Widget _buildEmailForm() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backButton(),
          const SizedBox(height: ShmTheme.gapL),
          Text('E-Mail-Adresse',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ShmTheme.gapS),
          Text(
            'Wir senden dir einen Einmal-Link. Deine E-Mail wird niemals gespeichert.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'E-Mail-Adresse',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            onSubmitted: (_) => _loading ? null : _requestMagicLink(),
          ),
          const SizedBox(height: ShmTheme.gapXl - 4),
          FilledButton(
            onPressed: _loading ? null : _requestMagicLink,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Login-Link senden'),
          ),
        ],
      ),
    );
  }

  // ── E-Mail gesendet ───────────────────────────────────────────────────────

  Widget _buildEmailSentScreen() {
    final scheme = Theme.of(context).colorScheme;
    final shm = context.shm;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: shm.yesContainer,
            child:
                Icon(Icons.mark_email_read_outlined, size: 36, color: shm.yes),
          ),
          const SizedBox(height: ShmTheme.gapXl),
          Text('Link gesendet!',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            'Prüfe dein Postfach bei\n$_sentToEmail',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6),
          ),
          const SizedBox(height: ShmTheme.gapXs),
          Text(
            'Der Link ist 15 Minuten gültig.',
            style: TextStyle(color: scheme.outline, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(ShmTheme.gapL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Code aus dem Link eingeben',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: ShmTheme.gapXs),
                  Text(
                    'Kopiere den 64-stelligen Code aus der URL des Login-Links (nach ?t=).',
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: ShmTheme.gapM),
                  TextField(
                    controller: _tokenCtrl,
                    maxLength: 64,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'abc123…',
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
                  const SizedBox(height: ShmTheme.gapM),
                  FilledButton(
                    onPressed: _loading ? null : _verifyToken,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Anmelden'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ShmTheme.gapL),
          TextButton(
            onPressed: () => setState(() {
              _mode = 'email';
              _tokenCtrl.clear();
            }),
            child: const Text('Anderen Link anfordern'),
          ),
        ],
      ),
    );
  }

  // ── Gerät-only (anonym) ───────────────────────────────────────────────────

  Widget _buildDeviceForm() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backButton(),
          const SizedBox(height: ShmTheme.gapL),
          Text('Anonym fortfahren',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ShmTheme.gapS),
          Text(
            'Ohne Konto: Abstimmungen werden nur auf diesem Gerät gespeichert.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 28),
          const Text('Altersgruppe',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: ShmTheme.gapS,
            runSpacing: ShmTheme.gapS,
            children: [
              for (final entry in ageLabels.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _ageGroup == entry.key,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _ageGroup = entry.key),
                ),
            ],
          ),
          const SizedBox(height: ShmTheme.gapXl),
          const Text('Postleitzahl',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: ShmTheme.gapXs),
          Text(
            'Wird sofort in einen Landkreis umgewandelt und verworfen — nie gespeichert.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _plzCtrl,
            keyboardType: TextInputType.number,
            maxLength: 5,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Postleitzahl',
              hintText: 'z. B. 80331',
              prefixIcon: Icon(Icons.location_on_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _loading ? null : _registerDevice,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Loslegen'),
          ),
        ],
      ),
    );
  }
}

// ── Provider-Button Widget ─────────────────────────────────────────────────────

class _ProviderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _ProviderButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ShmTheme.radiusM),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: ShmTheme.gapL + 2, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(ShmTheme.radiusM),
          color: scheme.surface,
        ),
        child: Row(children: [
          Icon(icon, size: 26, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.outline),
        ]),
      ),
    );
  }
}
