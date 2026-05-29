import 'package:flutter/material.dart';
import '../theme.dart';

// ── Kategorie-Farben ─────────────────────────────────────────────────────────

Color _categoryColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'politik':    return const Color(0xFF1565C0);
    case 'gesellschaft': return const Color(0xFF2E7D32);
    case 'bildung':    return const Color(0xFFB45309);
    case 'wirtschaft': return const Color(0xFF6D28D9);
    case 'umwelt':     return const Color(0xFF0F766E);
    case 'gesundheit': return const Color(0xFFBE185D);
    default:           return const Color(0xFF546E7A);
  }
}

Color _categoryBg(String cat) =>
    _categoryColor(cat).withOpacity(0.10);

// ── QuestionCard ─────────────────────────────────────────────────────────────

class QuestionCard extends StatelessWidget {
  final String title;
  final String? description;
  final String category;
  final String answerType;
  final List<String>? options;
  final bool isVoted;
  final void Function(String answer)? onAnswer;
  final VoidCallback? onViewMap;

  const QuestionCard({
    super.key,
    required this.title,
    required this.description,
    required this.category,
    required this.answerType,
    this.options,
    this.isVoted = false,
    this.onAnswer,
    this.onViewMap,
  });

  void _openVoteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VoteSheet(
        title: title,
        description: description,
        category: category,
        answerType: answerType,
        options: options,
        onAnswer: (answer) {
          Navigator.pop(context);
          onAnswer?.call(answer);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Farbiger Top-Stripe
          Container(height: 4, color: color),

          Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kategorie-Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _categoryBg(category),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category.isNotEmpty ? category : 'Allgemein',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                // Titel
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                    height: 1.35,
                  ),
                ),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF636366),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),

                // Action Row
                if (isVoted)
                  _VotedActionRow(onViewMap: onViewMap)
                else
                  _UnvotedActionRow(
                    onVote: () => _openVoteSheet(context),
                  ),

                const SizedBox(height: 10),
              ],
            ),
          ),

          // Bottom Banner
          if (isVoted)
            _KarteBanner(onTap: onViewMap)
          else
            _FairPlayBanner(onTap: () => _openVoteSheet(context)),
        ],
      ),
    );
  }
}

// ── Action Rows ───────────────────────────────────────────────────────────────

class _UnvotedActionRow extends StatelessWidget {
  final VoidCallback onVote;
  const _UnvotedActionRow({required this.onVote});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: onVote,
              icon: const Icon(Icons.how_to_vote_outlined, size: 14),
              label: const Text('Abstimmen',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShmTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_outline, size: 13,
                  color: Color(0xFFAEAEB2)),
              label: const Text('Ergebnisse',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFAEAEB2))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD1D1D6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VotedActionRow extends StatelessWidget {
  final VoidCallback? onViewMap;
  const _VotedActionRow({this.onViewMap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check_circle_outline, size: 14,
                  color: Color(0xFF166534)),
              label: const Text('Abgestimmt',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF166534))),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFDCFCE7),
                side: const BorderSide(color: Color(0xFF86EFAC)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: onViewMap,
              icon: const Icon(Icons.bar_chart_outlined, size: 14),
              label: const Text('Ergebnisse',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShmTheme.primary,
                side: const BorderSide(color: Color(0xFF93C5FD)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Banners ───────────────────────────────────────────────────────────────────

class _FairPlayBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _FairPlayBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          border: Border(
            top: BorderSide(color: const Color(0xFFFBBF24).withOpacity(0.5)),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handshake_outlined, size: 13, color: Color(0xFF92400E)),
            SizedBox(width: 6),
            Text(
              'Fair Play — erst abstimmen um Karte zu sehen',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E)),
            ),
          ],
        ),
      ),
    );
  }
}

class _KarteBanner extends StatelessWidget {
  final VoidCallback? onTap;
  const _KarteBanner({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 13),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
          ),
          border: Border(
            top: BorderSide(color: Color(0xFFBAD4FC)),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 14, color: Color(0xFF1D4ED8)),
            SizedBox(width: 6),
            Text(
              'Karte zu dieser Frage ansehen',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8)),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: Color(0xFF1D4ED8)),
          ],
        ),
      ),
    );
  }
}

// ── Vote Bottom Sheet ─────────────────────────────────────────────────────────

class _VoteSheet extends StatelessWidget {
  final String title;
  final String? description;
  final String category;
  final String answerType;
  final List<String>? options;
  final void Function(String) onAnswer;

  const _VoteSheet({
    required this.title,
    required this.description,
    required this.category,
    required this.answerType,
    required this.options,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Hero
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.75),
                        letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3),
                  ),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description!,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.70)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Answer section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              child: _buildAnswerSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection() {
    switch (answerType) {
      case 'binary':
        return _BinaryButtons(onAnswer: onAnswer);
      case 'scale':
        return _ScaleButtons(onAnswer: onAnswer);
      case 'multiple_choice':
        return _MultipleChoiceButtons(
            options: options ?? [], onAnswer: onAnswer);
      default:
        return Text('Unbekannter Antworttyp: $answerType',
            style: const TextStyle(color: Colors.red));
    }
  }
}

// ── Answer Widgets ────────────────────────────────────────────────────────────

class _BinaryButtons extends StatelessWidget {
  final void Function(String) onAnswer;
  const _BinaryButtons({required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => onAnswer('ja'),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Ja',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShmTheme.yes,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => onAnswer('nein'),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Nein',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShmTheme.no,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScaleButtons extends StatelessWidget {
  final void Function(String) onAnswer;
  const _ScaleButtons({required this.onAnswer});

  static const _colors = [
    Color(0xFFC62828),
    Color(0xFFE64A19),
    Color(0xFFF9A825),
    Color(0xFF558B2F),
    Color(0xFF1B5E20),
  ];

  static const _labels = ['Nein', 'Eher nein', 'Neutral', 'Eher ja', 'Ja'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wie stimmst du zu?',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (i) {
            final color = _colors[i];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 4 ? 7 : 0),
                child: InkWell(
                  onTap: () => onAnswer((i + 1).toString()),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: color.withOpacity(0.35)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${i + 1}',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: color),
                        ),
                        Text(
                          _labels[i],
                          style: TextStyle(
                              fontSize: 7.5,
                              color: color,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _MultipleChoiceButtons extends StatelessWidget {
  final List<String> options;
  final void Function(String) onAnswer;

  const _MultipleChoiceButtons(
      {required this.options, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Text('Keine Antwortoptionen vorhanden.',
          style: TextStyle(color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.asMap().entries.map((entry) {
        final idx = entry.key;
        final option = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: idx < options.length - 1 ? 9 : 0),
          child: InkWell(
            onTap: () => onAnswer(option),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E5EA), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      String.fromCharCode(65 + idx),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(option,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
