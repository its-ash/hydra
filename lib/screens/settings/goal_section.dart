import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../../water/settings.dart';
import '../../water/water_store.dart';

/// Daily goal: computed from body weight, activity and weather, or set by hand.
class GoalSection extends StatelessWidget {
  const GoalSection({super.key, required this.store});

  final WaterStore store;

  @override
  Widget build(BuildContext context) {
    final s = store.settings;
    final unit = s.unit;
    return UiColumn(
      gap: UiSpace.md,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiListGroup(
          header: 'Daily goal',
          footer: s.goalAuto
              ? 'About ${s.mlPerKg} ml per kg of body weight, plus activity and hot weather.'
              : 'Your own target.',
          children: [
            UiSwitchTile(
              'Calculate from my body',
              icon: Icons.calculate_rounded,
              value: s.goalAuto,
              onChanged: (v) => store.update((c) => c.copyWith(goalAuto: v)),
            ),
            UiListTile('Goal', icon: Icons.flag_rounded, iconStatus: UiStatus.info, value: unit.format(s.goalMl)),
          ],
        ),
        if (s.goalAuto) ...[
          UiNumberField<int>(
            label: 'Weight (kg)',
            value: s.weightKg,
            min: 30,
            max: 250,
            onChanged: (v) => store.update((c) => c.copyWith(weightKg: v)),
          ),
          UiNumberField<int>(
            label: 'Water per kg (ml)',
            helper: 'Common advice is 30 to 35 ml.',
            value: s.mlPerKg,
            min: 20,
            max: 50,
            onChanged: (v) => store.update((c) => c.copyWith(mlPerKg: v)),
          ),
          UiFieldLabel(
            label: 'Activity',
            helper: s.activity.hint,
            child: UiSegmentedControl<ActivityLevel>(
              [for (final a in ActivityLevel.values) UiSegment(a, label: a.label)],
              value: s.activity,
              expand: true,
              onChanged: (a) => store.update((c) => c.copyWith(activity: a)),
            ),
          ),
          UiListGroup(
            children: [
              UiSwitchTile(
                'Hot weather',
                subtitle: 'Adds ${unit.format(GoalCalculator.hotWeatherExtraMl)} to the goal.',
                icon: Icons.wb_sunny_rounded,
                status: UiStatus.warning,
                value: s.hot,
                onChanged: (v) => store.update((c) => c.copyWith(hot: v)),
              ),
            ],
          ),
        ] else
          UiNumberField<int>(
            label: 'Daily goal (${unit.label})',
            value: unit.fromMl(s.manualGoalMl),
            step: unit.goalStep,
            min: unit.fromMl(500),
            max: unit.fromMl(8000),
            onChanged: (v) => store.update((c) => c.copyWith(manualGoalMl: unit.toMl(v))),
          ),
      ],
    );
  }
}
