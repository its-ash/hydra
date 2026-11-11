import 'package:flutter/services.dart';

import 'settings.dart';
import 'water_log.dart';

/// What the phone currently allows.
class PlatformStatus {
  const PlatformStatus({this.notifications = true, this.exactAlarms = true});

  factory PlatformStatus.fromMap(Map<Object?, Object?> map) => PlatformStatus(
    notifications: map['notifications'] as bool? ?? true,
    exactAlarms: map['exactAlarms'] as bool? ?? true,
  );

  /// POST_NOTIFICATIONS (Android 13+) or notifications enabled for the app.
  final bool notifications;

  /// Exact alarms allowed. Without it reminders may arrive a few minutes late.
  final bool exactAlarms;
}

/// Everything the UI needs from native code. The real implementation is
/// [ChannelWaterPlatform]; tests use a fake.
abstract interface class WaterPlatform {
  Future<HydraSettings> loadSettings();
  Future<void> saveSettings(HydraSettings settings);

  /// Logs with `time >= from`, oldest first.
  Future<List<WaterLog>> loadLogs({required DateTime from});

  /// Returns the new row id. [time] defaults to now.
  Future<int> addLog(int ml, {DateTime? time});
  Future<void> deleteLog(int id);
  Future<PlatformStatus> status();
  Future<void> requestNotifications();
  Future<void> openExactAlarmSettings();
}

/// Dart side of MethodChannel "com.itsash.hydra/control" (MainActivity.kt).
class ChannelWaterPlatform implements WaterPlatform {
  const ChannelWaterPlatform();

  static const _channel = MethodChannel('com.itsash.hydra/control');

  @override
  Future<HydraSettings> loadSettings() async =>
      HydraSettings.fromMap(await _channel.invokeMapMethod<Object?, Object?>('getSettings') ?? const {});

  @override
  Future<void> saveSettings(HydraSettings settings) => _channel.invokeMethod('saveSettings', settings.toMap());

  @override
  Future<List<WaterLog>> loadLogs({required DateTime from}) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>('getLogs', {
      'from': from.millisecondsSinceEpoch,
    });
    return [for (final row in rows ?? const <Map<Object?, Object?>>[]) WaterLog.fromMap(row)];
  }

  @override
  Future<int> addLog(int ml, {DateTime? time}) async =>
      (await _channel.invokeMethod<num>('addLog', {'ml': ml, if (time != null) 'ts': time.millisecondsSinceEpoch}))!
          .toInt();

  @override
  Future<void> deleteLog(int id) => _channel.invokeMethod('deleteLog', {'id': id});

  @override
  Future<PlatformStatus> status() async =>
      PlatformStatus.fromMap(await _channel.invokeMapMethod<Object?, Object?>('status') ?? const {});

  @override
  Future<void> requestNotifications() => _channel.invokeMethod('requestNotifications');

  @override
  Future<void> openExactAlarmSettings() => _channel.invokeMethod('openExactAlarmSettings');
}
