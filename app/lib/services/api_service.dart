import 'dart:convert';
import 'package:http/http.dart' as http;

/// Wird von API-Aufrufen bei Fehlern geworfen. [code] ist ein maschinen-
/// lesbarer Schlüssel (z. B. `already_voted`), den die UI in eine
/// deutsche Meldung übersetzt.
class ApiException implements Exception {
  final String code;
  final int? statusCode;
  const ApiException(this.code, [this.statusCode]);

  @override
  String toString() => code;
}

/// Einziger HTTP-Zugang der App — alle Endpoints und die Base-URL leben hier.
class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'SHM_BASE_URL',
    defaultValue: 'https://shm.13-61-179-136.nip.io',
  );

  static const _jsonHeaders = {'Content-Type': 'application/json'};
  static const _timeout = Duration(seconds: 15);

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  static dynamic _decode(http.Response res) =>
      jsonDecode(utf8.decode(res.bodyBytes));

  /// Wirft eine [ApiException] mit dem `detail`-Feld des Backends (falls
  /// vorhanden), sonst mit [fallbackCode].
  static Never _fail(http.Response res, String fallbackCode) {
    String code = fallbackCode;
    try {
      final detail = (_decode(res) as Map<String, dynamic>)['detail'];
      if (detail is String && detail.isNotEmpty) code = detail;
    } catch (_) {}
    throw ApiException(code, res.statusCode);
  }

  static Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    String fallbackCode = 'request_failed',
  }) async {
    final res = await http
        .post(_uri(path), headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(_timeout);
    if (res.statusCode != 200) _fail(res, fallbackCode);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
    String fallbackCode = 'request_failed',
  }) async {
    final res =
        await http.get(_uri(path, query)).timeout(timeout ?? _timeout);
    if (res.statusCode != 200) _fail(res, fallbackCode);
    return _decode(res) as Map<String, dynamic>;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> requestMagicLink(String email) =>
      _postJson('/auth/magic-link/request', {'email': email},
          fallbackCode: 'magic_link_failed');

  static Future<Map<String, dynamic>> verifyMagicLink(String token) =>
      _postJson('/auth/magic-link/verify', {'token': token},
          fallbackCode: 'verify_failed');

  static Future<Map<String, dynamic>> socialLogin(
          String provider, String accessToken) =>
      _postJson('/auth/social',
          {'provider': provider, 'access_token': accessToken},
          fallbackCode: 'social_login_failed');

  static Future<void> logoutJwt(String jwt) async {
    await http
        .post(_uri('/auth/logout'), headers: {'Authorization': 'Bearer $jwt'})
        .timeout(_timeout);
  }

  static Future<Map<String, dynamic>> getMe(String jwt) async {
    final res = await http
        .get(_uri('/auth/me'), headers: {'Authorization': 'Bearer $jwt'})
        .timeout(_timeout);
    if (res.statusCode != 200) _fail(res, 'profile_load_failed');
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> register(String deviceToken,
      {String? emailHash}) {
    final body = <String, dynamic>{'device_token': deviceToken};
    if (emailHash != null) body['email_hash'] = emailHash;
    return _postJson('/auth/register', body,
        fallbackCode: 'register_failed');
  }

  // ── Fragen & Votes ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getActiveQuestions() async {
    final res = await http.get(_uri('/questions/')).timeout(_timeout);
    if (res.statusCode != 200) _fail(res, 'questions_load_failed');
    return List<Map<String, dynamic>>.from(_decode(res) as List);
  }

  /// Top-Fragen nach Beteiligung der letzten 7 Tage.
  static Future<List<Map<String, dynamic>>> getTopQuestions(
      {int limit = 10}) async {
    final res = await http
        .get(_uri('/questions/top', {'limit': '$limit'}))
        .timeout(_timeout);
    if (res.statusCode != 200) _fail(res, 'questions_load_failed');
    return List<Map<String, dynamic>>.from(_decode(res) as List);
  }

  static Future<Map<String, dynamic>> submitVote({
    required String deviceToken,
    required String questionId,
    required String answer,
    required String plz,
    required String ageGroup,
  }) =>
      _postJson('/votes/', {
        'device_token': deviceToken,
        'question_id': questionId,
        'answer': answer,
        'plz': plz,
        'age_group': ageGroup,
      }, fallbackCode: 'vote_failed');

  /// Eigene Votes vom Server (für Wiederherstellung nach Neuinstallation).
  /// Liefert eine Liste `{question_id, answer, question_title, category}`.
  static Future<List<Map<String, dynamic>>> getMyVotes(
      String deviceToken) async {
    final data = await _getJson('/votes/mine',
        query: {'device_token': deviceToken},
        fallbackCode: 'my_votes_failed');
    return List<Map<String, dynamic>>.from(
        (data['votes'] as List<dynamic>? ?? []));
  }

  // ── Statistiken & Karte ───────────────────────────────────────────────────
  // Ergebnisse gibt es serverseitig nur nach eigener Stimme — deshalb wird
  // überall das device_token mitgeschickt (Fair Play).

  static Future<Map<String, dynamic>> getMapSnapshot(
          String questionId, String deviceToken) =>
      _getJson('/stats/map/$questionId',
          query: {'device_token': deviceToken},
          fallbackCode: 'map_load_failed');

  static Future<Map<String, dynamic>> getBundeslandSnapshot(
          String questionId, String deviceToken) =>
      _getJson('/stats/map/$questionId/bundeslaender',
          query: {'device_token': deviceToken},
          fallbackCode: 'map_load_failed');

  static Future<Map<String, dynamic>> getBundeslandDetail(
          String questionId, String bundesland, String deviceToken) =>
      _getJson('/stats/map/$questionId/bundesland-detail',
          query: {'bundesland': bundesland, 'device_token': deviceToken},
          fallbackCode: 'stats_load_failed');

  static Future<Map<String, dynamic>> getLandkreisDetail(
          String questionId, String landkreisId, String deviceToken) =>
      _getJson('/stats/map/$questionId/landkreis-detail',
          query: {'landkreis_id': landkreisId, 'device_token': deviceToken},
          fallbackCode: 'stats_load_failed');

  /// Leichter Zähler-Endpoint für den Live-Modus (ersetzt das SSE-Polling).
  static Future<int> getLiveTotal(String questionId) async {
    final data = await _getJson('/stats/map/$questionId/total',
        timeout: const Duration(seconds: 5), fallbackCode: 'live_failed');
    return data['total_votes'] as int? ?? 0;
  }

  static Future<Map<String, dynamic>> getLandkreiseGeoJson() =>
      _getJson('/stats/geojson/landkreise',
          timeout: const Duration(seconds: 30),
          fallbackCode: 'geojson_load_failed');
}
