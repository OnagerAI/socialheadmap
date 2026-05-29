import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://shm.13-61-179-136.nip.io';

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> requestMagicLink(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/magic-link/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode == 400) throw Exception('invalid_email');
    if (res.statusCode != 200) throw Exception('magic_link_failed');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> verifyMagicLink(String token) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/magic-link/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );
    if (res.statusCode == 404) throw Exception('token_not_found');
    if (res.statusCode == 410) {
      final detail = jsonDecode(utf8.decode(res.bodyBytes))['detail'] ?? '';
      throw Exception(detail);
    }
    if (res.statusCode != 200) throw Exception('verify_failed');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> socialLogin(
      String provider, String accessToken) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/social'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'provider': provider, 'access_token': accessToken}),
    );
    if (res.statusCode == 401) {
      final detail = jsonDecode(utf8.decode(res.bodyBytes))['detail'] ?? '';
      throw Exception(detail);
    }
    if (res.statusCode != 200) throw Exception('social_login_failed');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<void> logoutJwt(String jwt) async {
    await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: {'Authorization': 'Bearer $jwt'},
    );
  }

  static Future<Map<String, dynamic>> getMe(String jwt) async {
    final res = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $jwt'},
    );
    if (res.statusCode == 401) throw Exception('not_authenticated');
    if (res.statusCode != 200) throw Exception('profile_load_failed');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getActiveQuestions() async {
    final res = await http.get(Uri.parse('$baseUrl/questions/'));
    if (res.statusCode != 200) throw Exception('Fragen konnten nicht geladen werden');
    return List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  static Future<Map<String, dynamic>> register(String deviceToken, {String? emailHash}) async {
    final body = <String, dynamic>{'device_token': deviceToken};
    if (emailHash != null) body['email_hash'] = emailHash;
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode == 409) throw Exception('already_registered');
    if (res.statusCode != 200) throw Exception('Registrierung fehlgeschlagen');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> submitVote({
    required String deviceToken,
    required String questionId,
    required String answer,
    required String plz,
    required String ageGroup,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/votes/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_token': deviceToken,
        'question_id': questionId,
        'answer': answer,
        'plz': plz,
        'age_group': ageGroup,
      }),
    );
    if (res.statusCode == 409) throw Exception('already_voted');
    if (res.statusCode == 422) {
      final detail = jsonDecode(utf8.decode(res.bodyBytes))['detail'];
      throw Exception(detail ?? 'Ungültige Eingabe');
    }
    if (res.statusCode != 200) throw Exception('Abstimmung fehlgeschlagen');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getMapSnapshot(String questionId) async {
    final res = await http.get(Uri.parse('$baseUrl/stats/map/$questionId'));
    if (res.statusCode != 200) throw Exception('Kartendaten nicht verfügbar');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getLandkreiseGeoJson() async {
    final res = await http.get(Uri.parse('$baseUrl/stats/geojson/landkreise'));
    if (res.statusCode != 200) throw Exception('GeoJSON nicht verfügbar');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
