import 'package:flutter/material.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Tab content for a pillar whose features are not built yet. Shows only a
/// clearly labelled "not yet available" card (engineering standard §10).
class PillarPlaceholderScreen extends StatelessWidget {
  const PillarPlaceholderScreen({
    required this.title,
    required this.caption,
    required this.feature,
    required this.workPackage,
    super.key,
  });

  final String title;
  final String caption;
  final String feature;
  final String workPackage;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
    children: [
      RfScreenTitle(title: title, caption: caption),
      RfNotYetAvailable(feature: feature, workPackage: workPackage),
    ],
  );
}
