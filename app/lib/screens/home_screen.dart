import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/question_card.dart';
import 'map_screen.dart';
import 'my_answers_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _FeedTab(),
          MyAnswersScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Übersicht',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_box_outlined),
            selectedIcon: Icon(Icons.check_box),
            label: 'Meine Antworten',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ── Feed Tab ────────────────────────────────────────────────────────────────

class _FeedTab extends StatefulWidget {
  const _FeedTab();

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  List<Map<String, dynamic>> _questions = [];
  Set<String> _votedIds = {};
  bool _loading = true;
  String? _error;
  String? _plz;
  String? _ageGroup;

  String _selectedCategory = 'Alle';
  bool _searchActive = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await StorageService.getUserProfile();
      _plz = profile['plz'];
      _ageGroup = profile['age_group'];
      final results = await Future.wait([
        ApiService.getActiveQuestions(),
        StorageService.getVotedQuestionIds(),
      ]);
      if (mounted) {
        setState(() {
          _questions = results[0] as List<Map<String, dynamic>>;
          _votedIds = results[1] as Set<String>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _onAnswer(Map<String, dynamic> question, String answer) async {
    final plz = _plz ?? '';
    if (plz.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte richte zuerst dein Profil ein (PLZ).')),
      );
      return;
    }

    final deviceToken = await StorageService.getOrCreateDeviceToken();
    final ageGroup = _ageGroup ?? 'B';

    try {
      await ApiService.submitVote(
        deviceToken: deviceToken,
        questionId: question['id'],
        answer: answer,
        plz: plz,
        ageGroup: ageGroup,
      );
      await StorageService.markQuestionVoted(
        question['id'],
        question['title'] ?? '',
        question['category'] ?? '',
      );
      if (mounted) {
        setState(() => _votedIds = {..._votedIds, question['id']});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stimme abgegeben'),
            backgroundColor: ShmTheme.yes,
            duration: Duration(seconds: 2),
          ),
        );
        _openMap(question);
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('already_voted')) {
        await StorageService.markQuestionVoted(
          question['id'],
          question['title'] ?? '',
          question['category'] ?? '',
        );
        if (mounted) {
          setState(() => _votedIds = {..._votedIds, question['id']});
          _openMap(question);
        }
      } else if (msg.contains('unknown_plz')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Postleitzahl nicht erkannt. Bitte Profil aktualisieren.'),
              backgroundColor: ShmTheme.no,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $msg'), backgroundColor: ShmTheme.no),
          );
        }
      }
    }
  }

  void _openMap(Map<String, dynamic> question) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MapScreen(
        questionId: question['id'],
        questionTitle: question['title'] ?? '',
      ),
    ));
  }

  List<String> get _categories {
    final cats = _questions.map((q) => q['category'] as String? ?? '').toSet().toList()..sort();
    return ['Alle', ...cats.where((c) => c.isNotEmpty)];
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _questions;
    if (_selectedCategory != 'Alle') {
      list = list.where((q) => q['category'] == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((item) =>
              (item['title'] as String? ?? '').toLowerCase().contains(q) ||
              (item['description'] as String? ?? '').toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white70,
                decoration: const InputDecoration(
                  hintText: 'Frage suchen …',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('SocialHeadmap',
                style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_searchActive ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _HeroBanner(
                          totalQuestions: _questions.length,
                          votedCount: _votedIds.length,
                          categoryCount: _categories.length - 1,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _CategoryBar(
                          categories: _categories,
                          selected: _selectedCategory,
                          onSelect: (c) => setState(() => _selectedCategory = c),
                        ),
                      ),
                      if (_filtered.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text('Keine Fragen gefunden.',
                                style: TextStyle(color: Colors.black54)),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final q = _filtered[i];
                              final voted = _votedIds.contains(q['id']);
                              return QuestionCard(
                                title: q['title'] ?? '',
                                description: q['description'],
                                category: q['category'] ?? '',
                                answerType: q['answer_type'] ?? 'binary',
                                options: q['options'] != null
                                    ? List<String>.from(q['options'])
                                    : null,
                                isVoted: voted,
                                onAnswer: voted ? null : (a) => _onAnswer(q, a),
                                onViewMap: voted ? () => _openMap(q) : null,
                              );
                            },
                            childCount: _filtered.length,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
    );
  }
}

// ── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final int totalQuestions;
  final int votedCount;
  final int categoryCount;

  const _HeroBanner({
    required this.totalQuestions,
    required this.votedCount,
    required this.categoryCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Dekorations-Icon
            Positioned(
              right: 0,
              top: 0,
              child: Icon(
                Icons.how_to_vote_outlined,
                size: 60,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOCIALHEADMAP · DEINE STIMME',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.70),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Was denkt Deutschland?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stat(value: '$totalQuestions', label: 'Aktive Fragen'),
                    const SizedBox(width: 20),
                    _Stat(value: '$categoryCount', label: 'Kategorien'),
                    const SizedBox(width: 20),
                    _Stat(value: '$votedCount', label: 'Beantwortet'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.70),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Category Filter Bar ─────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final void Function(String) onSelect;

  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFFF2F2F7),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (ctx, i) {
          final cat = categories[i];
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? ShmTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(color: const Color(0xFFD1D1D6), width: 1.5),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF3A3A3C),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}
