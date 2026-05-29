import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String _baseUrl = 'https://shm.13-61-179-136.nip.io';

const _ageLabels = {
  'A': '18–29',
  'B': '30–39',
  'C': '40–49',
  'D': '50–59',
  'E': '60+',
};

class LandkreisDetailScreen extends StatefulWidget {
  final String landkreisId;
  final String landkreisName;
  final String questionId;
  final String questionTitle;

  const LandkreisDetailScreen({
    super.key,
    required this.landkreisId,
    required this.landkreisName,
    required this.questionId,
    required this.questionTitle,
  });

  @override
  State<LandkreisDetailScreen> createState() => _LandkreisDetailScreenState();
}

class _LandkreisDetailScreenState extends State<LandkreisDetailScreen> {
  bool _loading = true;
  String? _error;
  int _totalVotes = 0;
  bool _hasQuorum = false;
  Map<String, dynamic> _totalAnswers = {};
  Map<String, dynamic> _ageGroups = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uri = Uri.parse('$_baseUrl/stats/map/${widget.questionId}/landkreis-detail')
          .replace(queryParameters: {'landkreis_id': widget.landkreisId});
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      setState(() {
        _totalVotes   = data['total_votes']   as int? ?? 0;
        _hasQuorum    = data['has_quorum']    as bool? ?? false;
        _totalAnswers = (data['total_answers'] as Map<String, dynamic>?) ?? {};
        _ageGroups    = (data['age_groups']    as Map<String, dynamic>?) ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.landkreisName, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(widget.questionTitle,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _loadData,
              icon: const Icon(Icons.refresh), label: const Text('Erneut versuchen')),
        ]),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF37474F), Color(0xFF263238)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_city, size: 48, color: Colors.white54),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_totalVotes',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800,
                      color: Colors.white, height: 1)),
              const Text('Stimmen gesamt',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              if (!_hasQuorum)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Kein Quorum (< 10 Stimmen)',
                      style: TextStyle(fontSize: 11, color: Colors.white,
                          fontWeight: FontWeight.w700)),
                )
              else
                Row(children: [
                  _MiniStat(
                    label: 'Ja',
                    value: (_totalAnswers['ja'] as num?)?.toInt() ?? 0,
                    rel: _totalVotes > 0
                        ? ((_totalAnswers['ja'] as num?)?.toInt() ?? 0) / _totalVotes
                        : 0.0,
                    color: const Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 12),
                  _MiniStat(
                    label: 'Nein',
                    value: (_totalAnswers['nein'] as num?)?.toInt() ?? 0,
                    rel: _totalVotes > 0
                        ? ((_totalAnswers['nein'] as num?)?.toInt() ?? 0) / _totalVotes
                        : 0.0,
                    color: const Color(0xFFEF5350),
                  ),
                ]),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        if (_hasQuorum) ...[
          _StatsTable(
            title: 'Abstimmung nach Altersgruppe',
            subtitle: 'Absolute Stimmen und prozentualer Anteil pro Gruppe',
            ageGroups: _ageGroups,
            totalAnswers: _totalAnswers,
            totalVotes: _totalVotes,
          ),
          const SizedBox(height: 12),
          Text(
            'Basis: $_totalVotes Stimmen aus ${widget.landkreisName}',
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ] else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Für diesen Landkreis liegen weniger als 10 Stimmen vor.\nErgebnisse werden erst ab 10 Stimmen angezeigt.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final double rel;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.rel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
      Text('${(rel * 100).round()}%', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.65))),
    ]);
  }
}

// ── Stats Table (shared style mit BundeslandStats) ────────────────────────────

class _StatsTable extends StatelessWidget {
  final String title;
  final String subtitle;
  final Map<String, dynamic> ageGroups;
  final Map<String, dynamic> totalAnswers;
  final int totalVotes;

  const _StatsTable({
    required this.title,
    required this.subtitle,
    required this.ageGroups,
    required this.totalAnswers,
    required this.totalVotes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          _TableRow(isHeader: true,
              cells: ['Alter', 'Ja abs.', 'Nein abs.', 'Ja %', 'Nein %']),
          ..._ageLabels.entries.map((entry) {
            final ag      = ageGroups[entry.key] as Map<String, dynamic>?;
            final answers = (ag?['answers'] as Map<String, dynamic>?) ?? {};
            final total   = (ag?['total']   as num?)?.toInt() ?? 0;
            final ja      = (answers['ja']   as num?)?.toInt() ?? 0;
            final nein    = (answers['nein'] as num?)?.toInt() ?? 0;
            final jaRel   = total > 0 ? (ja   / total * 100).round() : 0;
            final neinRel = total > 0 ? (nein / total * 100).round() : 0;
            return _TableRow(
              isHeader: false,
              cells: [
                entry.value, ja.toString(), nein.toString(),
                total > 0 ? '$jaRel%' : '–', total > 0 ? '$neinRel%' : '–',
              ],
              empty: total == 0,
            );
          }),
          const Divider(height: 1, thickness: 1),
          () {
            final ja      = (totalAnswers['ja']   as num?)?.toInt() ?? 0;
            final nein    = (totalAnswers['nein'] as num?)?.toInt() ?? 0;
            final jaRel   = totalVotes > 0 ? (ja   / totalVotes * 100).round() : 0;
            final neinRel = totalVotes > 0 ? (nein / totalVotes * 100).round() : 0;
            return _TableRow(
              isHeader: false, isTotal: true,
              cells: [
                'Gesamt', ja.toString(), nein.toString(),
                totalVotes > 0 ? '$jaRel%' : '–', totalVotes > 0 ? '$neinRel%' : '–',
              ],
            );
          }(),
        ]),
      ),
    ]);
  }
}

class _TableRow extends StatelessWidget {
  final List<String> cells;
  final bool isHeader;
  final bool isTotal;
  final bool empty;

  const _TableRow({
    required this.cells,
    this.isHeader = false,
    this.isTotal = false,
    this.empty = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isHeader
        ? const Color(0xFFF5F5F5)
        : isTotal ? const Color(0xFFEEF4FF) : Colors.white;
    return Container(
      color: bgColor,
      child: IntrinsicHeight(
        child: Row(
          children: cells.asMap().entries.map((entry) {
            final i = entry.key;
            final text = entry.value;
            Color? textColor;
            if (!isHeader && !empty) {
              if (i == 1 || i == 3) textColor = const Color(0xFF2E7D32);
              if (i == 2 || i == 4) textColor = const Color(0xFFC62828);
            }
            return Expanded(
              flex: i == 0 ? 2 : 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  border: Border(
                    right: i < cells.length - 1
                        ? BorderSide(color: Colors.grey.shade200) : BorderSide.none,
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Text(
                  text,
                  textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: (isHeader || isTotal || i == 0) ? FontWeight.w700 : FontWeight.normal,
                    color: isHeader ? const Color(0xFF636366)
                        : empty && i > 0 ? Colors.grey.shade400
                        : textColor ?? const Color(0xFF1C1C1E),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
