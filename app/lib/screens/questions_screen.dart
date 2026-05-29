import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/question_card.dart';
import 'map_screen.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});
  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  String? _error;
  String? _plz;
  String? _ageGroup;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await StorageService.getUserProfile();
      _plz = profile['plz'];
      _ageGroup = profile['age_group'];
      _questions = await ApiService.getActiveQuestions();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onAnswer(Map<String, dynamic> question, String answer) async {
    final deviceToken = await StorageService.getOrCreateDeviceToken();
    final plz = _plz ?? '';
    final ageGroup = _ageGroup ?? 'B';

    if (plz.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte richte zuerst dein Profil ein.')),
      );
      return;
    }

    try {
      await ApiService.submitVote(
        deviceToken: deviceToken,
        questionId: question['id'],
        answer: answer,
        plz: plz,
        ageGroup: ageGroup,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Stimme abgegeben!'), backgroundColor: ShmTheme.yes),
        );
        // Zur Karte navigieren
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MapScreen(questionId: question['id'], questionTitle: question['title']),
        ));
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('already_voted')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Du hast für diese Frage bereits abgestimmt.')),
          );
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MapScreen(questionId: question['id'], questionTitle: question['title']),
          ));
        }
      } else if (msg.contains('unknown_plz')) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Postleitzahl nicht erkannt. Bitte Profil aktualisieren.'), backgroundColor: ShmTheme.no),
        );
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $msg'), backgroundColor: ShmTheme.no),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _load, child: const Text('Erneut versuchen')),
      ]),
    );
    if (_questions.isEmpty) return const Center(
      child: Text('Derzeit keine aktiven Fragen.', style: TextStyle(color: Colors.black54)),
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _questions.length,
        itemBuilder: (ctx, i) {
          final q = _questions[i];
          return QuestionCard(
            title: q['title'] ?? '',
            description: q['description'],
            category: q['category'] ?? '',
            answerType: q['answer_type'] ?? 'binary',
            options: q['options'] != null ? List<String>.from(q['options']) : null,
            onAnswer: (answer) => _onAnswer(q, answer),
          );
        },
      ),
    );
  }
}
