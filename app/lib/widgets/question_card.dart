import 'package:flutter/material.dart';
import '../theme.dart';
import 'common.dart';
import 'stats_widgets.dart';

/// Frage-Karte im Feed. Zeigt vor dem Abstimmen den Vote-Einstieg,
/// danach die eigene Antwort und den Weg zu den Ergebnissen.
class QuestionCard extends StatelessWidget {
  final String title;
  final String? description;
  final String category;
  final String answerType;
  final List<String>? options;
  final bool isVoted;
  final String? myAnswer;
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
    this.myAnswer,
    this.onAnswer,
    this.onViewMap,
  });

  void _openVoteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => VoteSheet(
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
    final scheme = Theme.of(context).colorScheme;
    final shm = context.shm;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ShmTheme.gapL, vertical: ShmTheme.gapXs + 2),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isVoted ? onViewMap : () => _openVoteSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(ShmTheme.gapL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CategoryBadge(category),
                    const Spacer(),
                    if (isVoted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: shm.yesContainer,
                          borderRadius:
                              BorderRadius.circular(ShmTheme.radiusXl),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 14, color: shm.yes),
                            const SizedBox(width: 4),
                            Text(
                              myAnswer != null
                                  ? answerLabel(myAnswer!)
                                  : 'Abgestimmt',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: shm.yes,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: ShmTheme.gapM),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: ShmTheme.gapXs + 2),
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: ShmTheme.gapL),
                if (isVoted)
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: onViewMap,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Ergebnisse auf der Karte'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44)),
                    ),
                  )
                else ...[
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openVoteSheet(context),
                      icon: const Icon(Icons.how_to_vote_outlined, size: 18),
                      label: const Text('Jetzt abstimmen'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44)),
                    ),
                  ),
                  const SizedBox(height: ShmTheme.gapS + 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 13, color: scheme.outline),
                      const SizedBox(width: 5),
                      Text(
                        'Ergebnisse werden nach deiner Stimme sichtbar',
                        style: TextStyle(
                            fontSize: 12, color: scheme.outline),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Vote Bottom Sheet ─────────────────────────────────────────────────────────

class VoteSheet extends StatelessWidget {
  final String title;
  final String? description;
  final String category;
  final String answerType;
  final List<String>? options;
  final void Function(String) onAnswer;

  const VoteSheet({
    super.key,
    required this.title,
    required this.description,
    required this.category,
    required this.answerType,
    required this.options,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              ShmTheme.gapXl, 0, ShmTheme.gapXl, ShmTheme.gapXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryBadge(category),
              const SizedBox(height: ShmTheme.gapM),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: ShmTheme.gapS),
                Text(
                  description!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: ShmTheme.gapXl),
              _buildAnswerSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerSection(BuildContext context) {
    switch (answerType) {
      case 'binary':
        return _BinaryButtons(onAnswer: onAnswer);
      case 'scale':
        return _ScaleButtons(onAnswer: onAnswer);
      case 'multiple_choice':
        return _MultipleChoiceButtons(options: options ?? [], onAnswer: onAnswer);
      default:
        return Text('Unbekannter Antworttyp: $answerType',
            style: TextStyle(color: context.shm.no));
    }
  }
}

// ── Answer Widgets ────────────────────────────────────────────────────────────

class _BinaryButtons extends StatelessWidget {
  final void Function(String) onAnswer;
  const _BinaryButtons({required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final shm = context.shm;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: () => onAnswer('ja'),
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Ja'),
              style: FilledButton.styleFrom(
                backgroundColor: shm.yes,
                foregroundColor: shm.onYes,
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: ShmTheme.gapM),
        Expanded(
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: () => onAnswer('nein'),
              icon: const Icon(Icons.close, size: 20),
              label: const Text('Nein'),
              style: FilledButton.styleFrom(
                backgroundColor: shm.no,
                foregroundColor: shm.onNo,
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wie sehr stimmst du zu?',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
        const SizedBox(height: ShmTheme.gapM),
        Row(
          children: [
            for (int i = 1; i <= 5; i++) ...[
              if (i > 1) const SizedBox(width: ShmTheme.gapS),
              Expanded(
                child: _ScaleButton(
                  value: i,
                  color: answerColor(context, '$i', i - 1),
                  onTap: () => onAnswer('$i'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: ShmTheme.gapS),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Stimme nicht zu',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
            Text('Stimme voll zu',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

class _ScaleButton extends StatelessWidget {
  final int value;
  final Color color;
  final VoidCallback onTap;

  const _ScaleButton(
      {required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ShmTheme.radiusM),
      child: Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.28 : 0.12),
          borderRadius: BorderRadius.circular(ShmTheme.radiusM),
          border: Border.all(color: color.withOpacity(0.45), width: 1.5),
        ),
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Color.lerp(color, Colors.white, 0.35) : color,
          ),
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    if (options.isEmpty) {
      return Text('Keine Antwortoptionen vorhanden.',
          style: TextStyle(color: scheme.onSurfaceVariant));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (idx, option) in options.indexed) ...[
          if (idx > 0) const SizedBox(height: ShmTheme.gapS + 2),
          InkWell(
            onTap: () => onAnswer(option),
            borderRadius: BorderRadius.circular(ShmTheme.radiusM),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ShmTheme.gapL, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant, width: 1.5),
                borderRadius: BorderRadius.circular(ShmTheme.radiusM),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(ShmTheme.radiusS),
                    ),
                    child: Text(
                      String.fromCharCode(65 + idx),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: ShmTheme.gapM),
                  Expanded(
                    child: Text(option,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
