import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/stats_widgets.dart';
import 'bundesland_stats_screen.dart';
import 'landkreis_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final String questionId;
  final String questionTitle;

  const MapScreen({
    super.key,
    required this.questionId,
    required this.questionTitle,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static Map<String, dynamic>? _cachedGeoJson;

  Map<String, dynamic>? _geoJson;
  Map<String, Map<String, dynamic>>? _landkreisData;
  Map<String, int> _bundeslandVotes = {};
  String _deviceToken = '';
  bool _loading = true;
  Object? _error;

  bool _liveActive = false;
  Timer? _liveTimer;
  int _liveTotalVotes = 0;

  final _mapController = MapController();
  String? _selectedBundesland;

  static const _germanyCenter = LatLng(51.3, 10.4);
  static const _germanyZoom = 5.8;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _deviceToken = await StorageService.getOrCreateDeviceToken();
      await Future.wait([_loadGeoJson(), _loadSnapshot(), _loadBundeslandData()]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadGeoJson() async {
    if (_cachedGeoJson != null) {
      if (mounted) setState(() => _geoJson = _cachedGeoJson);
      return;
    }
    final data = await ApiService.getLandkreiseGeoJson();
    _cachedGeoJson = data;
    if (mounted) setState(() => _geoJson = data);
  }

  Future<void> _loadSnapshot() async {
    final data =
        await ApiService.getMapSnapshot(widget.questionId, _deviceToken);
    final landkreise = (data['landkreise'] as List<dynamic>?) ?? [];
    final map = <String, Map<String, dynamic>>{};
    for (final lk in landkreise) {
      final m = lk as Map<String, dynamic>;
      map[m['landkreis_id'] as String] = m;
    }
    if (mounted) {
      setState(() {
        _landkreisData = map;
        _loading = false;
      });
    }
  }

  Future<void> _loadBundeslandData() async {
    try {
      final data = await ApiService.getBundeslandSnapshot(
          widget.questionId, _deviceToken);
      final bls = (data['bundeslaender'] as List<dynamic>?) ?? [];
      final map = <String, int>{};
      for (final bl in bls) {
        final m = bl as Map<String, dynamic>;
        map[m['name'] as String] = m['total_votes'] as int;
      }
      if (mounted) setState(() => _bundeslandVotes = map);
    } catch (_) {}
  }

  // ── Live-Modus: leichter Zähler-Poll, Snapshot nur bei Änderung ───────────

  void _toggleLive() => _liveActive ? _stopLive() : _startLive();

  void _startLive() {
    setState(() => _liveActive = true);
    _liveTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final total = await ApiService.getLiveTotal(widget.questionId);
        if (mounted && total != _liveTotalVotes) {
          _liveTotalVotes = total;
          await _loadSnapshot();
          await _loadBundeslandData();
        }
      } catch (_) {}
    });
  }

  void _stopLive() {
    _liveTimer?.cancel();
    _liveTimer = null;
    setState(() => _liveActive = false);
  }

  // ── Navigation Übersicht ↔ Bundesland-Detail ──────────────────────────────

  void _selectBundesland(String blName) {
    setState(() => _selectedBundesland = blName);
    final bounds = _computeBundeslandBounds(blName);
    if (bounds != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
          );
        }
      });
    }
  }

  void _backToOverview() {
    setState(() => _selectedBundesland = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(_germanyCenter, _germanyZoom);
    });
  }

  LatLngBounds? _computeBundeslandBounds(String blName) {
    if (_geoJson == null) return null;
    final features = (_geoJson!['features'] as List<dynamic>? ?? []);
    double? minLat, maxLat, minLng, maxLng;

    void processCoord(dynamic c) {
      final coord = c as List<dynamic>;
      final lng = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      minLat = minLat == null ? lat : (lat < minLat! ? lat : minLat!);
      maxLat = maxLat == null ? lat : (lat > maxLat! ? lat : maxLat!);
      minLng = minLng == null ? lng : (lng < minLng! ? lng : minLng!);
      maxLng = maxLng == null ? lng : (lng > maxLng! ? lng : maxLng!);
    }

    void processPoly(List<dynamic> poly) {
      if (poly.isEmpty) return;
      for (final c in poly[0] as List<dynamic>) {
        processCoord(c);
      }
    }

    for (final feature in features) {
      final f = feature as Map<String, dynamic>;
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      if (props['bl'] != blName) continue;
      final geometry = f['geometry'] as Map<String, dynamic>? ?? {};
      final geoType = geometry['type'] as String? ?? '';
      final coords = geometry['coordinates'] as List<dynamic>? ?? [];
      if (geoType == 'Polygon') {
        processPoly(coords);
      } else if (geoType == 'MultiPolygon') {
        for (final poly in coords) {
          processPoly(poly as List<dynamic>);
        }
      }
    }

    if (minLat == null) return null;
    return LatLngBounds(LatLng(minLat!, minLng!), LatLng(maxLat!, maxLng!));
  }

  // ── Einfärbung ────────────────────────────────────────────────────────────

  Color _colorForOverview(ShmColors shm, Color emptyColor, String bundesland) {
    final votes = _bundeslandVotes[bundesland] ?? 0;
    if (votes == 0) return emptyColor;

    // Rang-basierte Einfärbung: Position unter allen BL mit Stimmen.
    final ranked = _bundeslandVotes.values.where((v) => v > 0).toList()..sort();
    int rank = 0;
    for (final v in ranked) {
      if (v < votes) rank++;
    }

    final ramp = shm.participationRamp;
    final n = ranked.length;
    final t = n <= 1 ? 1.0 : rank / (n - 1);
    final stepIdx =
        n <= 1 ? ramp.length - 1 : (t * (ramp.length - 1)).round().clamp(0, ramp.length - 1);
    return ramp[stepIdx];
  }

  Color _colorForLandkreis(ShmColors shm, String nuts3) {
    final lk = _landkreisData?[nuts3];
    if (lk == null) return shm.noQuorum.withOpacity(0.5);
    final hasQuorum = lk['has_quorum'] as bool? ?? false;
    final results = lk['results'] as Map<String, dynamic>? ?? {};
    if (!hasQuorum || results.isEmpty) return shm.noQuorum;

    // Binär: Ja/Nein-Verhältnis.
    final ja = (results['ja'] as num?)?.toDouble() ?? 0;
    final nein = (results['nein'] as num?)?.toDouble() ?? 0;
    if (ja > 0 || nein > 0) {
      if (ja >= nein) {
        final t = ((ja / (ja + nein)) - 0.5).clamp(0.0, 0.5) / 0.5;
        return Color.lerp(shm.yesWeak, shm.yesStrong, t)!;
      }
      final t = ((nein / (ja + nein)) - 0.5).clamp(0.0, 0.5) / 0.5;
      return Color.lerp(shm.noWeak, shm.noStrong, t)!;
    }

    // Skala: gewichteter Mittelwert 1–5.
    double total = 0, weightedSum = 0;
    for (int i = 1; i <= 5; i++) {
      final v = (results['$i'] as num?)?.toDouble() ?? 0;
      total += v;
      weightedSum += v * i;
    }
    if (total > 0) {
      final t = ((weightedSum / total) - 1) / 4;
      return Color.lerp(shm.noStrong, shm.yesStrong, t)!;
    }

    // Multiple Choice: Farbe der Gewinner-Option.
    String? winner;
    double maxV = 0;
    results.forEach((k, v) {
      final n = (v as num?)?.toDouble() ?? 0;
      if (n > maxV) {
        maxV = n;
        winner = k;
      }
    });
    if (winner != null) {
      final keys = results.keys.toList();
      return answerColor(context, winner!, keys.indexOf(winner!));
    }
    return shm.noQuorum;
  }

  // ── Sheets ────────────────────────────────────────────────────────────────

  void _onLandkreisTap(String nuts3, String name) {
    final lk = _landkreisData?[nuts3];
    showModalBottomSheet(
      context: context,
      builder: (_) => _LandkreisBottomSheet(
        nuts3: nuts3,
        name: name,
        data: lk,
        questionId: widget.questionId,
        questionTitle: widget.questionTitle,
      ),
    );
  }

  void _openStatsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuestionStatsSheet(
        questionTitle: widget.questionTitle,
        landkreisData: _landkreisData ?? {},
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shm = context.shm;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.questionTitle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Gesamtstatistik',
              onPressed: _openStatsSheet,
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _toggleLive,
              icon: _liveActive
                  ? Icon(Icons.stop_circle_outlined, color: shm.onNo)
                  : const Icon(Icons.sensors),
              label: Text(_liveActive ? 'Live an' : 'Live'),
              backgroundColor: _liveActive ? shm.no : null,
              foregroundColor: _liveActive ? shm.onNo : null,
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(error: _error!, onRetry: _loadData);
    if (_geoJson == null) {
      return const EmptyState(
          icon: Icons.map_outlined, title: 'Keine Kartendaten verfügbar');
    }
    return _buildMap();
  }

  Widget _buildMap() {
    final shm = context.shm;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyColor =
        isDark ? const Color(0xFF23262B) : const Color(0xFFF0F5FA);
    final borderColor =
        isDark ? const Color(0xFF4A5560) : const Color(0xFF6A8FAF);

    final features = (_geoJson!['features'] as List<dynamic>? ?? []);
    final isDetail = _selectedBundesland != null;

    final polygons = <Polygon>[];
    final tapMarkers = <Marker>[];
    final Map<String, List<LatLng>> blCentroids = {};

    for (final feature in features) {
      final f = feature as Map<String, dynamic>;
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final nuts3 = props['nuts3'] as String? ?? '';
      final name = props['name'] as String? ?? nuts3;
      final bl = props['bl'] as String? ?? '';
      final geometry = f['geometry'] as Map<String, dynamic>? ?? {};
      final geoType = geometry['type'] as String? ?? '';
      final coordinates = geometry['coordinates'] as List<dynamic>? ?? [];

      if (isDetail && bl != _selectedBundesland) continue;

      final color = isDetail
          ? _colorForLandkreis(shm, nuts3)
          : _colorForOverview(shm, emptyColor, bl);

      void addPolygon(List<dynamic> rings) {
        final latLngRings =
            rings.map((r) => _toLatLngs(r as List<dynamic>)).toList();
        if (latLngRings.isEmpty) return;
        polygons.add(Polygon(
          points: latLngRings.first,
          holePointsList:
              latLngRings.length > 1 ? latLngRings.sublist(1) : [],
          color: color,
          borderColor: isDetail ? scheme.outline : borderColor,
          borderStrokeWidth: isDetail ? 1.0 : 0.4,
        ));
      }

      if (geoType == 'Polygon') {
        addPolygon(coordinates);
      } else if (geoType == 'MultiPolygon') {
        for (final poly in coordinates) {
          addPolygon(poly as List<dynamic>);
        }
      }

      final centroid = _centroidOf(f);
      if (centroid != null) {
        if (!isDetail) {
          blCentroids.putIfAbsent(bl, () => []).add(centroid);
        }
        tapMarkers.add(Marker(
          point: centroid,
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: isDetail
                ? () => _onLandkreisTap(nuts3, name)
                : () => _selectBundesland(bl),
            child: const ColoredBox(color: Colors.transparent),
          ),
        ));
      }
    }

    // Bundesland-Labels in der Übersicht — tippbar → Statistik-Screen.
    final labelMarkers = <Marker>[];
    if (!isDetail) {
      for (final entry in blCentroids.entries) {
        final blName = entry.key;
        final pts = entry.value;
        final avgLat =
            pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
        final avgLng =
            pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
        final votes = _bundeslandVotes[blName] ?? 0;

        labelMarkers.add(Marker(
          point: LatLng(avgLat, avgLng),
          width: 130,
          height: 48,
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BundeslandStatsScreen(
                  bundesland: blName,
                  questionId: widget.questionId,
                  questionTitle: widget.questionTitle,
                ),
              ),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: scheme.primary.withOpacity(0.4)),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 3)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    blName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                  if (votes > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$votes Stimmen',
                      style: TextStyle(
                        fontSize: 9,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ));
      }
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF15181D), Color(0xFF1B2027)]
                  : const [Color(0xFFDDE8F0), Color(0xFFCDD8E4)],
            ),
          ),
        ),
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _germanyCenter,
            initialZoom: _germanyZoom,
            minZoom: 5.0,
            maxZoom: 12.0,
            backgroundColor: Colors.transparent,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.scrollWheelZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.flingAnimation,
            ),
            cameraConstraint: CameraConstraint.containCenter(
              bounds: LatLngBounds(
                const LatLng(46.5, 5.5),
                const LatLng(56.0, 16.0),
              ),
            ),
          ),
          children: [
            PolygonLayer(polygons: polygons, simplificationTolerance: 0),
            MarkerLayer(markers: tapMarkers),
            if (labelMarkers.isNotEmpty) MarkerLayer(markers: labelMarkers),
          ],
        ),
        if (isDetail)
          Positioned(
            top: ShmTheme.gapM,
            left: ShmTheme.gapM,
            child: Material(
              elevation: 3,
              color: scheme.surface,
              borderRadius: BorderRadius.circular(ShmTheme.radiusXl),
              child: InkWell(
                borderRadius: BorderRadius.circular(ShmTheme.radiusXl),
                onTap: _backToOverview,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ShmTheme.gapL, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _selectedBundesland!,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 88,
          right: ShmTheme.gapM,
          child: _MapLegend(isDetail: isDetail),
        ),
        if (_liveActive)
          Positioned(
            top: ShmTheme.gapM,
            right: ShmTheme.gapM,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: shm.no,
                borderRadius: BorderRadius.circular(ShmTheme.radiusXl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: shm.onNo),
                  const SizedBox(width: 5),
                  Text('LIVE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: shm.onNo)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<LatLng> _toLatLngs(List<dynamic> ring) {
    return ring.map((coord) {
      final c = coord as List<dynamic>;
      return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
    }).toList();
  }

  LatLng? _centroidOf(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final geoType = geometry['type'] as String? ?? '';
    final coordinates = geometry['coordinates'] as List<dynamic>? ?? [];
    if (coordinates.isEmpty) return null;

    List<dynamic> firstRing;
    if (geoType == 'Polygon') {
      firstRing = coordinates.first as List<dynamic>;
    } else if (geoType == 'MultiPolygon') {
      firstRing = (coordinates.first as List<dynamic>).first as List<dynamic>;
    } else {
      return null;
    }

    double sumLat = 0, sumLng = 0;
    int count = 0;
    for (final coord in firstRing) {
      final c = coord as List<dynamic>;
      sumLng += (c[0] as num).toDouble();
      sumLat += (c[1] as num).toDouble();
      count++;
    }
    if (count == 0) return null;
    return LatLng(sumLat / count, sumLng / count);
  }
}

// ── Legende ───────────────────────────────────────────────────────────────────

class _MapLegend extends StatelessWidget {
  final bool isDetail;
  const _MapLegend({required this.isDetail});

  @override
  Widget build(BuildContext context) {
    final shm = context.shm;
    final scheme = Theme.of(context).colorScheme;

    final rows = isDetail
        ? [
            (shm.noQuorum, 'Keine Stimmen'),
            (shm.yesStrong, 'Mehrheit Ja'),
            (shm.noStrong, 'Mehrheit Nein'),
          ]
        : [
            for (final (i, c) in shm.participationRamp.indexed)
              (
                c,
                i == 0
                    ? 'Wenig Beteiligung'
                    : i == shm.participationRamp.length - 1
                        ? 'Hohe Beteiligung'
                        : ''
              ),
          ];

    return Container(
      padding: const EdgeInsets.all(ShmTheme.gapM),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(ShmTheme.radiusM),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isDetail ? 'Ergebnis' : 'Beteiligung',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (isDetail)
            for (final (color, label) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(label, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              )
          else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (color, _) in rows)
                  Container(width: 16, height: 12, color: color),
              ],
            ),
            const SizedBox(height: 3),
            const Text('wenig  →  viel', style: TextStyle(fontSize: 10.5)),
          ],
          const SizedBox(height: 6),
          Text(
            isDetail
                ? 'Fläche tippen: Landkreis-Details'
                : 'Fläche: Landkreise · Label: Statistik',
            style: TextStyle(
                fontSize: 10.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Landkreis-Bottom-Sheet ────────────────────────────────────────────────────

class _LandkreisBottomSheet extends StatelessWidget {
  final String nuts3;
  final String name;
  final Map<String, dynamic>? data;
  final String questionId;
  final String questionTitle;

  const _LandkreisBottomSheet({
    required this.nuts3,
    required this.name,
    required this.data,
    required this.questionId,
    required this.questionTitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasData = data != null;
    final hasQuorum = hasData && (data!['has_quorum'] as bool? ?? false);
    final totalVotes = hasData ? (data!['total_votes'] as int? ?? 0) : 0;
    final results = hasData
        ? (data!['results'] as Map<String, dynamic>? ?? <String, dynamic>{})
        : <String, dynamic>{};

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ShmTheme.gapXl, 0, ShmTheme.gapXl, ShmTheme.gapXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text('$totalVotes Stimmen',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: ShmTheme.gapL),
          if (!hasData || totalVotes == 0)
            Text('Noch keine Abstimmungsdaten für diesen Landkreis.',
                style: TextStyle(color: scheme.onSurfaceVariant))
          else if (!hasQuorum)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ShmTheme.gapM),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(ShmTheme.radiusM),
              ),
              child: Text(
                'Für diesen Landkreis liegen noch keine auswertbaren Ergebnisse vor.',
                style: TextStyle(
                    color: scheme.onTertiaryContainer, fontSize: 13),
              ),
            )
          else if (results.isNotEmpty) ...[
            DistributionBar(answers: results, total: totalVotes),
            const SizedBox(height: ShmTheme.gapM),
            AnswerLegend(answers: results, total: totalVotes),
          ],
          const SizedBox(height: ShmTheme.gapXl),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LandkreisDetailScreen(
                    landkreisId: nuts3,
                    landkreisName: name,
                    questionId: questionId,
                    questionTitle: questionTitle,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.bar_chart, size: 18),
            label: const Text('Detailstatistik ansehen'),
          ),
        ],
      ),
    );
  }
}

// ── Gesamtstatistik-Sheet (ersetzt den früheren StatsScreen) ─────────────────

class _QuestionStatsSheet extends StatelessWidget {
  final String questionTitle;
  final Map<String, Map<String, dynamic>> landkreisData;

  const _QuestionStatsSheet({
    required this.questionTitle,
    required this.landkreisData,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Gesamtverteilung nur über Landkreise mit Quorum (konsistent zur Karte).
    final totals = <String, int>{};
    int totalVotes = 0;
    final withQuorum = <Map<String, dynamic>>[];
    for (final lk in landkreisData.values) {
      totalVotes += (lk['total_votes'] as int?) ?? 0;
      if (lk['has_quorum'] != true) continue;
      withQuorum.add(lk);
      final results = lk['results'] as Map<String, dynamic>? ?? {};
      for (final e in results.entries) {
        totals[e.key] = (totals[e.key] ?? 0) + ((e.value as num?)?.toInt() ?? 0);
      }
    }
    withQuorum.sort((a, b) => ((b['total_votes'] as int?) ?? 0)
        .compareTo((a['total_votes'] as int?) ?? 0));
    final top5 = withQuorum.take(5).toList();
    final quorumVotes =
        totals.values.fold<int>(0, (sum, v) => sum + v);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
            ShmTheme.gapXl, 0, ShmTheme.gapXl, ShmTheme.gapXl),
        children: [
          Text('Gesamtstatistik',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(questionTitle,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: ShmTheme.gapXl),
          StatsHeaderCard(
            totalVotes: totalVotes,
            totalAnswers: totals,
          ),
          if (quorumVotes < totalVotes) ...[
            const SizedBox(height: ShmTheme.gapS),
            Text(
              'Verteilung basiert auf $quorumVotes auswertbaren Stimmen.',
              style: TextStyle(
                  fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: ShmTheme.gapL),
          if (top5.isNotEmpty) ...[
            Text('Top 5 Landkreise',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: ShmTheme.gapM),
            Card(
              child: Column(
                children: [
                  for (final (i, lk) in top5.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: Text(
                        '#${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: i == 0
                              ? const Color(0xFFC9A227)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        (lk['landkreis_name'] as String?) ??
                            (lk['landkreis_id'] as String? ?? '–'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(
                        '${lk['total_votes']} Stimmen',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
