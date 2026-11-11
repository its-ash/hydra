import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../water/water_store.dart';
import 'history_page.dart';
import 'settings_screen.dart';
import 'today_page.dart';

/// Bottom navigation between Today and History, with Settings in the app bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final WaterStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _items = [
    UiNavItem(Icons.water_drop_outlined, 'Today', selectedIcon: Icons.water_drop_rounded),
    UiNavItem(Icons.bar_chart_outlined, 'History', selectedIcon: Icons.bar_chart_rounded),
  ];

  late final AppLifecycleListener _lifecycle;
  int _tab = 0;

  WaterStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.load();
    // Back from a permission screen, the notification or the widget: read the phone again.
    _lifecycle = AppLifecycleListener(onResume: store.load);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => UiShell(
        items: _items,
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
        appBar: UiAppBar(
          title: 'Hydra',
          actions: [
            UiIconButton(
              Icons.settings_rounded,
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => SettingsScreen(store: store)),
              ),
            ),
          ],
        ),
        pages: [
          if (store.ready) TodayPage(store: store) else const Center(child: UiSpinner(size: 28)),
          if (store.ready) HistoryPage(store: store) else const Center(child: UiSpinner(size: 28)),
        ],
      ),
    );
  }
}
