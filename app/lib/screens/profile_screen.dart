import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'legal_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _plz;
  String? _ageGroup;
  String? _username;
  String? _provider;
  bool _loading = true;

  static final _plzRegex = RegExp(r'^\d{5}$');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await StorageService.getUserProfile();
    final username = await AuthService.getUsername();
    final provider = await AuthService.getProvider();
    if (mounted) {
      setState(() {
        _plz = profile['plz'];
        _ageGroup = profile['age_group'];
        _username = username;
        _provider = provider;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abmelden?'),
        content: const Text(
            'Deine Abstimmungen auf diesem Gerät bleiben erhalten. Du wirst zur Anmeldung weitergeleitet.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ctx.shm.no, foregroundColor: ctx.shm.onNo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final jwt = await AuthService.getJwt();
    if (jwt != null) {
      try {
        await ApiService.logoutJwt(jwt);
      } catch (_) {}
    }
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
    }
  }

  String _ageLabel(String? key) =>
      key == null ? '–' : (ageLabels[key] ?? key);

  Future<void> _editPlz() async {
    final ctrl = TextEditingController(text: _plz ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Postleitzahl ändern'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 5,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'PLZ',
            hintText: 'z. B. 80331',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (_plzRegex.hasMatch(v)) Navigator.pop(ctx, v);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result != null) {
      await StorageService.saveUserProfile(
          ageGroup: _ageGroup ?? 'B', plz: result);
      await _load();
    }
  }

  Future<void> _editAgeGroup() async {
    String selected = _ageGroup ?? 'B';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Altersgruppe ändern'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in ageLabels.entries)
                RadioListTile<String>(
                  value: entry.key,
                  groupValue: selected,
                  title: Text('${entry.value} Jahre'),
                  onChanged: (v) => setS(() => selected = v!),
                  dense: true,
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await StorageService.saveUserProfile(
          ageGroup: result, plz: _plz ?? '');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shm = context.shm;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(ShmTheme.gapL),
              children: [
                // ── Account-Block (nur wenn per JWT eingeloggt) ──────────────
                if (_username != null) ...[
                  const SectionHeader('Mein Account'),
                  Card(
                    color: scheme.primaryContainer.withOpacity(0.4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: ShmTheme.gapL, vertical: ShmTheme.gapM),
                      child: Row(children: [
                        Icon(Icons.person_pin_outlined,
                            color: scheme.primary, size: 28),
                        const SizedBox(width: ShmTheme.gapM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_username!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      fontFamily: 'monospace')),
                              Text(
                                switch (_provider) {
                                  'google' => 'Google-Account',
                                  'facebook' => 'Facebook-Account',
                                  _ => 'E-Mail-Account',
                                },
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy_outlined,
                              size: 18, color: scheme.primary),
                          tooltip: 'Kopieren',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _username!));
                            showShmSnack(context, 'Username kopiert');
                          },
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: ShmTheme.gapXl),
                ],
                const SectionHeader('Meine Angaben'),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.location_on_outlined,
                            color: scheme.primary),
                        title: const Text('Postleitzahl'),
                        subtitle: Text(_plz?.isNotEmpty == true
                            ? _plz!
                            : 'Nicht angegeben'),
                        trailing: Icon(Icons.edit_outlined,
                            size: 18, color: scheme.outline),
                        onTap: _editPlz,
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: Icon(Icons.person_outline,
                            color: scheme.primary),
                        title: const Text('Altersgruppe'),
                        subtitle: Text(_ageLabel(_ageGroup)),
                        trailing: Icon(Icons.edit_outlined,
                            size: 18, color: scheme.outline),
                        onTap: _editAgeGroup,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ShmTheme.gapXl),
                const SectionHeader('Datenschutz & Anonymität'),
                Card(
                  color: scheme.secondaryContainer.withOpacity(0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.shield_outlined,
                              size: 18, color: scheme.primary),
                          const SizedBox(width: ShmTheme.gapS),
                          const Text('Wie wir deine Daten schützen',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: ShmTheme.gapS),
                        for (final s in const [
                          'Deine PLZ wird serverseitig zu einer Region umgewandelt und sofort verworfen.',
                          'Abstimmungen sind nur per Geräte-ID verknüpft — kein Name, keine E-Mail.',
                          'Ergebnisse siehst du erst, nachdem du selbst abgestimmt hast.',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('· ',
                                    style:
                                        TextStyle(color: scheme.primary)),
                                Expanded(
                                    child: Text(s,
                                        style: const TextStyle(
                                            fontSize: 13, height: 1.35))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: ShmTheme.gapXl),
                const SectionHeader('Rechtliches'),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading:
                        Icon(Icons.gavel_outlined, color: scheme.primary),
                    title: const Text('Datenschutz & Impressum'),
                    trailing:
                        Icon(Icons.chevron_right, color: scheme.outline),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LegalScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: ShmTheme.gapXl),

                // ── Logout (nur wenn JWT-User) ────────────────────────────
                if (_username != null) ...[
                  const SectionHeader('Account-Aktionen'),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: Icon(Icons.logout, color: shm.no),
                    label: Text('Abmelden',
                        style: TextStyle(color: shm.no)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: shm.no)),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
