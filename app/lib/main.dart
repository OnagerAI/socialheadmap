import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Widget startScreen;
  if (await AuthService.isLoggedIn()) {
    startScreen = const HomeScreen();
  } else {
    final isOnboardingDone = await StorageService.isOnboardingDone();
    final isRegistered     = await StorageService.isRegistered();
    if (isOnboardingDone && isRegistered) {
      startScreen = const HomeScreen();
    } else if (isOnboardingDone) {
      startScreen = const AuthScreen();
    } else {
      startScreen = const OnboardingScreen();
    }
  }

  runApp(SocialHeadmapApp(startScreen: startScreen));
}

class SocialHeadmapApp extends StatefulWidget {
  final Widget startScreen;
  const SocialHeadmapApp({super.key, required this.startScreen});

  @override
  State<SocialHeadmapApp> createState() => _SocialHeadmapAppState();
}

class _SocialHeadmapAppState extends State<SocialHeadmapApp> {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) => _handleDeepLink(uri));
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Magic Link: https://shm.13-61-179-136.nip.io/auth/magic-link/open?t=<token>
    //         oder: socialheadmap://auth?t=<token>
    final token = uri.queryParameters['t'];
    if (token == null || token.length != 64) return;

    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    // Lade-Overlay anzeigen
    showDialog(
      context: nav.context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = await ApiService.verifyMagicLink(token);
      await AuthService.saveAuth(
        jwt:      data['jwt'] as String,
        username: data['username'] as String,
        provider: data['provider'] as String,
      );
      nav.pop(); // Overlay schließen
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      nav.pop(); // Overlay schließen
      ScaffoldMessenger.of(nav.context).showSnackBar(
        SnackBar(
          content: Text(_deepLinkError(e.toString())),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  String _deepLinkError(String msg) {
    if (msg.contains('token_already_used')) {
      return 'Dieser Login-Link wurde bereits verwendet.';
    }
    if (msg.contains('token_expired')) {
      return 'Der Login-Link ist abgelaufen. Bitte fordere einen neuen an.';
    }
    return 'Anmeldung fehlgeschlagen. Bitte erneut versuchen.';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SocialHeadmap',
      theme: ShmTheme.theme,
      navigatorKey: _navigatorKey,
      home: widget.startScreen,
      routes: {
        '/auth': (_) => const AuthScreen(),
        '/home': (_) => const HomeScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
