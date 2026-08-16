import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
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
  List<Map<String, dynamic>> _top = [];

  /// question_id → eigene Antwort ('' wenn Antwort unbekannt).
  Map<String, String> _myAnswers = {};
  bool _loading = true;
  Object? _error;
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

      final questions = await ApiService.getActiveQuestions();
      List<Map<String, dynamic>> top = [];
      try {
        top = await ApiService.getTopQuestions();
      } catch (_) {
        // Altes Backend ohne /top — Feed funktioniert trotzdem.
      }
      await _syncMyVotes();
      final voted = await StorageService.getVotedQuestions();

      if (mounted) {
        setState(() {
          _questions = questions;
          _top = top;
          _myAnswers = {
            for (final q in voted)
              q['id'] as String: (q['answer'] as String?) ?? '',
          };
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  /// Gleicht die lokale „abgestimmt"-Liste mit dem Server ab, damit sie
  /// eine Neuinstallation überlebt. Best effort — Fehler sind nicht fatal.
  Future<void> _syncMyVotes() async {
    try {
      final deviceToken = await StorageService.getOrCreateDeviceToken();
      final votes = await ApiService.getMyVotes(deviceToken);
      await StorageService.replaceVotedQuestions([
        for (final v in votes)
          {
            'id': v['question_id'],
            'title': v['question_title'] ?? '',
            'category': v['category'] ?? '',
            'answer': v['answer'],
          },
      ]);
    } catch (_) {
      // Offline oder alter Server ohne /votes/mine — lokale Liste behalten.
    }
  }

  Future<void> _onAnswer(Map<String, dynamic> question, String answer) async {
    final plz = _plz ?? '';
    if (plz.isEmpty) {
      showShmSnack(context, 'Bitte richte zuerst dein Profil ein (PLZ).');
      return;
    }

    final deviceToken = await StorageService.getOrCreateDeviceToken();
    final ageGroup = _ageGroup ?? 'B';
    if (!mounted) return;

    try {
      await ApiService.submitVote(
        deviceToken: deviceToken,
        questionId: question['id'],
        answer: answer,
        plz: plz,
        ageGroup: ageGroup,
      );
      await _markVoted(question, answer);
      if (mounted) {
        showShmSnack(context, 'Stimme abgegeben', success: true);
        _openMap(question);
      }
    } catch (e) {
      final code = e.toString();
      if (code.contains('already_voted')) {
        await _markVoted(question, null);
        if (mounted) _openMap(question);
      } else if (mounted) {
        showShmSnack(context, errorMessage(e), error: true);
      }
    }
  }

  Future<void> _markVoted(
      Map<String, dynamic> question, String? answer) async {
    await StorageService.markQuestionVoted(
      question['id'],
      question['title'] ?? '',
      question['category'] ?? '',
      answer: answer,
    );
    if (mounted) {
      setState(() =>
          _myAnswers = {..._myAnswers, question['id'] as String: answer ?? ''});
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

  void _openVoteFor(Map<String, dynamic> q) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => VoteSheet(
        title: q['title'] ?? '',
        description: q['description'],
        category: q['category'] ?? '',
        answerType: q['answer_type'] ?? 'binary',
        options:
            q['options'] != null ? List<String>.from(q['options']) : null,
        onAnswer: (a) {
          Navigator.pop(context);
          _onAnswer(q, a);
        },
      ),
    );
  }

  List<String> get _categories {
    final cats =
        _questions.map((q) => q['category'] as String? ?? '').toSet().toList()
          ..sort();
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
                decoration: const InputDecoration(
                  hintText: 'Frage suchen …',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('SocialHeadmap'),
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
              ? ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _HeroBanner(
                          totalQuestions: _questions.length,
                          votedCount: _questions
                              .where(
                                  (q) => _myAnswers.containsKey(q['id']))
                              .length,
                          categoryCount: _categories.length - 1,
                        ),
                      ),
                      if (_top.isNotEmpty &&
                          _selectedCategory == 'Alle' &&
                          _searchQuery.isEmpty)
                        SliverToBoxAdapter(
                          child: _TopTenStrip(
                            top: _top,
                            myAnswers: _myAnswers,
                            onTap: (q) {
                              if (_myAnswers.containsKey(q['id'])) {
                                _openMap(q);
                              } else {
                                _openVoteFor(q);
                              }
                            },
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: _CategoryBar(
                          categories: _categories,
                          selected: _selectedCategory,
                          onSelect: (c) =>
                              setState(() => _selectedCategory = c),
                        ),
                      ),
                      if (_filtered.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.search_off,
                            title: 'Keine Fragen gefunden',
                            subtitle:
                                'Versuche eine andere Kategorie oder Suche.',
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final q = _filtered[i];
                              final voted =
                                  _myAnswers.containsKey(q['id']);
                              final answer = _myAnswers[q['id']];
                              return QuestionCard(
                                title: q['title'] ?? '',
                                description: q['description'],
                                category: q['category'] ?? '',
                                answerType: q['answer_type'] ?? 'binary',
                                options: q['options'] != null
                                    ? List<String>.from(q['options'])
                                    : null,
                                isVoted: voted,
                                myAnswer: (answer?.isNotEmpty ?? false)
                                    ? answer
                                    : null,
                                onAnswer:
                                    voted ? null : (a) => _onAnswer(q, a),
                                onViewMap:
                                    voted ? () => _openMap(q) : null,
                              );
                            },
                            childCount: _filtered.length,
                          ),
                        ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: ShmTheme.gapXl)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ShmTheme.gapL, ShmTheme.gapM, ShmTheme.gapL, ShmTheme.gapS),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF14304F), Color(0xFF1A4470)]
                : const [Color(0xFF0D47A1), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(ShmTheme.radiusL),
        ),
        padding: const EdgeInsets.all(ShmTheme.gapL + 2),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: Icon(
                Icons.how_to_vote_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Was denkt Deutschland?',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: ShmTheme.gapXs),
                Text(
                  'Stimme anonym ab und sieh die Ergebnisse auf der Karte.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: ShmTheme.gapL),
                Row(
                  children: [
                    _Stat(value: '$totalQuestions', label: 'Aktive Fragen'),
                    const SizedBox(width: ShmTheme.gapXl),
                    _Stat(value: '$categoryCount', label: 'Kategorien'),
                    const SizedBox(width: ShmTheme.gapXl),
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
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Top-10-Strip ────────────────────────────────────────────────────────────

class _TopTenStrip extends StatelessWidget {
  final List<Map<String, dynamic>> top;
  final Map<String, String> myAnswers;
  final void Function(Map<String, dynamic> question) onTap;

  const _TopTenStrip({
    required this.top,
    required this.myAnswers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              ShmTheme.gapL, ShmTheme.gapM, ShmTheme.gapL, ShmTheme.gapS),
          child: Row(
            children: [
              Icon(Icons.local_fire_department,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text('Top 10 · Was Deutschland bewegt',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 15)),
            ],
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: ShmTheme.gapL),
            itemCount: top.length,
            separatorBuilder: (_, __) => const SizedBox(width: ShmTheme.gapS + 2),
            itemBuilder: (ctx, i) {
              final entry = top[i];
              final q = entry['question'] as Map<String, dynamic>;
              final rank = entry['rank'] as int? ?? i + 1;
              final votes7d = entry['votes_7d'] as int? ?? 0;
              final voted = myAnswers.containsKey(q['id']);
              return _TopCard(
                rank: rank,
                title: q['title'] ?? '',
                category: q['category'] ?? '',
                votes7d: votes7d,
                voted: voted,
                onTap: () => onTap(q),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TopCard extends StatelessWidget {
  final int rank;
  final String title;
  final String category;
  final int votes7d;
  final bool voted;
  final VoidCallback onTap;

  const _TopCard({
    required this.rank,
    required this.title,
    required this.category,
    required this.votes7d,
    required this.voted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shm = context.shm;
    final catColor = ShmTheme.categoryColor(category);
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ShmTheme.gapM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: rank <= 3
                            ? const Color(0xFFC9A227)
                            : scheme.primary,
                      ),
                    ),
                    const SizedBox(width: ShmTheme.gapS),
                    Expanded(
                      child: Text(
                        category.isNotEmpty ? category : 'Allgemein',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: catColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (voted)
                      Icon(Icons.check_circle, size: 15, color: shm.yes),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3),
                  ),
                ),
                Text(
                  '$votes7d Stimmen diese Woche',
                  style: TextStyle(
                      fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
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
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: ShmTheme.gapL, vertical: ShmTheme.gapS),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: ShmTheme.gapS),
        itemBuilder: (ctx, i) {
          final cat = categories[i];
          return ChoiceChip(
            label: Text(cat),
            selected: cat == selected,
            showCheckmark: false,
            onSelected: (_) => onSelect(cat),
          );
        },
      ),
    );
  }
}
