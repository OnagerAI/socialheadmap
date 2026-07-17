import 'package:flutter/material.dart';
import '../constants.dart';
import '../theme.dart';

/// Farbe für einen Antwort-Schlüssel (ja/nein, Skala 1–5, Multiple Choice).
Color answerColor(BuildContext context, String key, int index) {
  final shm = context.shm;
  switch (key.toLowerCase()) {
    case 'ja':
      return shm.yes;
    case 'nein':
      return shm.no;
    case '1':
      return const Color(0xFFC62828);
    case '2':
      return const Color(0xFFE64A19);
    case '3':
      return const Color(0xFFF9A825);
    case '4':
      return const Color(0xFF558B2F);
    case '5':
      return const Color(0xFF1B5E20);
  }
  const palette = [
    Color(0xFF5C85D6),
    Color(0xFF26A69A),
    Color(0xFFFFB347),
    Color(0xFFBA68C8),
    Color(0xFFEC407A),
    Color(0xFF7E57C2),
  ];
  return palette[index % palette.length];
}

String answerLabel(String key) {
  switch (key.toLowerCase()) {
    case 'ja':
      return 'Ja';
    case 'nein':
      return 'Nein';
    default:
      return key;
  }
}

/// Sortiert Antwort-Schlüssel stabil: ja, nein, 1–5, dann alphabetisch.
List<String> sortedAnswerKeys(Iterable<String> keys) {
  const order = ['ja', 'nein', '1', '2', '3', '4', '5'];
  final list = keys.toList();
  list.sort((a, b) {
    final ia = order.indexOf(a.toLowerCase());
    final ib = order.indexOf(b.toLowerCase());
    if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
    if (ia >= 0) return -1;
    if (ib >= 0) return 1;
    return a.compareTo(b);
  });
  return list;
}

/// Großer Kopfbereich einer Detail-Statistik: Gesamtzahl + Verteilungsbalken.
class StatsHeaderCard extends StatelessWidget {
  final int totalVotes;
  final Map<String, dynamic> totalAnswers;
  final Widget? leading;
  final String? badge;

  const StatsHeaderCard({
    super.key,
    required this.totalVotes,
    required this.totalAnswers,
    this.leading,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ShmTheme.gapL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: ShmTheme.gapL),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalVotes',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('Stimmen gesamt',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius:
                          BorderRadius.circular(ShmTheme.radiusS),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            if (totalAnswers.isNotEmpty && totalVotes > 0) ...[
              const SizedBox(height: ShmTheme.gapL),
              DistributionBar(answers: totalAnswers, total: totalVotes),
              const SizedBox(height: ShmTheme.gapM),
              AnswerLegend(answers: totalAnswers, total: totalVotes),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontaler Stapelbalken für eine Antwortverteilung.
class DistributionBar extends StatelessWidget {
  final Map<String, dynamic> answers;
  final int total;
  final double height;

  const DistributionBar(
      {super.key, required this.answers, required this.total, this.height = 12});

  @override
  Widget build(BuildContext context) {
    final keys = sortedAnswerKeys(answers.keys);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Row(
        children: [
          for (final (i, key) in keys.indexed)
            Expanded(
              flex: ((answers[key] as num?)?.toInt() ?? 0).clamp(0, 1 << 20),
              child: Container(
                  height: height, color: answerColor(context, key, i)),
            ),
        ],
      ),
    );
  }
}

/// Legende: Farbchip + Label + Anzahl + Prozent pro Antwort.
class AnswerLegend extends StatelessWidget {
  final Map<String, dynamic> answers;
  final int total;

  const AnswerLegend({super.key, required this.answers, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keys = sortedAnswerKeys(answers.keys);
    return Wrap(
      spacing: ShmTheme.gapL,
      runSpacing: ShmTheme.gapS,
      children: [
        for (final (i, key) in keys.indexed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: answerColor(context, key, i),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${answerLabel(key)} · ${(answers[key] as num?)?.toInt() ?? 0}'
                ' (${total > 0 ? (((answers[key] as num?)?.toInt() ?? 0) / total * 100).round() : 0}%)',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
      ],
    );
  }
}

/// Aufschlüsselung nach Altersgruppe: pro Gruppe ein Stapelbalken mit Zahlen.
/// Ersetzt die frühere 5-Spalten-Tabelle und funktioniert für alle
/// Antworttypen (binär, Skala, Multiple Choice).
class AgeGroupBreakdown extends StatelessWidget {
  final Map<String, dynamic> ageGroups;

  const AgeGroupBreakdown({super.key, required this.ageGroups});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ShmTheme.gapL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nach Altersgruppe',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: ShmTheme.gapL),
            for (final entry in ageLabels.entries) ...[
              _AgeRow(
                label: entry.value,
                data: ageGroups[entry.key] as Map<String, dynamic>?,
              ),
              if (entry.key != ageLabels.keys.last)
                Divider(
                    height: ShmTheme.gapXl,
                    color: scheme.outlineVariant.withOpacity(0.4)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgeRow extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? data;

  const _AgeRow({required this.label, required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answers = (data?['answers'] as Map<String, dynamic>?) ?? {};
    final total = (data?['total'] as num?)?.toInt() ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: total == 0
              ? Text('Keine Stimmen',
                  style: TextStyle(
                      fontSize: 12, color: scheme.outline))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DistributionBar(
                        answers: answers, total: total, height: 10),
                    const SizedBox(height: 6),
                    AnswerLegend(answers: answers, total: total),
                  ],
                ),
        ),
        const SizedBox(width: ShmTheme.gapM),
        Text('$total',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
