import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/stats_widgets.dart';
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
    // Server ist die Wahrheit (überlebt Neuinstallation); lokal ist Fallback.
    try {
      final deviceToken = await StorageService.getOrCreateDeviceToken();
      final votes = await ApiService.getMyVotes(deviceToken);
      final list = [
        for (final v in votes)
          {
            'id': v['question_id'],
            'title': v['question_title'] ?? '',
            'category': v['category'] ?? '',
            'answer': v['answer'],
          },
      ];
      await StorageService.replaceVotedQuestions(list);
      if (mounted) {
        setState(() {
          _voted = list;
          _loading = false;
        });
      }
      return;
    } catch (_) {
      // Offline — lokale Liste anzeigen.
    }
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
      appBar: AppBar(title: const Text('Meine Antworten')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _voted.isEmpty
              ? const EmptyState(
                  icon: Icons.how_to_vote_outlined,
                  title: 'Noch keine Abstimmungen',
                  subtitle:
                      'Geh zur Übersicht und stimme bei einer Frage ab —\ndanach erscheinen deine Antworten hier.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(ShmTheme.gapL),
                    itemCount: _voted.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: ShmTheme.gapS + 2),
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
    final scheme = Theme.of(context).colorScheme;
    final shm = context.shm;
    final category = question['category'] as String? ?? '';
    final title = question['title'] as String? ?? '';
    final answer = question['answer'] as String?;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onViewMap,
        child: Padding(
          padding: const EdgeInsets.all(ShmTheme.gapL),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (category.isNotEmpty) CategoryBadge(category),
                        if (answer != null && answer.isNotEmpty) ...[
                          const SizedBox(width: ShmTheme.gapS),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: shm.yesContainer,
                              borderRadius:
                                  BorderRadius.circular(ShmTheme.radiusXl),
                            ),
                            child: Text(
                              answerLabel(answer),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: shm.yes,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: ShmTheme.gapS),
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ShmTheme.gapM),
              Icon(Icons.map_outlined, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
