import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'bundesland_stats_screen.dart';
import 'landkreis_detail_screen.dart';

const String _baseUrl = 'https://shm.13-61-179-136.nip.io';

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
  bool _loading = true;
  String? _error;

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
      await Future.wait([_loadGeoJson(), _loadSnapshot(), _loadBundeslandData()]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
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
    final response = await http
        .get(Uri.parse('$_baseUrl/stats/geojson/landkreise'))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('GeoJSON-Fehler: HTTP ${response.statusCode}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    _cachedGeoJson = data;
    if (mounted) setState(() => _geoJson = data);
  }

  Future<void> _loadSnapshot() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/stats/map/${widget.questionId}'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Snapshot-Fehler: HTTP ${response.statusCode}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
      final response = await http
          .get(Uri.parse('$_baseUrl/stats/map/${widget.questionId}/bundeslaender'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return;
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final bls = (data['bundeslaender'] as List<dynamic>?) ?? [];
      final map = <String, int>{};
      for (final bl in bls) {
        final m = bl as Map<String, dynamic>;
        map[m['name'] as String] = m['total_votes'] as int;
      }
      if (mounted) setState(() => _bundeslandVotes = map);
    } catch (_) {}
  }

  void _selectBundesland(String blName) {
    setState(() => _selectedBundesland = blName);
    final bounds = _computeBundeslandBounds(blName);
    if (bounds != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(50),
            ),
          );
        }
      });
    }
  }

  void _backToOverview() {
    setState(() => _selectedBundesland = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(_germanyCenter, _germanyZoom);
      }
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

    void processRing(List<dynamic> ring) {
      for (final c in ring) processCoord(c);
    }

    void processPoly(List<dynamic> poly) {
      if (poly.isNotEmpty) processRing(poly[0] as List<dynamic>);
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
        for (final poly in coords) processPoly(poly as List<dynamic>);
      }
    }

    if (minLat == null) return null;
    return LatLngBounds(LatLng(minLat!, minLng!), LatLng(maxLat!, maxLng!));
  }

  Color _colorForOverview(String bundesland) {
    final votes = _bundeslandVotes[bundesland] ?? 0;
    if (votes == 0) return const Color(0xFFF0F5FA);

    // Rang-basierte Einfärbung: sortiere alle BL mit Stimmen, Position = Helligkeit
    final ranked = _bundeslandVotes.entries
        .where((e) => e.value > 0)
        .map((e) => e.value)
        .toList()
      ..sort();

    int rank = 0;
    for (final v in ranked) {
      if (v < votes) rank++;
    }

    final n = ranked.length;
    final t = n <= 1 ? 1.0 : rank / (n - 1);

    // 5 Stufen: weiß → hellblau → mittelblau → blau → dunkelblau
    const steps = [
      Color(0xFFDEECF8),
      Color(0xFF9BBFE8),
      Color(0xFF5490C8),
      Color(0xFF2163A8),
      Color(0xFF0D3D7A),
    ];
    final stepIdx = n <= 1 ? 4 : (t * (steps.length - 1)).round().clamp(0, steps.length - 1);
    return steps[stepIdx];
  }

  Color _colorForLandkreis(String nuts3) {
    if (_landkreisData == null) return const Color(0xFFF2F2F2);
    final lk = _landkreisData![nuts3];
    if (lk == null) return const Color(0xFFEEEEEE);
    final hasQuorum = lk['has_quorum'] as bool? ?? false;
    if (!hasQuorum) return const Color(0xFFDDDDDD);
    final results = lk['results'] as Map<String, dynamic>? ?? {};
    if (results.isEmpty) return const Color(0xFFDDDDDD);

    final ja = (results['ja'] as num?)?.toDouble() ?? 0;
    final nein = (results['nein'] as num?)?.toDouble() ?? 0;
    if (ja > 0 || nein > 0) {
      if (ja >= nein) {
        final t = ((ja / (ja + nein)) - 0.5).clamp(0.0, 0.5) / 0.5;
        return Color.lerp(const Color(0xFFC8E6C9), const Color(0xFF2E7D32), t)!;
      } else {
        final t = ((nein / (ja + nein)) - 0.5).clamp(0.0, 0.5) / 0.5;
        return Color.lerp(const Color(0xFFFFCDD2), const Color(0xFFC62828), t)!;
      }
    }

    double total = 0, weightedSum = 0;
    for (int i = 1; i <= 5; i++) {
      final v = (results[i.toString()] as num?)?.toDouble() ?? 0;
      total += v;
      weightedSum += v * i;
    }
    if (total > 0) {
      final t = ((weightedSum / total) - 1) / 4;
      return Color.lerp(const Color(0xFF42A5F5), const Color(0xFFFF8F00), t)!;
    }

    const palette = [
      Color(0xFF5C85D6),
      Color(0xFF66BB6A),
      Color(0xFFFFB347),
      Color(0xFFBA68C8),
    ];
    final keys = results.keys.toList();
    String? winner;
    double maxV = 0;
    results.forEach((k, v) {
      final n = (v as num?)?.toDouble() ?? 0;
      if (n > maxV) {
        maxV = n;
        winner = k;
      }
    });
    if (winner != null) return palette[keys.indexOf(winner!) % palette.length];
    return const Color(0xFFDDDDDD);
  }

  void _onLandkreisTap(BuildContext context, String nuts3, String name) {
    final lk = _landkreisData?[nuts3];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _LandkreisBottomSheet(
        nuts3: nuts3,
        name: name,
        data: lk,
        questionId: widget.questionId,
        questionTitle: widget.questionTitle,
      ),
    );
  }

  void _toggleLive() {
    if (_liveActive) {
      _stopLive();
    } else {
      _startLive();
    }
  }

  void _startLive() {
    setState(() => _liveActive = true);
    _liveTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final response = await http
            .get(Uri.parse('$_baseUrl/stats/map/${widget.questionId}/live'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final dataLine = utf8.decode(response.bodyBytes)
              .split('\n')
              .firstWhere((l) => l.startsWith('data:'), orElse: () => '');
          if (dataLine.isNotEmpty) {
            final json =
                jsonDecode(dataLine.substring(5).trim()) as Map<String, dynamic>;
            final totalVotes = json['total_votes'] as int? ?? 0;
            if (mounted && totalVotes != _liveTotalVotes) {
              _liveTotalVotes = totalVotes;
              await _loadSnapshot();
              await _loadBundeslandData();
            }
          }
        }
      } catch (_) {}
    });
  }

  void _stopLive() {
    _liveTimer?.cancel();
    _liveTimer = null;
    setState(() => _liveActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.questionTitle),
        actions: [
          if (_liveActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.circle, color: Colors.red.shade400, size: 10),
                  const SizedBox(width: 4),
                  const Text('Live', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _toggleLive,
              icon: Icon(_liveActive ? Icons.stop : Icons.stream),
              label: Text(_liveActive ? 'Live stoppen' : 'Live'),
              backgroundColor: _liveActive ? Colors.red.shade400 : null,
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Fehler beim Laden der Karte',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }
    if (_geoJson == null) {
      return const Center(child: Text('Keine Kartendaten verfügbar'));
    }
    return _buildMap();
  }

  Widget _buildMap() {
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

      final color = isDetail ? _colorForLandkreis(nuts3) : _colorForOverview(bl);
      final borderWidth = isDetail ? 1.0 : 0.4;
      final borderColor =
          isDetail ? const Color(0xFF3A3A3A) : const Color(0xFF6A8FAF);

      if (geoType == 'Polygon') {
        final rings =
            coordinates.map((r) => _toLatLngs(r as List<dynamic>)).toList();
        if (rings.isNotEmpty) {
          polygons.add(Polygon(
            points: rings.first,
            holePointsList: rings.length > 1 ? rings.sublist(1) : [],
            color: color,
            borderColor: borderColor,
            borderStrokeWidth: borderWidth,
          ));
        }
      } else if (geoType == 'MultiPolygon') {
        for (final poly in coordinates) {
          final polyRings =
              (poly as List<dynamic>).map((r) => _toLatLngs(r as List<dynamic>)).toList();
          if (polyRings.isNotEmpty) {
            polygons.add(Polygon(
              points: polyRings.first,
              holePointsList: polyRings.length > 1 ? polyRings.sublist(1) : [],
              color: color,
              borderColor: borderColor,
              borderStrokeWidth: borderWidth,
            ));
          }
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
                ? () => _onLandkreisTap(context, nuts3, name)
                : () => _selectBundesland(bl),
            child: const ColoredBox(color: Colors.transparent),
          ),
        ));
      }
    }

    // Bundesland-Labels in der Übersicht — tippbar → Statistik-Screen
    final labelMarkers = <Marker>[];
    if (!isDetail) {
      for (final entry in blCentroids.entries) {
        final blName = entry.key;
        final pts = entry.value;
        final avgLat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
        final avgLng = pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.4), width: 1),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    blName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D2D52),
                      height: 1.2,
                    ),
                  ),
                  if (votes > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bar_chart, size: 9, color: Color(0xFF1565C0)),
                        const SizedBox(width: 2),
                        Text(
                          '$votes',
                          style: const TextStyle(
                            fontSize: 8,
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFDDE8F0), Color(0xFFCDD8E4)],
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
                  InteractiveFlag.doubleTapZoom,
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
        // Zurück-Button im Detail-Modus
        if (isDetail)
          Positioned(
            top: 12,
            left: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _backToOverview,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 18),
                      SizedBox(width: 6),
                      Text('Übersicht', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Bundesland-Titel im Detail-Modus
        if (isDetail)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
                child: Text(
                  _selectedBundesland!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        // Legende
        Positioned(
          bottom: 80,
          right: 12,
          child: _buildLegend(isDetail),
        ),
      ],
    );
  }

  Widget _buildLegend(bool isDetail) {
    if (isDetail) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Ergebnis', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            _LegendRow(color: Color(0xFFDDDDDD), label: '< 10 Stimmen'),
            _LegendRow(color: Color(0xFF2E7D32), label: 'Ja (stark)'),
            _LegendRow(color: Color(0xFFC62828), label: 'Nein (stark)'),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('Beteiligung (Rang)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          _LegendRow(color: Color(0xFFF0F5FA), label: 'Keine Stimmen'),
          _LegendRow(color: Color(0xFFDEECF8), label: 'Rang 1 (wenigste)'),
          _LegendRow(color: Color(0xFF9BBFE8), label: 'Rang 2'),
          _LegendRow(color: Color(0xFF5490C8), label: 'Rang 3'),
          _LegendRow(color: Color(0xFF2163A8), label: 'Rang 4'),
          _LegendRow(color: Color(0xFF0D3D7A), label: 'Rang 5 (meiste)'),
          SizedBox(height: 4),
          Text('Chip-Tippen = Statistik', style: TextStyle(fontSize: 8, color: Colors.grey)),
          Text('Fläche-Tippen = Landkreise', style: TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
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

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }
}

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
    final hasData = data != null;
    final hasQuorum = hasData && (data!['has_quorum'] as bool? ?? false);
    final totalVotes = hasData ? (data!['total_votes'] as int? ?? 0) : 0;
    final results =
        hasData ? (data!['results'] as Map<String, dynamic>? ?? {}) : {};

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          Text(nuts3,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 16),
          if (!hasData) ...[
            const Text('Keine Abstimmungsdaten vorhanden.'),
          ] else ...[
            _InfoRow(label: 'Gesamtstimmen', value: totalVotes.toString()),
            const SizedBox(height: 8),
            if (!hasQuorum)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'Kein Quorum erreicht – Ergebnisse nicht sichtbar',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            if (hasQuorum && results.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Ergebnisse', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...results.entries.map((e) {
                final votes = (e.value as num?)?.toInt() ?? 0;
                final pct = totalVotes > 0 ? votes / totalVotes : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key.toUpperCase()),
                          Text('$votes Stimmen (${(pct * 100).round()}%)'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.grey.shade200,
                        color: e.key == 'ja'
                            ? Colors.green
                            : e.key == 'nein'
                                ? Colors.red
                                : Colors.blue,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
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
              icon: const Icon(Icons.bar_chart, size: 16),
              label: const Text('Detailstatistik ansehen'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
