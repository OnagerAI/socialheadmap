import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'map_screen.dart';

class MyAnswersScreen extends StatefulWidget {
  const MyAnswersScreen({super.key});

  @override
  State<MyAnswersScreen> createState() => _MyAnswersScreenState();
}

class _MyAnswersScreenState extends State<MyAnswersScreen> {
  List<Map<String, dynamic>> _voted = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final qs = await StorageService.getVotedQuestions();
    if (mounted) {
      setState(() {
        _voted = List<Map<String, dynamic>>.from(qs.reversed);
        _loading = false;
      });
    }
  }

  void _openMap(Map<String, dynamic> q) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MapScreen(
        questionId: q['id'],
        questionTitle: q['title'] ?? '',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Antworten', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _voted.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    itemCount: _voted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _AnswerCard(
                      question: _voted[i],
                      onViewMap: () => _openMap(_voted[i]),
                    ),
                  ),
                ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final Map<String, dynamic> question;
  final VoidCallback onViewMap;

  const _AnswerCard({required this.question, required this.onViewMap});

  @override
  Widget build(BuildContext context) {
    final category = question['category'] as String? ?? '';
    final title = question['title'] as String? ?? '';

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check_circle, color: ShmTheme.yes, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onViewMap,
              icon: const Icon(Icons.map_outlined, size: 14),
              label: const Text('Karte', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShmTheme.primary,
                side: const BorderSide(color: ShmTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_box_outline_blank, size: 56, color: Colors.black26),
            SizedBox(height: 16),
            Text(
              'Noch keine Abstimmungen',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            SizedBox(height: 8),
            Text(
              'Geh zur Übersicht und stimme bei einer Frage ab –\ndanach erscheinen deine Antworten hier.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
