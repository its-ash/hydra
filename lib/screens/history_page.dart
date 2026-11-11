import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../water/stats.dart';
import '../water/water_store.dart';

/// Bar chart of the last 7 or 30 days against the goal, plus averages and streaks.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.store});

  final WaterStore store;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  int _days = 7;

  String _label(DateTime day) => _days == 7 ? _weekdays[day.weekday - 1] : '${day.day}';

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final unit = store.settings.unit;
    final goal = store.goalMl;
    final stats = store.stats;
    final totals = stats.lastDays(_days);
    final colors = context.colors;
    final metCount = totals.where((d) => d.metGoal(goal)).length;
    final best = stats.bestStreak(goal);
    final current = stats.currentStreak(goal);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: UiSpace.lg, bottom: UiSpace.xxl),
      child: UiContent(
        child: UiColumn(
          gap: UiSpace.xl,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiSegmentedControl<int>(
              const [UiSegment(7, label: '7 days'), UiSegment(30, label: '30 days')],
              value: _days,
              expand: true,
              onChanged: (v) => setState(() => _days = v),
            ),
            UiSection(
              title: 'Water per day',
              subtitle: 'Goal: ${unit.format(goal)}',
              child: UiColumn(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UiBarChart(
                    bars: [
                      for (final DayTotal d in totals)
                        UiBarData(_label(d.day), unit.fromMl(d.ml), color: d.metGoal(goal) ? colors.success : colors.accent),
                    ],
                    height: 220,
                    yFormat: (v) => '${v.round()}',
                  ),
                  UiChartLegend([
                    UiLegendItem('Goal met', color: colors.success),
                    UiLegendItem('Below goal', color: colors.accent),
                  ]),
                ],
              ),
            ),
            UiResponsiveGrid(
              minItemWidth: 150,
              children: [
                UiStatCard(
                  label: 'Average per day',
                  value: unit.format(stats.averageMl(_days)),
                  icon: Icons.show_chart_rounded,
                  iconStatus: UiStatus.info,
                ),
                UiStatCard(
                  label: 'Goal met',
                  value: '$metCount of $_days days',
                  icon: Icons.check_circle_rounded,
                  iconStatus: UiStatus.success,
                ),
                UiStatCard(
                  label: 'Best streak',
                  value: best == 1 ? '1 day' : '$best days',
                  icon: Icons.emoji_events_rounded,
                  iconStatus: UiStatus.warning,
                ),
                UiStatCard(
                  label: 'Current streak',
                  value: current == 1 ? '1 day' : '$current days',
                  icon: Icons.local_fire_department_rounded,
                  iconStatus: UiStatus.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
