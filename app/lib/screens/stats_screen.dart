import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

const String _baseUrl = 'https://shm.13-61-179-136.nip.io';

class StatsScreen extends StatefulWidget {
  final String questionId;
  final Map<String, dynamic> question;

  const StatsScreen({
    super.key,
    required this.questionId,
    required this.question,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _snapshot;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/stats/map/${widget.questionId}'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      if (mounted) {
        setState(() {
          _snapshot = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _landkreise {
    final list = (_snapshot?['landkreise'] as List<dynamic>?) ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Map<String, int> get _gesamtVerteilung {
    final totals = <String, int>{};
    for (final lk in _landkreise) {
      if (lk['has_quorum'] != true) continue;
      final results = lk['results'] as Map<String, dynamic>? ?? {};
      for (final entry in results.entries) {
        final votes = (entry.value as num?)?.toInt() ?? 0;
        totals[entry.key] = (totals[entry.key] ?? 0) + votes;
      }
    }
    return totals;
  }

  int get _gesamtStimmen {
    return _landkreise.fold<int>(
      0,
      (sum, lk) => sum + ((lk['total_votes'] as int?) ?? 0),
    );
  }

  List<Map<String, dynamic>> get _top5Landkreise {
    final mitQuorum =
        _landkreise.where((lk) => lk['has_quorum'] == true).toList();
    mitQuorum.sort(
      (a, b) =>
          ((b['total_votes'] as int?) ?? 0)
              .compareTo((a['total_votes'] as int?) ?? 0),
    );
    return mitQuorum.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.question['title'] as String? ?? 'Statistiken';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _loadSnapshot,
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Statistiken konnten nicht geladen werden',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadSnapshot,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }
    if (_snapshot == null) {
      return const Center(child: Text('Keine Daten vorhanden'));
    }
    return RefreshIndicator(
      onRefresh: _loadSnapshot,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GesamtstimmenCard(gesamtStimmen: _gesamtStimmen),
          const SizedBox(height: 16),
          _VerteilungsCard(verteilung: _gesamtVerteilung),
          const SizedBox(height: 16),
          _Top5Card(landkreise: _top5Landkreise),
        ],
      ),
    );
  }
}

class _GesamtstimmenCard extends StatelessWidget {
  final int gesamtStimmen;

  const _GesamtstimmenCard({required this.gesamtStimmen});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.how_to_vote, size: 40, color: Colors.blue),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gesamtstimmen',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                Text(
                  gesamtStimmen.toString(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VerteilungsCard extends StatefulWidget {
  final Map<String, int> verteilung;

  const _VerteilungsCard({required this.verteilung});

  @override
  State<_VerteilungsCard> createState() => _VerteilungsCardState();
}

class _VerteilungsCardState extends State<_VerteilungsCard> {
  int? _touchedIndex;

  static const _answerColors = {
    'ja': Colors.green,
    'nein': Colors.red,
    '1': Colors.blue,
    '2': Colors.lightBlue,
    '3': Colors.orange,
    '4': Colors.deepOrange,
    '5': Colors.purple,
  };

  Color _colorFor(String key, int index) {
    if (_answerColors.containsKey(key.toLowerCase())) {
      return _answerColors[key.toLowerCase()]!;
    }
    final palette = [
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.indigo,
    ];
    return palette[index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.verteilung.entries.toList();
    if (entries.isEmpty) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Keine Daten mit Quorum vorhanden')),
        ),
      );
    }

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    final isBinary = entries.length == 2 &&
        entries.any((e) => e.key == 'ja') &&
        entries.any((e) => e.key == 'nein');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gesamtverteilung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            isBinary
                ? _buildPieChart(entries, total)
                : _buildBarChart(entries, total),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: entries.asMap().entries.map((e) {
                final idx = e.key;
                final entry = e.value;
                final pct =
                    total > 0 ? (entry.value / total * 100).round() : 0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _colorFor(entry.key, idx),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.key.toUpperCase()}: ${entry.value} ($pct%)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(
      List<MapEntry<String, int>> entries, int total) {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: entries.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            final isTouched = _touchedIndex == idx;
            final pct = total > 0 ? entry.value / total * 100 : 0.0;
            return PieChartSectionData(
              color: _colorFor(entry.key, idx),
              value: entry.value.toDouble(),
              title: isTouched ? '${pct.round()}%' : '',
              radius: isTouched ? 70 : 60,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {
              setState(() {
                if (response?.touchedSection != null) {
                  _touchedIndex =
                      response!.touchedSection!.touchedSectionIndex;
                } else {
                  _touchedIndex = null;
                }
              });
            },
          ),
          sectionsSpace: 2,
          centerSpaceRadius: 30,
        ),
      ),
    );
  }

  Widget _buildBarChart(
      List<MapEntry<String, int>> entries, int total) {
    final maxValue =
        entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxValue * 1.2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entries[idx].key.toUpperCase(),
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value.toDouble(),
                  color: _colorFor(e.value.key, e.key),
                  width: 24,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Top5Card extends StatelessWidget {
  final List<Map<String, dynamic>> landkreise;

  const _Top5Card({required this.landkreise});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 Landkreise nach Stimmenzahl',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (landkreise.isEmpty)
              const Text('Keine Landkreise mit Quorum vorhanden')
            else
              ...landkreise.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final lk = entry.value;
                final name = lk['landkreis_name'] as String? ??
                    lk['landkreis_id'] as String? ??
                    '–';
                final votes = lk['total_votes'] as int? ?? 0;
                final results =
                    lk['results'] as Map<String, dynamic>? ?? {};

                String resultText = '';
                if (results.isNotEmpty) {
                  final parts = results.entries
                      .map((e) =>
                          '${e.key.toUpperCase()}: ${(e.value as num?)?.toInt() ?? 0}')
                      .join(' | ');
                  resultText = parts;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: rank == 1
                                ? Colors.amber.shade700
                                : Colors.grey,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            if (resultText.isNotEmpty)
                              Text(
                                resultText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '$votes Stimmen',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
