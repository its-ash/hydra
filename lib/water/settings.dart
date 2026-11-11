import 'package:flutter/material.dart';

import 'units.dart';

/// How active the user is; adds water on top of the body-weight base.
enum ActivityLevel {
  low('low', 'Low', 'Mostly sitting', 0),
  moderate('moderate', 'Moderate', 'Some exercise', 350),
  high('high', 'High', 'Daily training', 700);

  const ActivityLevel(this.key, this.label, this.hint, this.extraMl);

  final String key;
  final String label;
  final String hint;
  final int extraMl;

  static ActivityLevel of(String? key) => values.firstWhere((a) => a.key == key, orElse: () => ActivityLevel.moderate);
}

/// Daily goal from body weight, activity and weather.
abstract final class GoalCalculator {
  static const int defaultMlPerKg = 33;
  static const int hotWeatherExtraMl = 500;
  static const int minGoalMl = 1000;
  static const int maxGoalMl = 6000;

  /// `weightKg * mlPerKg` + activity + hot weather, rounded to 50 ml and kept within a sensible range.
  static int compute({
    required int weightKg,
    int mlPerKg = defaultMlPerKg,
    ActivityLevel activity = ActivityLevel.moderate,
    bool hot = false,
  }) {
    final raw = weightKg * mlPerKg + activity.extraMl + (hot ? hotWeatherExtraMl : 0);
    return ((raw / 50).round() * 50).clamp(minGoalMl, maxGoalMl);
  }
}

/// Everything the user can set. The same keys are stored natively
/// (`HydraPrefs.kt`); the notification, the widget and the reminder alarm read
/// `goalMl`, `defaultCupMl`, `unit` and the reminder fields from there.
class HydraSettings {
  const HydraSettings({
    this.weightKg = 70,
    this.mlPerKg = GoalCalculator.defaultMlPerKg,
    this.activity = ActivityLevel.moderate,
    this.hot = false,
    this.goalAuto = true,
    this.manualGoalMl = 2000,
    this.unit = VolumeUnit.ml,
    this.cups = const [150, 250, 500],
    this.defaultCupMl = 250,
    this.remindersOn = false,
    this.intervalMin = 90,
    this.wakeMin = 7 * 60,
    this.sleepMin = 22 * 60,
  });

  factory HydraSettings.fromMap(Map<Object?, Object?> map) {
    const d = HydraSettings();
    int i(String key, int fallback) => (map[key] as num?)?.toInt() ?? fallback;
    final cups = _parseCups(map['cups'] as String?) ?? d.cups;
    final defaultCup = i('defaultCupMl', d.defaultCupMl);
    return HydraSettings(
      weightKg: i('weightKg', d.weightKg),
      mlPerKg: i('mlPerKg', d.mlPerKg),
      activity: ActivityLevel.of(map['activity'] as String?),
      hot: map['hot'] as bool? ?? d.hot,
      goalAuto: map['goalAuto'] as bool? ?? d.goalAuto,
      manualGoalMl: i('manualGoalMl', d.manualGoalMl),
      unit: VolumeUnit.of(map['unit'] as String?),
      cups: cups,
      defaultCupMl: cups.contains(defaultCup) ? defaultCup : cups.first,
      remindersOn: map['remindersOn'] as bool? ?? d.remindersOn,
      intervalMin: i('intervalMin', d.intervalMin),
      wakeMin: i('wakeMin', d.wakeMin),
      sleepMin: i('sleepMin', d.sleepMin),
    );
  }

  final int weightKg;
  final int mlPerKg;
  final ActivityLevel activity;
  final bool hot;

  /// True: the goal is computed from the body fields. False: [manualGoalMl].
  final bool goalAuto;
  final int manualGoalMl;
  final VolumeUnit unit;

  /// Quick-add sizes in ml (three, editable).
  final List<int> cups;

  /// The cup used by the notification and the widget button. One of [cups].
  final int defaultCupMl;
  final bool remindersOn;
  final int intervalMin;

  /// Minutes after midnight.
  final int wakeMin;
  final int sleepMin;

  /// The goal in effect, in ml.
  int get goalMl =>
      goalAuto ? GoalCalculator.compute(weightKg: weightKg, mlPerKg: mlPerKg, activity: activity, hot: hot) : manualGoalMl;

  TimeOfDay get wake => TimeOfDay(hour: wakeMin ~/ 60, minute: wakeMin % 60);
  TimeOfDay get sleep => TimeOfDay(hour: sleepMin ~/ 60, minute: sleepMin % 60);

  HydraSettings copyWith({
    int? weightKg,
    int? mlPerKg,
    ActivityLevel? activity,
    bool? hot,
    bool? goalAuto,
    int? manualGoalMl,
    VolumeUnit? unit,
    List<int>? cups,
    int? defaultCupMl,
    bool? remindersOn,
    int? intervalMin,
    int? wakeMin,
    int? sleepMin,
  }) {
    final newCups = cups ?? this.cups;
    final newDefault = defaultCupMl ?? this.defaultCupMl;
    return HydraSettings(
      weightKg: weightKg ?? this.weightKg,
      mlPerKg: mlPerKg ?? this.mlPerKg,
      activity: activity ?? this.activity,
      hot: hot ?? this.hot,
      goalAuto: goalAuto ?? this.goalAuto,
      manualGoalMl: manualGoalMl ?? this.manualGoalMl,
      unit: unit ?? this.unit,
      cups: newCups,
      defaultCupMl: newCups.contains(newDefault) ? newDefault : newCups.first,
      remindersOn: remindersOn ?? this.remindersOn,
      intervalMin: intervalMin ?? this.intervalMin,
      wakeMin: wakeMin ?? this.wakeMin,
      sleepMin: sleepMin ?? this.sleepMin,
    );
  }

  /// The map sent to native code. Includes the resolved `goalMl`.
  Map<String, Object> toMap() => {
    'weightKg': weightKg,
    'mlPerKg': mlPerKg,
    'activity': activity.key,
    'hot': hot,
    'goalAuto': goalAuto,
    'manualGoalMl': manualGoalMl,
    'goalMl': goalMl,
    'unit': unit.name,
    'cups': cups.join(','),
    'defaultCupMl': defaultCupMl,
    'remindersOn': remindersOn,
    'intervalMin': intervalMin,
    'wakeMin': wakeMin,
    'sleepMin': sleepMin,
  };

  static List<int>? _parseCups(String? text) {
    if (text == null) return null;
    final cups = [for (final p in text.split(',')) if (int.tryParse(p.trim()) case final v? when v > 0) v];
    return cups.length == 3 ? cups : null;
  }
}
