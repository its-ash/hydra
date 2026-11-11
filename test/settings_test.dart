import 'package:flutter_test/flutter_test.dart';
import 'package:hydra/water/settings.dart';
import 'package:hydra/water/units.dart';

void main() {
  group('GoalCalculator', () {
    test('33 ml per kg plus activity, rounded to 50', () {
      // 70 * 33 = 2310 + 350 = 2660 -> 2650
      expect(GoalCalculator.compute(weightKg: 70), 2650);
      expect(GoalCalculator.compute(weightKg: 70, activity: ActivityLevel.low), 2300);
      expect(GoalCalculator.compute(weightKg: 70, activity: ActivityLevel.high), 3000);
    });

    test('hot weather adds 500 ml', () {
      expect(GoalCalculator.compute(weightKg: 60, activity: ActivityLevel.low, hot: true), 2500);
    });

    test('ml per kg is adjustable', () {
      expect(GoalCalculator.compute(weightKg: 80, mlPerKg: 30, activity: ActivityLevel.low), 2400);
    });

    test('result stays within a sensible range', () {
      expect(GoalCalculator.compute(weightKg: 30, mlPerKg: 20, activity: ActivityLevel.low), GoalCalculator.minGoalMl);
      expect(GoalCalculator.compute(weightKg: 250, mlPerKg: 50, activity: ActivityLevel.high, hot: true), GoalCalculator.maxGoalMl);
    });
  });

  group('HydraSettings', () {
    test('goalMl is computed or manual', () {
      expect(const HydraSettings().goalMl, 2650);
      expect(const HydraSettings(goalAuto: false, manualGoalMl: 3100).goalMl, 3100);
    });

    test('toMap includes the resolved goal and round-trips', () {
      final s = const HydraSettings(
        weightKg: 82,
        activity: ActivityLevel.high,
        hot: true,
        unit: VolumeUnit.oz,
        cups: [200, 300, 600],
        defaultCupMl: 300,
        remindersOn: true,
        intervalMin: 60,
        wakeMin: 6 * 60 + 30,
        sleepMin: 23 * 60,
      );
      final map = s.toMap();
      expect(map['goalMl'], s.goalMl);
      expect(map['cups'], '200,300,600');
      final back = HydraSettings.fromMap(map);
      expect(back.toMap(), map);
      expect(back.unit, VolumeUnit.oz);
      expect(back.wake.hour, 6);
      expect(back.wake.minute, 30);
    });

    test('empty or damaged maps fall back to defaults', () {
      expect(HydraSettings.fromMap(const {}).toMap(), const HydraSettings().toMap());
      final broken = HydraSettings.fromMap(const {'cups': '100,abc', 'unit': 'pints', 'activity': '??'});
      expect(broken.cups, const [150, 250, 500]);
      expect(broken.unit, VolumeUnit.ml);
      expect(broken.activity, ActivityLevel.moderate);
    });

    test('the default cup is always one of the cups', () {
      final s = const HydraSettings().copyWith(cups: [100, 200, 300]);
      expect(s.cups, contains(s.defaultCupMl));
      expect(HydraSettings.fromMap({'cups': '100,200,300', 'defaultCupMl': 250}).defaultCupMl, 100);
    });
  });

  group('VolumeUnit', () {
    test('converts and formats', () {
      expect(VolumeUnit.ml.format(250), '250 ml');
      expect(VolumeUnit.oz.fromMl(237), 8);
      expect(VolumeUnit.oz.format(2000), '68 oz');
      expect(VolumeUnit.oz.toMl(8), 237);
      expect(VolumeUnit.ml.toMl(330), 330);
    });

    test('unknown key means ml', () {
      expect(VolumeUnit.of(null), VolumeUnit.ml);
      expect(VolumeUnit.of('oz'), VolumeUnit.oz);
    });
  });
}
