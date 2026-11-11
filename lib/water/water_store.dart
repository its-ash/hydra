import 'package:flutter/foundation.dart';

import 'settings.dart';
import 'stats.dart';
import 'water_log.dart';
import 'water_platform.dart';

/// UI state: settings, the log and permissions. Every change is written
/// natively first (the notification, widget and alarms read the same data), then
/// the state is read back.
class WaterStore extends ChangeNotifier {
  WaterStore({this.platform = const ChannelWaterPlatform(), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Streaks look back this far.
  static const historyDays = 400;

  final WaterPlatform platform;
  final DateTime Function() _clock;

  HydraSettings _settings = const HydraSettings();
  List<WaterLog> _logs = const [];
  PlatformStatus _status = const PlatformStatus();
  bool _ready = false;

  bool get ready => _ready;
  HydraSettings get settings => _settings;
  PlatformStatus get status => _status;

  /// Every loaded log, oldest first.
  List<WaterLog> get logs => _logs;

  int get goalMl => _settings.goalMl;

  WaterStats get stats => WaterStats(_logs, now: _clock());

  /// Today's drinks, newest first.
  List<WaterLog> get todayLogs {
    final today = dayOf(_clock());
    return [
      for (final log in _logs.reversed)
        if (dayOf(log.time) == today) log,
    ];
  }

  int get todayMl => todayLogs.fold(0, (sum, log) => sum + log.ml);

  double get progress => goalMl <= 0 ? 0 : (todayMl / goalMl).clamp(0.0, 1.0);

  bool get goalReached => todayMl >= goalMl;

  /// Reads everything from the phone. Also called when the app comes back to the
  /// front, because the notification and the widget can add water on their own.
  Future<void> load() async {
    final now = _clock();
    final from = DateTime(now.year, now.month, now.day - historyDays);
    final results = await (platform.loadSettings(), platform.loadLogs(from: from), platform.status()).wait;
    _settings = results.$1;
    _logs = results.$2;
    _status = results.$3;
    // First load: write the defaults back so native code (widget, alarms) sees the same goal as the UI.
    if (!_ready) await platform.saveSettings(_settings);
    _ready = true;
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    _status = await platform.status();
    notifyListeners();
  }

  /// Logs [ml] now. Returns the new log so the caller can offer undo.
  Future<WaterLog?> add(int ml, {DateTime? time}) async {
    if (ml <= 0) return null;
    final at = time ?? _clock();
    final id = await platform.addLog(ml, time: at);
    final log = WaterLog(id: id, time: at, ml: ml);
    _logs = [..._logs, log]..sort((a, b) => a.time.compareTo(b.time));
    notifyListeners();
    return log;
  }

  Future<void> remove(WaterLog log) async {
    await platform.deleteLog(log.id);
    _logs = [
      for (final l in _logs)
        if (l.id != log.id) l,
    ];
    notifyListeners();
  }

  /// Puts back a removed drink at its original time.
  Future<void> restore(WaterLog log) => add(log.ml, time: log.time);

  Future<void> update(HydraSettings Function(HydraSettings current) change) async {
    final next = change(_settings);
    _settings = next;
    notifyListeners();
    await platform.saveSettings(next);
  }

  /// Turns reminders on or off. Turning on asks for the notification permission.
  Future<void> setReminders(bool on) async {
    await update((s) => s.copyWith(remindersOn: on));
    if (on) {
      await platform.requestNotifications();
      await refreshStatus();
    }
  }

  Future<void> requestNotifications() => platform.requestNotifications();

  Future<void> openExactAlarmSettings() => platform.openExactAlarmSettings();

  /// True when reminders are on but the phone will not show them.
  bool get remindersBlocked => _settings.remindersOn && !_status.notifications;
}
