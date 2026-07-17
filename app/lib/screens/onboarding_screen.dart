import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
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

  bool get _allConsented =>
      _consentGeneral && _consentPolitical && _consentAge && _consentRegion;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() => _controller.nextPage(
      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  ShmTheme.gapXl, ShmTheme.gapM, ShmTheme.gapXl, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_page + 1) / 3,
                  minHeight: 5,
                ),
              ),
            ),
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

  Widget _page0() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(ShmTheme.gapXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(ShmTheme.radiusXl),
            ),
            child: Icon(Icons.map_outlined,
                size: 52, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: ShmTheme.gapXl),
          Text('SocialHeadmap',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 26)),
          const SizedBox(height: ShmTheme.gapM),
          Text(
            'Stimme anonym über wichtige gesellschaftliche Fragen ab und sieh, wie Deutschland wirklich denkt.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 36),
          const _FeatureRow(Icons.lock_outline, 'Vollständig anonym',
              'Kein Name, kein Tracking — Login optional'),
          const SizedBox(height: ShmTheme.gapM),
          const _FeatureRow(Icons.map, 'Interaktive Karte',
              'Ergebnisse nach Bundesland und Landkreis'),
          const SizedBox(height: ShmTheme.gapM),
          const _FeatureRow(Icons.shield_outlined, 'Privacy by Design',
              'Deine PLZ wird niemals gespeichert'),
          const Spacer(),
          FilledButton(onPressed: _next, child: const Text('Weiter')),
        ],
      ),
    );
  }

  Widget _page1() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ShmTheme.gapXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: ShmTheme.gapL),
          Text('Datenschutz & Einwilligung',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ShmTheme.gapS),
          Text(
            'SocialHeadmap verarbeitet besondere Kategorien personenbezogener Daten (Art. 9 DSGVO). Bitte lies die folgenden Erklärungen sorgfältig.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: ShmTheme.gapL),
          _ConsentCard(
            title: 'Allgemeine Datenverarbeitung',
            description:
                'Zur Verhinderung von Doppelabstimmungen wird auf deinem Gerät ein anonymes Token (UUID) gespeichert. Es enthält keine persönlichen Informationen.',
            legalBasis: 'Art. 6(1)(a) DSGVO — Einwilligung',
            value: _consentGeneral,
            onChanged: (v) => setState(() => _consentGeneral = v ?? false),
          ),
          _ConsentCard(
            title: 'Politische & gesellschaftliche Meinungen',
            description:
                'Einige Fragen betreffen politische Meinungen oder weltanschauliche Überzeugungen. Diese Daten werden anonym und ausschließlich aggregiert auf Landkreis-Ebene gespeichert.',
            legalBasis: 'Art. 9(2)(a) DSGVO — Explizite Einwilligung',
            value: _consentPolitical,
            onChanged: (v) => setState(() => _consentPolitical = v ?? false),
            isArticle9: true,
          ),
          _ConsentCard(
            title: 'Altersgruppe',
            description:
                'Dein ungefähres Alter (10-Jahres-Gruppe, z. B. 30–39 Jahre) wird gespeichert. Das genaue Alter oder Geburtsdatum wird nicht verarbeitet.',
            legalBasis: 'Art. 6(1)(a) DSGVO — Einwilligung',
            value: _consentAge,
            onChanged: (v) => setState(() => _consentAge = v ?? false),
          ),
          _ConsentCard(
            title: 'Region (Landkreis)',
            description:
                'Du gibst deine Postleitzahl an — diese wird sofort in eine Landkreis-ID umgewandelt und dann verworfen. Nur der Landkreis wird gespeichert (~200.000 Einwohner).',
            legalBasis: 'Art. 6(1)(a) DSGVO — Einwilligung',
            value: _consentRegion,
            onChanged: (v) => setState(() => _consentRegion = v ?? false),
          ),
          const SizedBox(height: ShmTheme.gapS),
          RichText(
            text: TextSpan(
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
              children: [
                const TextSpan(
                    text:
                        'Du kannst deine Einwilligung jederzeit widerrufen. Mehr in der '),
                TextSpan(
                  text: 'Datenschutzerklärung',
                  style: TextStyle(
                      color: scheme.primary,
                      decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () =>
                        launchUrl(Uri.parse('${ApiService.baseUrl}/legal')),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: ShmTheme.gapL),
          FilledButton(
            onPressed: _allConsented ? _next : null,
            child: const Text('Einwilligungen bestätigen'),
          ),
          if (!_allConsented)
            Padding(
              padding: const EdgeInsets.only(top: ShmTheme.gapS),
              child: Text(
                'Bitte allen Punkten zustimmen um fortzufahren.',
                style: TextStyle(color: context.shm.no, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _page2() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(ShmTheme.gapXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(Icons.check_circle_outline, size: 80, color: context.shm.yes),
          const SizedBox(height: ShmTheme.gapXl),
          Text('Alles bereit!',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ShmTheme.gapM),
          Text(
            'Jetzt noch kurz dein Profil einrichten — damit können wir Ergebnisse nach Alter und Region aufschlüsseln.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const Spacer(),
          FilledButton(
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: ShmTheme.gapM),
      color: isArticle9
          ? scheme.tertiaryContainer.withOpacity(0.35)
          : null,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(ShmTheme.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(ShmTheme.gapM),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: value, onChanged: onChanged),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14))),
                        if (isArticle9)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.tertiary,
                              borderRadius:
                                  BorderRadius.circular(ShmTheme.radiusS),
                            ),
                            child: Text('Art. 9',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onTertiary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: ShmTheme.gapXs),
                    Text(description,
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(height: ShmTheme.gapXs),
                    Text(legalBasis,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.primary,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: scheme.primary, size: 28),
        const SizedBox(width: ShmTheme.gapM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(subtitle,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }
}
