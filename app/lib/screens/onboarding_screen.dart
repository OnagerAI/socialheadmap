import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  bool _consentGeneral = false;
  bool _consentPolitical = false;
  bool _consentAge = false;
  bool _consentRegion = false;

  bool get _allConsented => _consentGeneral && _consentPolitical && _consentAge && _consentRegion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_page + 1) / 3, color: ShmTheme.primary),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [_page0(), _page1(), _page2()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page0() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.map_outlined, size: 80, color: ShmTheme.primary),
        const SizedBox(height: 24),
        const Text('SocialHeadmap', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text(
          'Stimme anonym über wichtige gesellschaftliche Fragen ab und sieh, wie Deutschland wirklich denkt.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 32),
        const _FeatureRow(Icons.lock_outline, 'Vollständig anonym', 'Kein Name, kein Login, kein Tracking'),
        const SizedBox(height: 12),
        const _FeatureRow(Icons.map, 'Interaktive Karte', 'Sieh Ergebnisse nach Landkreis aufgeschlüsselt'),
        const SizedBox(height: 12),
        const _FeatureRow(Icons.shield_outlined, 'Privacy by Design', 'Deine PLZ wird niemals gespeichert'),
        const Spacer(),
        ElevatedButton(
          onPressed: () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
          child: const Text('Weiter'),
        ),
      ],
    ),
  );

  Widget _page1() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Datenschutz & Einwilligung', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'SocialHeadmap verarbeitet besondere Kategorien personenbezogener Daten (Art. 9 DSGVO). Bitte lies die folgenden Erklärungen sorgfältig.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        _ConsentCard(
          title: 'Allgemeine Datenverarbeitung',
          description: 'Zur Verhinderung von Doppelabstimmungen wird auf deinem Gerät ein anonymes Token (UUID) gespeichert. Es enthält keine persönlichen Informationen.',
          legalBasis: 'Art. 6(1)(a) DSGVO — Einwilligung',
          value: _consentGeneral,
          onChanged: (v) => setState(() => _consentGeneral = v ?? false),
        ),
        _ConsentCard(
          title: 'Politische & gesellschaftliche Meinungen (Art. 9 DSGVO)',
          description: 'Einige Fragen betreffen politische Meinungen oder weltanschauliche Überzeugungen. Diese Daten werden anonym und ausschließlich aggregiert auf Landkreis-Ebene gespeichert.',
          legalBasis: 'Art. 9(2)(a) DSGVO — Explizite Einwilligung',
          value: _consentPolitical,
          onChanged: (v) => setState(() => _consentPolitical = v ?? false),
          isArticle9: true,
        ),
        _ConsentCard(
          title: 'Altersgruppe',
          description: 'Dein ungefähres Alter (10-Jahres-Gruppe: z.B. 30–39 Jahre) wird gespeichert. Das genaue Alter oder Geburtsdatum wird nicht verarbeitet.',
          legalBasis: 'Art. 6(1)(a) DSGVO — Einwilligung',
          value: _consentAge,
          onChanged: (v) => setState(() => _consentAge = v ?? false),
        ),
        _ConsentCard(
          title: 'Region (Landkreis)',
          description: 'Du gibst deine Postleitzahl an — diese wird sofort in eine Landkreis-ID umgewandelt und dann verworfen. Nur der Landkreis wird gespeichert (~200.000 Einwohner).',
          legalBasis: 'Art. 6(1)(a) DSGVO — Einwilligung',
          value: _consentRegion,
          onChanged: (v) => setState(() => _consentRegion = v ?? false),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black54, fontSize: 12),
            children: [
              const TextSpan(text: 'Du kannst deine Einwilligung jederzeit widerrufen. Mehr in der '),
              TextSpan(
                text: 'Datenschutzerklärung',
                style: const TextStyle(color: ShmTheme.primary, decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse('https://shm.13-61-179-136.nip.io/legal')),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _allConsented
              ? () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
              : null,
          child: const Text('Einwilligungen bestätigen'),
        ),
        if (!_allConsented)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Bitte allen Punkten zustimmen um fortzufahren.', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    ),
  );

  Widget _page2() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, size: 80, color: ShmTheme.yes),
        const SizedBox(height: 24),
        const Text('Alles bereit!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text(
          'Jetzt noch kurz dein Profil einrichten — damit können wir Ergebnisse nach Alter und Region aufschlüsseln.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () async {
            await StorageService.setOnboardingDone();
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            }
          },
          child: const Text('Profil einrichten'),
        ),
      ],
    ),
  );
}

class _ConsentCard extends StatelessWidget {
  final String title, description, legalBasis;
  final bool value, isArticle9;
  final ValueChanged<bool?> onChanged;

  const _ConsentCard({
    required this.title,
    required this.description,
    required this.legalBasis,
    required this.value,
    required this.onChanged,
    this.isArticle9 = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isArticle9 ? const Color(0xFFFFF8E1) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: value, onChanged: onChanged, activeColor: ShmTheme.primary),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      if (isArticle9)
                        const Chip(
                          label: Text('Art. 9', style: TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: Colors.orange,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text(legalBasis, style: const TextStyle(fontSize: 11, color: ShmTheme.primary, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _FeatureRow(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ShmTheme.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
