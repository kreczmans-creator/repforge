import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// 36 px amber-tinted icon tile from the brand mock-up (activity rows, empty
/// states). One definition so size, tint and radius cannot drift.
class RfIconTile extends StatelessWidget {
  const RfIconTile({required this.icon, super.key});

  static const double size = 36;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final rf = context.rf;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: rf.accentSubtle,
        borderRadius: BorderRadius.circular(RfRadius.sm),
      ),
      child: Icon(icon, size: RfIcon.sm, color: rf.accent),
    );
  }
}
