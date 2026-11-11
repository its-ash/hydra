import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../../water/water_store.dart';

/// Reminder switch, interval, wake and sleep time, and the notification and exact-alarm permissions.
class ReminderSection extends StatelessWidget {
  const ReminderSection({super.key, required this.store});

  static const _intervals = [30, 45, 60, 90, 120, 180];

  final WaterStore store;

  static String intervalLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? (h == 1 ? '1 hour' : '$h hours') : '$h h $m min';
  }

  @override
  Widget build(BuildContext context) {
    final s = store.settings;
    return UiColumn(
      gap: UiSpace.md,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (store.remindersBlocked)
          UiAlert(
            'Notifications are blocked, so reminders cannot show.',
            status: UiStatus.warning,
            action: UiButton(
              'Allow notifications',
              size: UiSize.sm,
              variant: UiButtonVariant.soft,
              onPressed: store.requestNotifications,
            ),
          ),
        UiListGroup(
          header: 'Reminders',
          footer:
              'Between your wake and sleep time. Skipped if you logged water in the last 30 minutes, and stopped once '
              'the goal is reached.',
          children: [
            UiSwitchTile(
              'Remind me to drink',
              icon: Icons.notifications_active_rounded,
              value: s.remindersOn,
              onChanged: store.setReminders,
            ),
            if (s.remindersOn)
              UiListTile(
                'Every',
                icon: Icons.timer_rounded,
                value: intervalLabel(s.intervalMin),
                chevron: true,
                onTap: () async {
                  final picked = await UiActionSheet.show<int>(
                    context,
                    title: 'Remind me every',
                    actions: [
                      for (final m in _intervals)
                        UiSheetAction(
                          intervalLabel(m),
                          value: m,
                          icon: m == s.intervalMin ? Icons.check_rounded : null,
                        ),
                    ],
                  );
                  if (picked != null) await store.update((c) => c.copyWith(intervalMin: picked));
                },
              ),
          ],
        ),
        if (s.remindersOn) ...[
          UiTimeField(
            label: 'Wake up',
            value: s.wake,
            clearable: false,
            onChanged: (t) {
              if (t != null) store.update((c) => c.copyWith(wakeMin: t.hour * 60 + t.minute));
            },
          ),
          UiTimeField(
            label: 'Go to sleep',
            helper: 'No reminders from this time until you wake up.',
            value: s.sleep,
            clearable: false,
            onChanged: (t) {
              if (t != null) store.update((c) => c.copyWith(sleepMin: t.hour * 60 + t.minute));
            },
          ),
          if (!store.status.exactAlarms)
            UiListGroup(
              footer: 'Without this, Android may delay reminders by a few minutes.',
              children: [
                UiListTile(
                  'Allow exact timing',
                  icon: Icons.alarm_on_rounded,
                  iconStatus: UiStatus.warning,
                  chevron: true,
                  onTap: store.openExactAlarmSettings,
                ),
              ],
            ),
        ],
      ],
    );
  }
}
