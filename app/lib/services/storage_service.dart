import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class StorageService {
  static const _storage = FlutterSecureStorage(
    webOptions: WebOptions(dbName: 'shm_secure', publicKey: 'shm_key'),
  );
  static const _deviceTokenKey = 'device_token';
  static const _emailSaltKey = 'email_salt';
  static const _ageGroupKey = 'age_group';
  static const _plzKey = 'plz';
  static const _onboardingDoneKey = 'onboarding_done';
  static const _registeredKey = 'registered';

  static Future<String> getOrCreateDeviceToken() async {
    String? token = await _storage.read(key: _deviceTokenKey);
    if (token == null) {
      token = const Uuid().v4();
      await _storage.write(key: _deviceTokenKey, value: token);
    }
    return token;
  }

  static Future<String> hashEmail(String email) async {
    String? salt = await _storage.read(key: _emailSaltKey);
    if (salt == null) {
      salt = const Uuid().v4();
      await _storage.write(key: _emailSaltKey, value: salt);
    }
    final bytes = utf8.encode(email.trim().toLowerCase() + salt);
    return sha256.convert(bytes).toString();
  }

  static Future<void> saveUserProfile({required String ageGroup, required String plz}) async {
    await _storage.write(key: _ageGroupKey, value: ageGroup);
    await _storage.write(key: _plzKey, value: plz);
  }

  static Future<Map<String, String?>> getUserProfile() async {
    return {
      'age_group': await _storage.read(key: _ageGroupKey),
      'plz': await _storage.read(key: _plzKey),
    };
  }

  static Future<void> setOnboardingDone() async =>
      _storage.write(key: _onboardingDoneKey, value: 'true');

  static Future<bool> isOnboardingDone() async =>
      (await _storage.read(key: _onboardingDoneKey)) == 'true';

  static Future<void> setRegistered() async =>
      _storage.write(key: _registeredKey, value: 'true');

  static Future<bool> isRegistered() async =>
      (await _storage.read(key: _registeredKey)) == 'true';

  // ── Voted Questions ──────────────────────────────────────────────────────

  static const _votedQuestionsKey = 'voted_questions';

  static Future<void> markQuestionVoted(
      String questionId, String questionTitle, String category,
      {String? answer}) async {
    final raw = await _storage.read(key: _votedQuestionsKey) ?? '[]';
    final list = List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    if (!list.any((q) => q['id'] == questionId)) {
      list.add({
        'id': questionId,
        'title': questionTitle,
        'category': category,
        if (answer != null) 'answer': answer,
      });
      await _storage.write(key: _votedQuestionsKey, value: jsonEncode(list));
    }
  }

  /// Ersetzt die lokale Liste komplett — für den Abgleich mit /votes/mine.
  static Future<void> replaceVotedQuestions(
      List<Map<String, dynamic>> questions) async {
    await _storage.write(key: _votedQuestionsKey, value: jsonEncode(questions));
  }

  static Future<List<Map<String, dynamic>>> getVotedQuestions() async {
    final raw = await _storage.read(key: _votedQuestionsKey) ?? '[]';
    return List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  static Future<Set<String>> getVotedQuestionIds() async {
    final qs = await getVotedQuestions();
    return qs.map((q) => q['id'] as String).toSet();
  }
}
