import 'water_log.dart';

/// Midnight at the start of [t]'s local day.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// The day after [day]. Goes through the calendar, so DST shifts do not matter.
DateTime nextDay(DateTime day) => DateTime(day.year, day.month, day.day + 1);

DateTime previousDay(DateTime day) => DateTime(day.year, day.month, day.day - 1);

/// Total ml of one day.
class DayTotal {
  const DayTotal(this.day, this.ml);

  final DateTime day;
  final int ml;

  bool metGoal(int goalMl) => ml >= goalMl;
}

/// History numbers computed from the log. Days are compared with the current
/// goal, because past goals are not stored.
class WaterStats {
  WaterStats(Iterable<WaterLog> logs, {required DateTime now}) : today = dayOf(now) {
    for (final log in logs) {
      final day = dayOf(log.time);
      if (day.isAfter(today)) continue;
      _totals[day] = (_totals[day] ?? 0) + log.ml;
      if (_firstDay == null || day.isBefore(_firstDay!)) _firstDay = day;
    }
  }

  final DateTime today;
  final Map<DateTime, int> _totals = {};
  DateTime? _firstDay;

  int totalOn(DateTime day) => _totals[dayOf(day)] ?? 0;

  /// The last [days] days ending today, oldest first. Days without drinks are 0.
  List<DayTotal> lastDays(int days) {
    final out = <DayTotal>[];
    var day = today;
    for (var i = 0; i < days; i++) {
      out.add(DayTotal(day, totalOn(day)));
      day = previousDay(day);
    }
    return out.reversed.toList();
  }

  /// Average ml per day over the last [days] days, counting only days since the
  /// first logged drink (so a new user is not averaged down by empty days).
  /// 0 when nothing is logged.
  int averageMl(int days) {
    final first = _firstDay;
    if (first == null) return 0;
    final tracked = lastDays(days).where((d) => !d.day.isBefore(first)).toList();
    if (tracked.isEmpty) return 0;
    return (tracked.fold<int>(0, (sum, d) => sum + d.ml) / tracked.length).round();
  }

  /// Days within the last [days] that reached [goalMl].
  int daysMet(int days, int goalMl) => lastDays(days).where((d) => d.metGoal(goalMl)).length;

  /// Consecutive days that met the goal, ending today. Today does not break the
  /// streak while it is still in progress: the count then ends yesterday.
  int currentStreak(int goalMl) {
    if (goalMl <= 0) return 0;
    var day = today;
    if (totalOn(day) < goalMl) day = previousDay(day);
    var streak = 0;
    while (totalOn(day) >= goalMl) {
      streak++;
      day = previousDay(day);
    }
    return streak;
  }

  /// Longest run of consecutive goal days in the whole log.
  int bestStreak(int goalMl) {
    final first = _firstDay;
    if (first == null || goalMl <= 0) return 0;
    var best = 0, run = 0;
    for (var day = first; !day.isAfter(today); day = nextDay(day)) {
      run = totalOn(day) >= goalMl ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }
}
