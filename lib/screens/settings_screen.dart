import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../water/units.dart';
import '../water/water_store.dart';
import 'settings/cups_section.dart';
import 'settings/goal_section.dart';
import 'settings/reminder_section.dart';

/// Goal, units, cups and reminders, then Updates and Developer.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final WaterStore store;

  @override
  Widget build(BuildContext context) {
    return UiScaffold(
      appBar: const UiAppBar(title: 'Settings'),
      scrollable: true,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.settings;
          return UiColumn(
            gap: UiSpace.lg,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GoalSection(store: store),
              UiSection(
                title: 'Units',
                child: UiSegmentedControl<VolumeUnit>(
                  [for (final u in VolumeUnit.values) UiSegment(u, label: u.label)],
                  value: s.unit,
                  expand: true,
                  onChanged: (u) => store.update((c) => c.copyWith(unit: u)),
                ),
              ),
              CupsSection(store: store),
              ReminderSection(store: store),
              const UiUpdateSection(storeId: 'hydra'),
              const UiDeveloperSection(),
            ],
          );
        },
      ),
    );
  }
}
