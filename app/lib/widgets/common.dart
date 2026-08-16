import 'package:flutter/material.dart';
import '../constants.dart';
import '../theme.dart';

/// Vollflächige Fehleransicht mit Retry-Button.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: ShmTheme.gapL),
            Text(
              errorMessage(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: ShmTheme.gapXl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vollflächiger Leer-Zustand mit Icon, Titel und optionalem Untertitel.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState(
      {super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outlineVariant),
            const SizedBox(height: ShmTheme.gapL),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: ShmTheme.gapS),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Abschnitts-Überschrift in Versalien (Profil, Listen).
class SectionHeader extends StatelessWidget {
  final String text;
  const SectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ShmTheme.gapS, left: 2),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Farbiges Kategorie-Badge (einheitlich für Feed, Sheet, Listen).
class CategoryBadge extends StatelessWidget {
  final String category;
  const CategoryBadge(this.category, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = ShmTheme.categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(
            Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(ShmTheme.radiusXl),
      ),
      child: Text(
        category.isNotEmpty ? category : 'Allgemein',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).brightness == Brightness.dark
              ? Color.lerp(color, Colors.white, 0.45)
              : color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Zeigt eine Snackbar mit semantischer Farbe.
void showShmSnack(BuildContext context, String message,
    {bool success = false, bool error = false}) {
  final shm = context.shm;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: success
          ? shm.yes
          : error
              ? shm.no
              : null,
      duration: const Duration(seconds: 3),
    ),
  );
}
