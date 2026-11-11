import 'package:flutter_test/flutter_test.dart';
import 'package:hydra/water/settings.dart';
import 'package:hydra/water/water_log.dart';
import 'package:hydra/water/water_platform.dart';
import 'package:hydra/water/water_store.dart';

/// In-memory stand-in for the Kotlin side.
class FakePlatform implements WaterPlatform {
  HydraSettings settings = const HydraSettings();
  final List<WaterLog> logs = [];
  PlatformStatus platformStatus = const PlatformStatus();
  int saves = 0;
  int notificationRequests = 0;
  int _nextId = 1;

  @override
  Future<HydraSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(HydraSettings s) async {
    settings = s;
    saves++;
  }

  @override
  Future<List<WaterLog>> loadLogs({required DateTime from}) async => [
    for (final l in logs)
      if (!l.time.isBefore(from)) l,
  ];

  @override
  Future<int> addLog(int ml, {DateTime? time}) async {
    final id = _nextId++;
    logs.add(WaterLog(id: id, time: time ?? DateTime.now(), ml: ml));
    return id;
  }

  @override
  Future<void> deleteLog(int id) async => logs.removeWhere((l) => l.id == id);

  @override
  Future<PlatformStatus> status() async => platformStatus;

  @override
  Future<void> requestNotifications() async => notificationRequests++;

  @override
  Future<void> openExactAlarmSettings() async {}
}

void main() {
  late FakePlatform platform;
  late DateTime now;
  late WaterStore store;

  setUp(() {
    platform = FakePlatform();
    now = DateTime(2026, 3, 15, 14);
    store = WaterStore(platform: platform, clock: () => now);
  });

  test('load reads everything and saves the defaults once', () async {
    platform.logs.add(WaterLog(id: 99, time: DateTime(2026, 3, 15, 8), ml: 300));
    await store.load();
    expect(store.ready, isTrue);
    expect(store.todayMl, 300);
    expect(platform.saves, 1);
    await store.load();
    expect(platform.saves, 1);
  });

  test('add logs natively and updates today', () async {
    await store.load();
    final log = await store.add(250);
    expect(log, isNotNull);
    expect(store.todayMl, 250);
    expect(platform.logs.single.ml, 250);
    expect(store.todayLogs.single.id, log!.id);
  });

  test('add ignores zero and negative amounts', () async {
    await store.load();
    expect(await store.add(0), isNull);
    expect(await store.add(-5), isNull);
    expect(platform.logs, isEmpty);
  });

  test('remove then restore puts the drink back at its original time', () async {
    await store.load();
    final log = (await store.add(500, time: DateTime(2026, 3, 15, 9)))!;
    await store.remove(log);
    expect(store.todayMl, 0);
    expect(platform.logs, isEmpty);
    await store.restore(log);
    expect(store.todayMl, 500);
    expect(store.todayLogs.single.time, DateTime(2026, 3, 15, 9));
  });

  test("today's log is newest first and ignores other days", () async {
    await store.load();
    await store.add(100, time: DateTime(2026, 3, 15, 8));
    await store.add(200, time: DateTime(2026, 3, 15, 12));
    await store.add(300, time: DateTime(2026, 3, 14, 20));
    expect(store.todayLogs.map((l) => l.ml), [200, 100]);
  });

  test('progress and goal reached', () async {
    platform.settings = const HydraSettings(goalAuto: false, manualGoalMl: 2000);
    await store.load();
    await store.add(500);
    expect(store.progress, 0.25);
    expect(store.goalReached, isFalse);
    await store.add(1600);
    expect(store.progress, 1);
    expect(store.goalReached, isTrue);
  });

  test('update saves the new settings natively', () async {
    await store.load();
    await store.update((s) => s.copyWith(weightKg: 90));
    expect(platform.settings.weightKg, 90);
    expect(store.goalMl, platform.settings.goalMl);
  });

  test('turning reminders on asks for notifications; off does not', () async {
    await store.load();
    await store.setReminders(true);
    expect(platform.settings.remindersOn, isTrue);
    expect(platform.notificationRequests, 1);
    await store.setReminders(false);
    expect(platform.settings.remindersOn, isFalse);
    expect(platform.notificationRequests, 1);
  });

  test('reminders are blocked only when on and notifications are denied', () async {
    platform.platformStatus = const PlatformStatus(notifications: false);
    await store.load();
    expect(store.remindersBlocked, isFalse);
    await store.update((s) => s.copyWith(remindersOn: true));
    expect(store.remindersBlocked, isTrue);
  });
}
