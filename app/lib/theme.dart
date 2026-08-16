import 'package:flutter/material.dart';

/// Zentrales Design-System von SocialHeadmap.
///
/// Alle Farben, Radien und Textstile kommen von hier — Screens greifen nie
/// direkt auf Hex-Werte zu. Light und Dark Mode werden beide unterstützt;
/// semantische Farben (Ja/Nein, Karte, Kategorien) liegen in [ShmColors]
/// als ThemeExtension und passen sich dem Modus an.
class ShmTheme {
  ShmTheme._();

  // ── Marken-Basisfarben ────────────────────────────────────────────────────
  static const Color seed = Color(0xFF1565C0); // Deutschland-Blau

  // ── Radien & Abstände ─────────────────────────────────────────────────────
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXl = 24;

  static const double gapXs = 4;
  static const double gapS = 8;
  static const double gapM = 12;
  static const double gapL = 16;
  static const double gapXl = 24;

  // ── Kategorie-Farben (konstant in beiden Modi, ausreichend Kontrast) ─────
  static const Map<String, Color> _categoryColors = {
    'politik': Color(0xFF1565C0),
    'gesellschaft': Color(0xFF2E7D32),
    'bildung': Color(0xFFB45309),
    'wirtschaft': Color(0xFF6D28D9),
    'umwelt': Color(0xFF0F766E),
    'gesundheit': Color(0xFFBE185D),
  };

  static Color categoryColor(String category) =>
      _categoryColors[category.toLowerCase()] ?? const Color(0xFF546E7A);

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;

    final textTheme = Typography.material2021(platform: TargetPlatform.iOS)
        .black
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        )
        .copyWith(
          // Lesbare Mindestgrößen — nichts unter 11pt.
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: scheme.onSurfaceVariant,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: scheme.onSurface,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? scheme.surface : const Color(0xFFF6F7FA),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? scheme.surface : const Color(0xFFF6F7FA),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 18),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
          side: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusM)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusM)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusM)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withOpacity(isDark ? 0.4 : 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        height: 68,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusXl)),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.6),
        thickness: 1,
      ),
      extensions: [ShmColors._forBrightness(brightness)],
    );
  }
}

/// Semantische Farben, die es in Material nicht gibt (Ja/Nein, Kartenrampen).
/// Über `Theme.of(context).extension<ShmColors>()!` bzw. [ShmColorsX] abrufbar.
class ShmColors extends ThemeExtension<ShmColors> {
  final Color yes;
  final Color no;
  final Color onYes;
  final Color onNo;
  final Color yesContainer;
  final Color noContainer;
  final Color noQuorum;

  /// Beteiligungs-Rampe für die Bundesland-Übersicht (hell → dunkel).
  final List<Color> participationRamp;

  /// Endpunkte für Ja-/Nein-Einfärbung der Landkreise.
  final Color yesWeak;
  final Color yesStrong;
  final Color noWeak;
  final Color noStrong;

  const ShmColors({
    required this.yes,
    required this.no,
    required this.onYes,
    required this.onNo,
    required this.yesContainer,
    required this.noContainer,
    required this.noQuorum,
    required this.participationRamp,
    required this.yesWeak,
    required this.yesStrong,
    required this.noWeak,
    required this.noStrong,
  });

  factory ShmColors._forBrightness(Brightness b) {
    final isDark = b == Brightness.dark;
    return ShmColors(
      yes: isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
      no: isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828),
      onYes: Colors.white,
      onNo: Colors.white,
      yesContainer:
          isDark ? const Color(0xFF1B3A1E) : const Color(0xFFDCFCE7),
      noContainer: isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEE2E2),
      noQuorum: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFDDDDDD),
      participationRamp: isDark
          ? const [
              Color(0xFF1E2A3A),
              Color(0xFF23405E),
              Color(0xFF2C5A88),
              Color(0xFF3E7AB5),
              Color(0xFF6FA8DC),
            ]
          : const [
              Color(0xFFDEECF8),
              Color(0xFF9BBFE8),
              Color(0xFF5490C8),
              Color(0xFF2163A8),
              Color(0xFF0D3D7A),
            ],
      yesWeak: isDark ? const Color(0xFF2E5231) : const Color(0xFFC8E6C9),
      yesStrong: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
      noWeak: isDark ? const Color(0xFF5A2A2A) : const Color(0xFFFFCDD2),
      noStrong: isDark ? const Color(0xFFE57373) : const Color(0xFFC62828),
    );
  }

  @override
  ShmColors copyWith({
    Color? yes,
    Color? no,
    Color? onYes,
    Color? onNo,
    Color? yesContainer,
    Color? noContainer,
    Color? noQuorum,
    List<Color>? participationRamp,
    Color? yesWeak,
    Color? yesStrong,
    Color? noWeak,
    Color? noStrong,
  }) {
    return ShmColors(
      yes: yes ?? this.yes,
      no: no ?? this.no,
      onYes: onYes ?? this.onYes,
      onNo: onNo ?? this.onNo,
      yesContainer: yesContainer ?? this.yesContainer,
      noContainer: noContainer ?? this.noContainer,
      noQuorum: noQuorum ?? this.noQuorum,
      participationRamp: participationRamp ?? this.participationRamp,
      yesWeak: yesWeak ?? this.yesWeak,
      yesStrong: yesStrong ?? this.yesStrong,
      noWeak: noWeak ?? this.noWeak,
      noStrong: noStrong ?? this.noStrong,
    );
  }

  @override
  ShmColors lerp(ThemeExtension<ShmColors>? other, double t) {
    if (other is! ShmColors) return this;
    return ShmColors(
      yes: Color.lerp(yes, other.yes, t)!,
      no: Color.lerp(no, other.no, t)!,
      onYes: Color.lerp(onYes, other.onYes, t)!,
      onNo: Color.lerp(onNo, other.onNo, t)!,
      yesContainer: Color.lerp(yesContainer, other.yesContainer, t)!,
      noContainer: Color.lerp(noContainer, other.noContainer, t)!,
      noQuorum: Color.lerp(noQuorum, other.noQuorum, t)!,
      participationRamp: t < 0.5 ? participationRamp : other.participationRamp,
      yesWeak: Color.lerp(yesWeak, other.yesWeak, t)!,
      yesStrong: Color.lerp(yesStrong, other.yesStrong, t)!,
      noWeak: Color.lerp(noWeak, other.noWeak, t)!,
      noStrong: Color.lerp(noStrong, other.noStrong, t)!,
    );
  }
}

extension ShmColorsX on BuildContext {
  ShmColors get shm => Theme.of(this).extension<ShmColors>()!;
}
