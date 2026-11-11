import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'screens/home_screen.dart';
import 'water/water_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(HydraApp(store: WaterStore()));
}

class HydraApp extends StatelessWidget {
  const HydraApp({super.key, required this.store});

  final WaterStore store;

  @override
  Widget build(BuildContext context) {
    return UiApp(
      title: 'Hydra',
      home: HomeScreen(store: store),
    );
  }
}
