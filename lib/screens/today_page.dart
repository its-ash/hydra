import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../water/units.dart';
import '../water/water_log.dart';
import '../water/water_store.dart';

/// Progress ring, quick-add cups, streak and today's log.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.store});

  final WaterStore store;

  VolumeUnit get unit => store.settings.unit;

  Future<void> _add(BuildContext context, int ml) async {
    final wasReached = store.goalReached;
    final log = await store.add(ml);
    if (log == null || !context.mounted) return;
    if (!wasReached && store.goalReached) {
      context.showToast('Daily goal reached. Well done!', status: UiStatus.success);
    } else {
      context.showToast(
        'Added ${unit.format(ml)}',
        actionLabel: 'Undo',
        onAction: () => store.remove(log),
      );
    }
  }

  Future<void> _addCustom(BuildContext context) async {
    final text = await UiDialog.prompt(
      context,
      title: 'Add water',
      label: 'Amount (${unit.label})',
      hint: unit == VolumeUnit.ml ? '330' : '12',
      confirmLabel: 'Add',
      keyboardType: TextInputType.number,
      validator: (v) {
        final n = int.tryParse(v.trim());
        return n == null || n <= 0 ? 'Enter a number above 0.' : null;
      },
    );
    final amount = int.tryParse((text ?? '').trim());
    if (amount == null || !context.mounted) return;
    await _add(context, unit.toMl(amount));
  }

  Future<void> _remove(BuildContext context, WaterLog log) async {
    await store.remove(log);
    if (!context.mounted) return;
    context.showToast('Removed ${unit.format(log.ml)}', actionLabel: 'Undo', onAction: () => store.restore(log));
  }

  @override
  Widget build(BuildContext context) {
    final stats = store.stats;
    final streak = stats.currentStreak(store.goalMl);
    final left = store.goalMl - store.todayMl;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: UiSpace.lg, bottom: UiSpace.xxl),
      child: UiContent(
        child: UiColumn(
          gap: UiSpace.xl,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (store.remindersBlocked)
              UiAlert(
                'Reminders are on, but notifications are blocked for Hydra.',
                status: UiStatus.warning,
                action: UiButton(
                  'Allow notifications',
                  size: UiSize.sm,
                  variant: UiButtonVariant.soft,
                  onPressed: store.requestNotifications,
                ),
              ),
            Center(child: _Ring(store: store)),
            _QuickAdd(
              cups: store.settings.cups,
              unit: unit,
              onCup: (ml) => _add(context, ml),
              onCustom: () => _addCustom(context),
            ),
            UiRow(
              gap: UiSpace.md,
              children: [
                Expanded(
                  child: UiStatCard(
                    label: 'Streak',
                    value: streak == 1 ? '1 day' : '$streak days',
                    icon: Icons.local_fire_department_rounded,
                    iconStatus: streak > 0 ? UiStatus.warning : UiStatus.neutral,
                  ),
                ),
                Expanded(
                  child: UiStatCard(
                    label: 'Left today',
                    value: left > 0 ? unit.format(left) : 'Done',
                    icon: left > 0 ? Icons.flag_rounded : Icons.check_circle_rounded,
                    iconStatus: left > 0 ? UiStatus.info : UiStatus.success,
                  ),
                ),
              ],
            ),
            _TodayLog(store: store, onRemove: (log) => _remove(context, log)),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.store});

  final WaterStore store;

  @override
  Widget build(BuildContext context) {
    final unit = store.settings.unit;
    return UiProgressRing(
      store.progress,
      size: 232,
      stroke: 18,
      status: store.goalReached ? UiStatus.success : UiStatus.accent,
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${unit.fromMl(store.todayMl)}', style: context.text.displayMedium),
          Text('of ${unit.format(store.goalMl)}', style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted)),
        ],
      ),
    );
  }
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.cups, required this.unit, required this.onCup, required this.onCustom});

  final List<int> cups;
  final VolumeUnit unit;
  final ValueChanged<int> onCup;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: UiSpace.sm,
      runSpacing: UiSpace.sm,
      children: [
        for (final ml in cups)
          UiButton(
            unit.format(ml),
            icon: Icons.water_drop_rounded,
            variant: UiButtonVariant.soft,
            onPressed: () => onCup(ml),
          ),
        UiButton('Custom', icon: Icons.edit_rounded, variant: UiButtonVariant.outline, onPressed: onCustom),
      ],
    );
  }
}

class _TodayLog extends StatelessWidget {
  const _TodayLog({required this.store, required this.onRemove});

  final WaterStore store;
  final ValueChanged<WaterLog> onRemove;

  @override
  Widget build(BuildContext context) {
    final logs = store.todayLogs;
    final unit = store.settings.unit;
    if (logs.isEmpty) {
      return const UiEmptyState(
        compact: true,
        icon: Icons.water_drop_outlined,
        title: 'Nothing logged yet',
        message: 'Tap a cup size to add your first drink.',
      );
    }
    final locale = MaterialLocalizations.of(context);
    return UiListGroup(
      header: 'Today',
      children: [
        for (final log in logs)
          UiListTile(
            unit.format(log.ml),
            subtitle: locale.formatTimeOfDay(TimeOfDay.fromDateTime(log.time)),
            icon: Icons.water_drop_rounded,
            trailing: UiIconButton(
              Icons.delete_outline_rounded,
              tooltip: 'Delete',
              onPressed: () => onRemove(log),
            ),
          ),
      ],
    );
  }
}
