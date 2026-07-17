import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datenschutz & Impressum')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Impressum', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Angaben gemäß § 5 TMG\n\nSocialHeadmap\nBetreiber: Artur Shachnev\nDeutschland\n\nKontakt: info@socialheadmap.de'),
            Divider(height: 40),
            Text('Datenschutzerklärung', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('1. Was wir speichern', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              '• Anonymes Gerätekennzeichen (UUID v4) — gespeichert auf deinem Gerät\n'
              '• Landkreis-ID (NUTS-3) — abgeleitet aus deiner PLZ, PLZ wird sofort verworfen\n'
              '• Altersgruppe (10-Jahres-Schritte, z.B. 30–39 Jahre)\n'
              '• Deine Antwort auf die Frage\n'
              '• E-Mail-Hash (optional, verschlüsselt, nicht rekonstruierbar)',
            ),
            SizedBox(height: 16),
            Text('2. Was wir NICHT speichern', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              '• Deine IP-Adresse (nicht protokolliert)\n'
              '• Deine genaue Postleitzahl (wird nach Landkreis-Umrechnung verworfen)\n'
              '• Dein genaues Alter oder Geburtsdatum\n'
              '• Deine E-Mail-Adresse im Klartext\n'
              '• Verhaltensdaten, Geräteprofil, Standort-Tracking',
            ),
            SizedBox(height: 16),
            Text('3. Rechtsgrundlagen', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              '• Gerätekennzeichen & Vote-Daten: Art. 6(1)(a) DSGVO (Einwilligung)\n'
              '• Politische/weltanschauliche Fragen: Art. 9(2)(a) DSGVO (explizite Einwilligung)\n'
              '• E-Mail-Hash (optional): Art. 6(1)(a) DSGVO',
            ),
            SizedBox(height: 16),
            Text('4. Fair-Play-Prinzip', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              'Ergebnisse einer Frage sind erst sichtbar, nachdem du selbst abgestimmt hast — '
              'das wird auch serverseitig durchgesetzt. Regionale Ergebnisse werden ab der ersten Stimme angezeigt.',
            ),
            SizedBox(height: 16),
            Text('5. Deine Rechte', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              'Du hast das Recht auf Auskunft, Löschung und Widerspruch (Art. 15–21 DSGVO). '
              'Da deine Daten vollständig anonym sind, ist eine Identifikation und gezielte Löschung technisch nicht möglich — '
              'das ist bewusst so designed (Privacy by Design, Art. 25 DSGVO).',
            ),
            SizedBox(height: 16),
            Text('6. Server-Standort', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Server: AWS EU (Europa) — Frankfurt/Irland\nKeine Datenübertragung in Drittländer.'),
            SizedBox(height: 16),
            Text('7. Widerruf der Einwilligung', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              'Du kannst deine Einwilligung jederzeit widerrufen, indem du die App-Daten löschst. '
              'Da alle Stimmen vollständig anonym sind, können bereits abgegebene Stimmen nicht nachträglich entfernt werden.',
            ),
            SizedBox(height: 32),
            Text('Stand: Juli 2026', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
