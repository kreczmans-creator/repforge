import 'package:flutter/material.dart';
import 'package:repforge/ui/components/rf_brand_mark.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_list_tile.dart';
import 'package:repforge/ui/components/rf_macro_bar.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_stat_tile.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';
import 'package:repforge/ui/tokens.dart';

/// Debug-only catalogue of every design-system component in the current
/// theme. Golden tests render this screen in light and dark.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  static final _sample = [
    RfTrendPoint(DateTime(2026, 10), 88.2),
    RfTrendPoint(DateTime(2026, 10, 8), 87.6),
    RfTrendPoint(DateTime(2026, 10, 15), 87.9),
    RfTrendPoint(DateTime(2026, 10, 29), 86.8),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rf = context.rf;
    final rfText = context.rfText;
    return Scaffold(
      appBar: AppBar(title: const Text('Component gallery')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Design system',
            caption: 'RepForge v1.0 · every component, current theme',
          ),
          const RfSectionHeader(title: 'Brand'),
          const RfCard(child: RfBrandMark(height: 32)),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Typography'),
          RfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display 40', style: theme.textTheme.displaySmall),
                Text('H1 Good morning', style: theme.textTheme.headlineLarge),
                Text('H2 Upper Body', style: theme.textTheme.headlineMedium),
                Text(
                  'H3 Nutrition today',
                  style: theme.textTheme.headlineSmall,
                ),
                Text('H4 Bodyweight goal', style: theme.textTheme.titleMedium),
                Text(
                  'Body: keep rest periods consistent.',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'Body small: product data is crowdsourced.',
                  style: theme.textTheme.bodySmall,
                ),
                Text('LABEL · WORKOUTS THIS WEEK', style: rfText.kicker),
                Text('1,180 kcal', style: rfText.dataXl),
                Text('86.8 kg', style: rfText.dataL),
                Text('4 × 8 @ 92.5 kg', style: rfText.dataM),
                Text('142 / 200 g', style: rfText.dataS),
                Text('2026-11-02 07:41 · SYNCED', style: rfText.meta),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Colour'),
          RfCard(
            child: Wrap(
              spacing: RfSpace.s2,
              runSpacing: RfSpace.s2,
              children: [
                _Swatch('Accent', rf.accent),
                _Swatch('Accent text', rf.accentText),
                _Swatch('Surface 1', rf.surface1),
                _Swatch('Surface 2', rf.surface2),
                _Swatch('Surface 3', rf.surface3),
                _Swatch('Elevated', rf.elevated),
                _Swatch('Border', rf.border),
                _Swatch('Secondary', rf.textSecondary),
                _Swatch('Muted', rf.textMuted),
                _Swatch('Success', rf.success),
                _Swatch('Info', rf.info),
                _Swatch('Alert', rf.alert),
                _Swatch('Focus', rf.focus),
                _Swatch('Success text', rf.successText),
                _Swatch('Info text', rf.infoText),
                _Swatch('Alert text', rf.alertText),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Buttons'),
          RfCard(
            child: Column(
              children: [
                RfButton(
                  label: 'Start workout',
                  icon: Icons.play_arrow,
                  onPressed: () {},
                ),
                const SizedBox(height: RfSpace.s2),
                RfButton(
                  label: 'Secondary',
                  variant: RfButtonVariant.secondary,
                  onPressed: () {},
                ),
                const SizedBox(height: RfSpace.s2),
                RfButton(
                  label: 'Tertiary',
                  variant: RfButtonVariant.tertiary,
                  onPressed: () {},
                ),
                const SizedBox(height: RfSpace.s2),
                RfButton(
                  label: 'Delete',
                  variant: RfButtonVariant.danger,
                  onPressed: () {},
                ),
                const SizedBox(height: RfSpace.s2),
                const RfButton(label: 'Saving', loading: true, onPressed: null),
                const SizedBox(height: RfSpace.s2),
                const RfButton(label: 'Disabled', onPressed: null),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Inputs'),
          RfCard(
            child: Column(
              children: [
                RfTextField.number(label: 'Weight', unit: 'kg', hint: '82.4'),
                const SizedBox(height: RfSpace.s3),
                RfTextField.integer(label: 'Reps'),
                const SizedBox(height: RfSpace.s3),
                const RfTextField(
                  label: 'Note',
                  errorText: 'Example validation message',
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Stats and progress'),
          const Row(
            children: [
              Expanded(
                child: RfStatTile(
                  label: 'Calories left',
                  value: '1,180',
                  unit: 'kcal',
                  progress: 0.55,
                  caption: '1,420 of 2,600',
                ),
              ),
              SizedBox(width: RfSpace.s3),
              Expanded(
                child: RfStatTile(
                  label: 'Protein',
                  value: '142',
                  unit: 'g',
                  progress: 0.71,
                  caption: 'of 200 g',
                ),
              ),
            ],
          ),
          const SizedBox(height: RfSpace.s3),
          RfCard(
            child: Column(
              children: [
                const RfMacroBar(label: 'Protein', amount: 142, target: 200),
                RfMacroBar(
                  label: 'Carbs',
                  amount: 188,
                  target: 280,
                  color: rf.textSecondary,
                ),
                RfMacroBar(
                  label: 'Fat',
                  amount: 54,
                  target: 80,
                  color: rf.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Trend chart'),
          RfCard(
            child: RfTrendChart(
              unit: 'kg',
              series: [RfTrendSeries(label: 'Weight', points: _sample)],
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Lists'),
          RfCard(
            padding: const EdgeInsets.symmetric(
              horizontal: RfSpace.s4,
              vertical: RfSpace.s1,
            ),
            child: Column(
              children: [
                RfListTile(
                  icon: Icons.fitness_center,
                  title: 'Lower Body Strength',
                  subtitle: 'Yesterday · 52 min · 12,400 kg volume',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const RfListTile(
                  icon: Icons.monitor_weight_outlined,
                  title: 'Weigh-in',
                  subtitle: 'Today · 86.8 kg',
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'States'),
          const RfEmptyState(message: 'Nothing logged yet.'),
          const SizedBox(height: RfSpace.s3),
          const RfLoading(),
          RfErrorState(message: 'Could not load data.', onRetry: () {}),
          const SizedBox(height: RfSpace.s3),
          const RfNotYetAvailable(
            feature: 'Example feature',
            workPackage: 'WP n',
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 56,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(RfRadius.xs),
          border: Border.all(color: context.rf.border),
        ),
      ),
      const SizedBox(height: RfSpace.s1),
      Text(label, style: context.rfText.meta),
    ],
  );
}
