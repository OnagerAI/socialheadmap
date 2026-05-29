import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage(
    webOptions: WebOptions(dbName: 'shm_secure', publicKey: 'shm_key'),
  );

  static const _jwtKey      = 'auth_jwt';
  static const _usernameKey = 'auth_username';
  static const _providerKey = 'auth_provider';

  // ── Speichern ─────────────────────────────────────────────────────────────

  static Future<void> saveAuth({
    required String jwt,
    required String username,
    required String provider,
  }) async {
    await _storage.write(key: _jwtKey,      value: jwt);
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _providerKey, value: provider);
  }

  // ── Lesen ─────────────────────────────────────────────────────────────────

  static Future<String?> getJwt()      => _storage.read(key: _jwtKey);
  static Future<String?> getUsername() => _storage.read(key: _usernameKey);
  static Future<String?> getProvider() => _storage.read(key: _providerKey);

  static Future<bool> isLoggedIn() async {
    final jwt = await getJwt();
    if (jwt == null) return false;
    return !_isExpired(jwt);
  }

  // ── JWT-Ablauf prüfen (ohne Library, nur Base64-Decode des Payloads) ──────

  static bool _isExpired(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return true;
      // Base64Url-Padding ergänzen
      var payload = parts[1];
      final rem = payload.length % 4;
      if (rem != 0) payload = payload.padRight(payload.length + (4 - rem), '=');
      final decoded = jsonDecode(utf8.decode(base64Url.decode(payload)));
      final exp = decoded['exp'] as int?;
      if (exp == null) return true;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 > exp;
    } catch (_) {
      return true;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    // JWT lokal löschen — Backend-Invalidierung macht der Aufrufer via ApiService
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _providerKey);
  }

  // ── Navigation nach Logout ────────────────────────────────────────────────

  static void navigateToAuth(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
  }
}
