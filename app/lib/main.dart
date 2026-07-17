import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'constants.dart';
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
    final isRegistered = await StorageService.isRegistered();
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
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  /// Magic Link: https://<host>/auth/magic-link/open?t=<token>
  ///         oder socialheadmap://auth?t=<token>
  Future<void> _handleDeepLink(Uri uri) async {
    final token = uri.queryParameters['t'];
    if (token == null || token.length != 64) return;

    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    var overlayOpen = true;
    showDialog(
      context: nav.context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).whenComplete(() => overlayOpen = false);

    void closeOverlay() {
      if (overlayOpen && nav.mounted) nav.pop();
    }

    try {
      final data = await ApiService.verifyMagicLink(token);
      await AuthService.saveAuth(
        jwt: data['jwt'] as String,
        username: data['username'] as String,
        provider: data['provider'] as String,
      );
      closeOverlay();
      if (nav.mounted) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      closeOverlay();
      if (!nav.mounted) return;
      ScaffoldMessenger.maybeOf(nav.context)?.showSnackBar(
        SnackBar(content: Text(errorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SocialHeadmap',
      theme: ShmTheme.light,
      darkTheme: ShmTheme.dark,
      themeMode: ThemeMode.system,
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
