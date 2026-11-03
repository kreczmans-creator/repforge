import 'package:flutter/material.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/ui/tokens.dart';

/// Small label stating where a nutrient value came from (GEN provenance).
class ProvenanceBadge extends StatelessWidget {
  const ProvenanceBadge(this.provenance, {super.key});

  final DataProvenance provenance;

  static String label(DataProvenance p) => switch (p) {
    DataProvenance.verified => 'Verified',
    DataProvenance.userEntered => 'Your entry',
    DataProvenance.estimated => 'Estimate',
    DataProvenance.crowdsourced => 'Community data',
  };

  @override
  Widget build(BuildContext context) {
    final rf = context.rf;
    final color = switch (provenance) {
      DataProvenance.verified => rf.successText,
      DataProvenance.userEntered => rf.textSecondary,
      DataProvenance.estimated => rf.accentText,
      DataProvenance.crowdsourced => rf.infoText,
    };
    return Semantics(
      label: 'Data source: ${label(provenance)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(RfRadius.xs),
        ),
        child: Text(
          label(provenance),
          style: context.rfText.meta.copyWith(color: color, letterSpacing: 0),
        ),
      ),
    );
  }
}
