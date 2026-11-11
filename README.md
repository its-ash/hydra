# Hydra

Track your water and get smart reminders. Log a glass from the notification or a widget.

**[Website](https://hydra.itsash.in)** · **[Download APK](https://github.com/its-ash/hydra/releases/latest/download/hydra.apk)** · Get it in **[Ash Store](https://store.itsash.in)**

## Features

- **Today**: a progress ring of what you drank against your daily goal, quick-add cups
  (150 / 250 / 500 ml by default, editable) and a custom amount. Delete a drink or undo
  an add. A streak counts the days in a row you reached the goal.
- **Goal from your body**: about 33 ml per kg of body weight (adjustable), plus activity
  level and an optional hot-weather boost. Or type your own goal.
- **Smart reminders**: every 30 minutes to 3 hours between your wake and sleep time.
  Skipped if you drank in the last 30 minutes, and stopped once you reach the goal.
- **Log without opening the app**: the reminder has **+250 ml** (your default cup) and
  **Snooze 30 min** buttons. The same quick add is on the home-screen widget.
- **History**: the last 7 or 30 days against your goal, the average per day, goal days and
  your best streak.
- **ml or oz**, light and dark theme.
- **Private**: no account, everything stays on your phone. The only network call is the
  update check in Settings.

## Install

- **Ash Store**: install [Ash Store](https://store.itsash.in) once, then install and update Hydra from it.
- **APK**: download the [latest APK](https://github.com/its-ash/hydra/releases/latest/download/hydra.apk) on your phone and open it. Allow your browser to install unknown apps if Android asks.

Requires Android 8.0 (API 26) or later. Turn on **Reminders** in Settings and allow
notifications when Android asks. On Android 12 and later you can also allow exact alarms
so reminders arrive on the minute. Add the **Hydra** widget from your home screen's widget list.

## Develop

Needs Flutter ≥ 3.44 and the shared theme package at `../theme`.

```bash
make run           # run on a connected device
make test          # flutter analyze + flutter test
make test-native   # JVM tests for the Kotlin reminder planner
make build         # release APK
make deploy        # bump version, build, tag, push, GitHub release (see store.mk)
```

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `hydra.apk`. Ash Store and the website pick up the new
version from that release.

## Project layout

```
lib/
├── main.dart
├── water/
│   ├── settings.dart             # HydraSettings, GoalCalculator, ActivityLevel
│   ├── stats.dart                # daily totals, average, streaks (pure)
│   ├── units.dart                # ml / oz
│   ├── water_log.dart            # one drink
│   ├── water_platform.dart       # MethodChannel to MainActivity.kt
│   └── water_store.dart          # UI state, talks to native first
└── screens/
    ├── home_screen.dart          # Today / History tabs, Settings icon
    ├── today_page.dart           # ring, quick add, streak, today's log
    ├── history_page.dart         # 7 / 30 day bar chart, stats
    ├── settings_screen.dart
    └── settings/                 # goal, cups, reminders sections
android/app/src/main/kotlin/com/itsash/hydra/
├── Planner.kt                    # pure reminder rules and day math
├── Reminders.kt                  # AlarmManager scheduling, notification
├── Receivers.kt                  # alarm, notification actions, boot / time change
├── HydraWidget.kt                # home-screen widget
├── WaterDb.kt                    # SQLite water log (hydra.db)
├── HydraPrefs.kt                 # settings (SharedPreferences)
└── MainActivity.kt               # channel handlers, permissions
android/app/src/test/…/PlannerTest.kt
```

See `CLAUDE.md` for details.

## License

No license file is included yet.

Built by [itsash.in](https://itsash.in).
