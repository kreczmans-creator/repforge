import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/ui/theme.dart';

/// Root widget. Wrap in a `ProviderScope` (see `main.dart`).
class RepForgeApp extends ConsumerStatefulWidget {
  const RepForgeApp({super.key, this.router});

  /// Optional router override for tests.
  final GoRouter? router;

  @override
  ConsumerState<RepForgeApp> createState() => _RepForgeAppState();
}

class _RepForgeAppState extends ConsumerState<RepForgeApp> {
  late final GoRouter _router = widget.router ?? createRouter();

  @override
  void dispose() {
    // Only dispose a router this state created; an injected one belongs to
    // the caller.
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dark is the product's default state (owner direction, 2026-11-03);
    // the persisted theme preference can switch it.
    final pref =
        ref.watch(settingsProvider.select((s) => s.value?.theme)) ??
        ThemePreference.dark;
    return MaterialApp.router(
      title: 'RepForge',
      debugShowCheckedModeBanner: false,
      theme: rfTheme(Brightness.light),
      darkTheme: rfTheme(Brightness.dark),
      themeMode: switch (pref) {
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.system => ThemeMode.system,
      },
      routerConfig: _router,
    );
  }
}
