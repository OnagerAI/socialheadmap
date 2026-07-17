import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/stats_widgets.dart';

class BundeslandStatsScreen extends StatefulWidget {
  final String bundesland;
  final String questionId;
  final String questionTitle;

  const BundeslandStatsScreen({
    super.key,
    required this.bundesland,
    required this.questionId,
    required this.questionTitle,
  });

  @override
  State<BundeslandStatsScreen> createState() => _BundeslandStatsScreenState();
}

class _BundeslandStatsScreenState extends State<BundeslandStatsScreen> {
  bool _loading = true;
  Object? _error;
  int _totalVotes = 0;
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
      final data = await ApiService.getBundeslandDetail(
          widget.questionId, widget.bundesland);
      if (mounted) {
        setState(() {
          _totalVotes = data['total_votes'] as int? ?? 0;
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
            Text(widget.bundesland),
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
    if (_totalVotes == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WappenWidget(bundesland: widget.bundesland, size: 72),
              const SizedBox(height: ShmTheme.gapXl),
              Text(
                'Noch keine auswertbaren Stimmen aus ${widget.bundesland}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: ShmTheme.gapS),
              Text(
                'Ergebnisse erscheinen, sobald Landkreise das Quorum von 10 Stimmen erreichen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(ShmTheme.gapL),
      children: [
        StatsHeaderCard(
          totalVotes: _totalVotes,
          totalAnswers: _totalAnswers,
          leading: WappenWidget(bundesland: widget.bundesland, size: 52),
        ),
        const SizedBox(height: ShmTheme.gapL),
        AgeGroupBreakdown(ageGroups: _ageGroups),
        const SizedBox(height: ShmTheme.gapM),
        Text(
          'Basis: $_totalVotes Stimmen aus Landkreisen mit Quorum (≥ 10 Stimmen)',
          style: TextStyle(
            fontSize: 11.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Bundesland-Wappen aus den gebündelten SVG-Assets.
class WappenWidget extends StatelessWidget {
  final String bundesland;
  final double size;
  const WappenWidget({super.key, required this.bundesland, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = wappenAssets[bundesland];
    if (asset == null) {
      return Icon(Icons.location_city,
          size: size, color: Theme.of(context).colorScheme.outline);
    }
    return SvgPicture.asset(asset, width: size, height: size, fit: BoxFit.contain);
  }
}
