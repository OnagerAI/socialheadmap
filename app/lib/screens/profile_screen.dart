import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'legal_screen.dart';
import 'auth_screen.dart';

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

  static const _ageGroups = [
    ('A', '18–29 Jahre'),
    ('B', '30–39 Jahre'),
    ('C', '40–49 Jahre'),
    ('D', '50–59 Jahre'),
    ('E', '60+ Jahre'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile  = await StorageService.getUserProfile();
    final username = await AuthService.getUsername();
    final provider = await AuthService.getProvider();
    if (mounted) {
      setState(() {
        _plz      = profile['plz'];
        _ageGroup = profile['age_group'];
        _username = username;
        _provider = provider;
        _loading  = false;
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
            style: FilledButton.styleFrom(backgroundColor: ShmTheme.no),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final jwt = await AuthService.getJwt();
    if (jwt != null) {
      try { await ApiService.logoutJwt(jwt); } catch (_) {}
    }
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
    }
  }

  String _ageLabel(String? key) {
    if (key == null) return '–';
    return _ageGroups.firstWhere(
      (e) => e.$1 == key,
      orElse: () => (key, key),
    ).$2;
  }

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
          decoration: const InputDecoration(
            labelText: 'PLZ',
            hintText: 'z.B. 80331',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.length >= 4) Navigator.pop(ctx, v);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result != null) {
      await StorageService.saveUserProfile(ageGroup: _ageGroup ?? 'B', plz: result);
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
            children: _ageGroups.map((e) => RadioListTile<String>(
              value: e.$1,
              groupValue: selected,
              title: Text(e.$2),
              onChanged: (v) => setS(() => selected = v!),
              dense: true,
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await StorageService.saveUserProfile(ageGroup: result, plz: _plz ?? '');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Account-Block (nur wenn per JWT eingeloggt) ──────────────
                if (_username != null) ...[
                  const _SectionHeader('Mein Account'),
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: ShmTheme.primary.withOpacity(0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: ShmTheme.primary.withOpacity(0.15)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        const Icon(Icons.person_pin_outlined,
                            color: ShmTheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_username!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  fontFamily: 'monospace')),
                          Text(
                            _provider == 'google'
                                ? 'Google-Account'
                                : _provider == 'facebook'
                                    ? 'Facebook-Account'
                                    : 'E-Mail-Account',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ])),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined,
                              size: 18, color: ShmTheme.primary),
                          tooltip: 'Kopieren',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _username!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Username kopiert'),
                                  duration: Duration(seconds: 2)),
                            );
                          },
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const _SectionHeader('Meine Angaben'),
                Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined,
                            color: ShmTheme.primary),
                        title: const Text('Postleitzahl'),
                        subtitle: Text(_plz?.isNotEmpty == true ? _plz! : 'Nicht angegeben'),
                        trailing: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                        onTap: _editPlz,
                      ),
                      Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                      ListTile(
                        leading: const Icon(Icons.person_outline,
                            color: ShmTheme.primary),
                        title: const Text('Altersgruppe'),
                        subtitle: Text(_ageLabel(_ageGroup)),
                        trailing: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                        onTap: _editAgeGroup,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeader('Datenschutz & Anonymität'),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.blue.shade100),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.shield_outlined, size: 18, color: ShmTheme.primary),
                          const SizedBox(width: 8),
                          Text('Wie wir deine Daten schützen',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900)),
                        ]),
                        const SizedBox(height: 8),
                        ...[
                          'Deine PLZ wird serverseitig zu einer Region umgewandelt und sofort verworfen.',
                          'Abstimmungen sind nur per Geräte-ID verknüpft – kein Name, keine E-Mail.',
                          'Ergebnisse sind erst ab 10 Stimmen pro Region sichtbar.',
                        ].map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('· ', style: TextStyle(color: Colors.blue)),
                              Expanded(child: Text(s, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeader('Rechtliches'),
                Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.gavel_outlined, color: ShmTheme.primary),
                    title: const Text('Datenschutz & Impressum'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LegalScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Logout (nur wenn JWT-User) ────────────────────────────
                if (_username != null) ...[
                  const _SectionHeader('Account-Aktionen'),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Abmelden',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}
