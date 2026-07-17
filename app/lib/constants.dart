/// App-weite Fachkonstanten (Altersgruppen, Wappen-Assets).
library;

/// Altersgruppen-Schlüssel → Anzeige-Label.
const Map<String, String> ageLabels = {
  'A': '18–29',
  'B': '30–39',
  'C': '40–49',
  'D': '50–59',
  'E': '60+',
};

const Map<String, String> wappenAssets = {
  'Baden-Württemberg': 'assets/wappen/baden-wuerttemberg.svg',
  'Bayern': 'assets/wappen/bayern.svg',
  'Berlin': 'assets/wappen/berlin.svg',
  'Brandenburg': 'assets/wappen/brandenburg.svg',
  'Bremen': 'assets/wappen/bremen.svg',
  'Hamburg': 'assets/wappen/hamburg.svg',
  'Hessen': 'assets/wappen/hessen.svg',
  'Mecklenburg-Vorpommern': 'assets/wappen/mecklenburg-vorpommern.svg',
  'Niedersachsen': 'assets/wappen/niedersachsen.svg',
  'Nordrhein-Westfalen': 'assets/wappen/nordrhein-westfalen.svg',
  'Rheinland-Pfalz': 'assets/wappen/rheinland-pfalz.svg',
  'Saarland': 'assets/wappen/saarland.svg',
  'Sachsen': 'assets/wappen/sachsen.svg',
  'Sachsen-Anhalt': 'assets/wappen/sachsen-anhalt.svg',
  'Schleswig-Holstein': 'assets/wappen/schleswig-holstein.svg',
  'Thüringen': 'assets/wappen/thueringen.svg',
};

/// Übersetzt Backend-Fehlercodes in deutsche Meldungen.
String errorMessage(Object error) {
  final code = error.toString().replaceAll('Exception: ', '');
  return switch (code) {
    'already_voted' => 'Du hast bei dieser Frage bereits abgestimmt.',
    'unknown_plz' =>
      'Postleitzahl nicht erkannt. Bitte Profil aktualisieren.',
    'device_not_registered' =>
      'Gerät nicht registriert. Bitte melde dich neu an.',
    'question_not_found' => 'Diese Frage ist nicht mehr aktiv.',
    'token_already_used' =>
      'Dieser Login-Link wurde bereits verwendet. Bitte fordere einen neuen an.',
    'token_expired' =>
      'Der Login-Link ist abgelaufen (15 min). Bitte fordere einen neuen an.',
    'token_not_found' => 'Ungültiger Code. Bitte prüfe die Eingabe.',
    'invalid_email' => 'Bitte gib eine gültige E-Mail-Adresse ein.',
    'email_send_failed' =>
      'E-Mail konnte nicht gesendet werden. Bitte später erneut versuchen.',
    'already_registered' => 'Diese E-Mail ist bereits registriert.',
    'questions_load_failed' => 'Fragen konnten nicht geladen werden.',
    'map_load_failed' => 'Kartendaten konnten nicht geladen werden.',
    'stats_load_failed' => 'Statistiken konnten nicht geladen werden.',
    'geojson_load_failed' => 'Kartengeometrie nicht verfügbar.',
    _ => 'Etwas ist schiefgelaufen. Bitte erneut versuchen. ($code)',
  };
}
