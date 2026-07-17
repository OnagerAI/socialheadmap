import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/stats_widgets.dart';

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
  Object? _error;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deviceToken = await StorageService.getOrCreateDeviceToken();
      final data = await ApiService.getLandkreisDetail(
          widget.questionId, widget.landkreisId, deviceToken);
      if (mounted) {
        setState(() {
          _totalVotes = data['total_votes'] as int? ?? 0;
          _hasQuorum = data['has_quorum'] as bool? ?? false;
          _totalAnswers =
              (data['total_answers'] as Map<String, dynamic>?) ?? {};
          _ageGroups = (data['age_groups'] as Map<String, dynamic>?) ?? {};
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.landkreisName),
            Text(
              widget.questionTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(error: _error!, onRetry: _loadData);

    return ListView(
      padding: const EdgeInsets.all(ShmTheme.gapL),
      children: [
        StatsHeaderCard(
          totalVotes: _totalVotes,
          totalAnswers: _totalAnswers,
          badge: _hasQuorum ? null : 'Kein Quorum',
        ),
        const SizedBox(height: ShmTheme.gapL),
        if (_hasQuorum) ...[
          AgeGroupBreakdown(ageGroups: _ageGroups),
          const SizedBox(height: ShmTheme.gapM),
          Text(
            'Basis: $_totalVotes Stimmen aus ${widget.landkreisName}',
            style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ] else
          const EmptyState(
            icon: Icons.how_to_vote_outlined,
            title: 'Noch keine Stimmen',
            subtitle:
                'Für diesen Landkreis liegen noch keine Stimmen vor.\nSobald hier abgestimmt wird, erscheinen die Ergebnisse.',
          ),
      ],
    );
  }
}
