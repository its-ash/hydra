import 'package:flutter_test/flutter_test.dart';
import 'package:hydra/water/stats.dart';
import 'package:hydra/water/water_log.dart';

final _now = DateTime(2026, 3, 15, 14, 30);

/// A drink [daysAgo] days before [_now] at 09:00.
WaterLog drink(int ml, {int daysAgo = 0, int id = 0}) =>
    WaterLog(id: id, time: DateTime(2026, 3, 15 - daysAgo, 9), ml: ml);

void main() {
  test('totals add up per local day', () {
    final stats = WaterStats([drink(250), drink(500), drink(300, daysAgo: 1)], now: _now);
    expect(stats.totalOn(_now), 750);
    expect(stats.totalOn(DateTime(2026, 3, 14, 23)), 300);
    expect(stats.totalOn(DateTime(2026, 3, 1)), 0);
  });

  test('lastDays is oldest first and fills empty days', () {
    final days = WaterStats([drink(400, daysAgo: 2)], now: _now).lastDays(3);
    expect(days.map((d) => d.day.day), [13, 14, 15]);
    expect(days.map((d) => d.ml), [400, 0, 0]);
  });

  test('lastDays crosses a month boundary', () {
    final days = WaterStats(const [], now: DateTime(2026, 3, 2)).lastDays(4);
    expect(days.map((d) => (d.day.month, d.day.day)), [(2, 27), (2, 28), (3, 1), (3, 2)]);
  });

  test('average only counts days since the first drink', () {
    // First drink 2 days ago: tracked days are 2 days ago, yesterday and today.
    final stats = WaterStats([drink(900, daysAgo: 2), drink(1200, daysAgo: 1), drink(300)], now: _now);
    expect(stats.averageMl(30), 800);
    expect(stats.averageMl(2), 750); // yesterday and today only
  });

  test('average is 0 without logs', () {
    expect(WaterStats(const [], now: _now).averageMl(7), 0);
  });

  test('current streak counts days that met the goal', () {
    final stats = WaterStats([drink(2000), drink(2100, daysAgo: 1), drink(2500, daysAgo: 2), drink(900, daysAgo: 3)], now: _now);
    expect(stats.currentStreak(2000), 3);
  });

  test('an unfinished today does not break the streak', () {
    final stats = WaterStats([drink(500), drink(2000, daysAgo: 1), drink(2000, daysAgo: 2)], now: _now);
    expect(stats.currentStreak(2000), 2);
  });

  test('a missed yesterday ends the streak', () {
    final stats = WaterStats([drink(2000), drink(500, daysAgo: 1), drink(2000, daysAgo: 2)], now: _now);
    expect(stats.currentStreak(2000), 1);
    expect(WaterStats([drink(2000, daysAgo: 2)], now: _now).currentStreak(2000), 0);
  });

  test('best streak finds the longest run', () {
    final logs = [
      for (final d in [1, 2, 3, 4, 8, 9]) drink(2000, daysAgo: d),
    ];
    final stats = WaterStats(logs, now: _now);
    expect(stats.bestStreak(2000), 4);
    expect(stats.currentStreak(2000), 4);
    expect(stats.bestStreak(2500), 0);
  });

  test('days met counts goal days inside the window', () {
    final stats = WaterStats([drink(2000), drink(2000, daysAgo: 3), drink(2000, daysAgo: 10)], now: _now);
    expect(stats.daysMet(7, 2000), 2);
    expect(stats.daysMet(30, 2000), 3);
  });

  test('a zero goal never loops forever', () {
    final stats = WaterStats([drink(100)], now: _now);
    expect(stats.currentStreak(0), 0);
    expect(stats.bestStreak(0), 0);
  });

  test('logs from the future are ignored', () {
    final stats = WaterStats([WaterLog(id: 1, time: DateTime(2026, 3, 16, 8), ml: 500)], now: _now);
    expect(stats.lastDays(1).single.ml, 0);
    expect(stats.averageMl(7), 0);
  });
}
