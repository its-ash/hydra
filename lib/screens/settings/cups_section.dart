import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../../water/water_store.dart';

/// The three quick-add sizes, and which one the notification and widget use.
class CupsSection extends StatelessWidget {
  const CupsSection({super.key, required this.store});

  final WaterStore store;

  Future<void> _edit(BuildContext context, int index) async {
    final unit = store.settings.unit;
    final current = store.settings.cups[index];
    final text = await UiDialog.prompt(
      context,
      title: 'Cup ${index + 1}',
      label: 'Size (${unit.label})',
      initialValue: '${unit.fromMl(current)}',
      keyboardType: TextInputType.number,
      validator: (v) {
        final n = int.tryParse(v.trim());
        return n == null || unit.toMl(n) < 20 || unit.toMl(n) > 2000 ? 'Enter a size between 20 and 2000 ml.' : null;
      },
    );
    final amount = int.tryParse((text ?? '').trim());
    if (amount == null) return;
    final ml = unit.toMl(amount);
    await store.update((s) {
      final cups = [...s.cups]..[index] = ml;
      // Keep the default pointing at the same slot when its size is edited.
      return s.copyWith(cups: cups, defaultCupMl: s.defaultCupMl == current ? ml : s.defaultCupMl);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = store.settings;
    final unit = s.unit;
    return UiListGroup(
      header: 'Cup sizes',
      footer: 'The default cup is used by the notification and widget buttons.',
      children: [
        for (var i = 0; i < s.cups.length; i++)
          UiListTile(
            'Cup ${i + 1}',
            icon: Icons.local_drink_rounded,
            value: unit.format(s.cups[i]),
            chevron: true,
            onTap: () => _edit(context, i),
          ),
        UiListTile(
          'Default cup',
          icon: Icons.touch_app_rounded,
          value: unit.format(s.defaultCupMl),
          chevron: true,
          onTap: () async {
            final picked = await UiActionSheet.show<int>(
              context,
              title: 'Default cup',
              actions: [
                for (final ml in s.cups)
                  UiSheetAction(unit.format(ml), value: ml, icon: ml == s.defaultCupMl ? Icons.check_rounded : null),
              ],
            );
            if (picked != null) await store.update((c) => c.copyWith(defaultCupMl: picked));
          },
        ),
      ],
    );
  }
}
