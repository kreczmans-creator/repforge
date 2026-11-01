import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/ui/theme.dart';

/// Root widget. Wrap in a `ProviderScope` (see `main.dart`).
class RepForgeApp extends StatefulWidget {
  const RepForgeApp({super.key, this.router});

  /// Optional router override for tests.
  final GoRouter? router;

  @override
  State<RepForgeApp> createState() => _RepForgeAppState();
}

class _RepForgeAppState extends State<RepForgeApp> {
  late final GoRouter _router = widget.router ?? createRouter();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'RepForge',
    debugShowCheckedModeBanner: false,
    theme: rfTheme(Brightness.light),
    darkTheme: rfTheme(Brightness.dark),
    routerConfig: _router,
  );
}
