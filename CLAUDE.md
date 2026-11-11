# Hydra (package: hydra / com.itsash.hydra)

Offline water tracker with smart reminders. Flutter is the UI (Today, History,
Settings); native Kotlin owns the data and everything that must work with the app
closed: the reminder alarm, the notification actions and the home-screen widget.

## Data contract (Kotlin and Dart)

Native code is the single owner of the data. Dart reads and writes it only through
the MethodChannel, so the notification and widget (which run without Dart) and the UI
always see the same state.

- **Water log**: SQLite file `hydra.db`, table `logs(id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER NOT NULL, ml INTEGER NOT NULL)`. `ts` is epoch milliseconds, `ml` is
  millilitres. "Today" is the local calendar day. Kotlin: `WaterDb.kt`; Dart: `WaterLog`.
- **Settings**: SharedPreferences file `hydra_prefs` (`HydraPrefs.kt`), mirrored by
  `HydraSettings` (`lib/water/settings.dart`). Dart owns the values and sends the whole map
  with `saveSettings`. Keys (ints unless noted): `weightKg`, `mlPerKg`, `activity` (string),
  `hot` (bool), `goalAuto` (bool), `manualGoalMl`, `goalMl` (the resolved goal; native reads
  only this), `unit` (`ml`|`oz`), `cups` (string `"150,250,500"`), `defaultCupMl`,
  `remindersOn` (bool), `intervalMin`, `wakeMin`, `sleepMin` (minutes after midnight).
  Native-only keys (never sent to Dart): `snoozeUntil` (long), `askedNotifications` (bool).
  Add a key in both `settings.dart` (`fromMap`/`toMap`) and `HydraPrefs.kt` if native needs it.
- On first load Dart writes the defaults back so native sees the same `goalMl`.

## Channel `com.itsash.hydra/control` (`MainActivity.kt`, `lib/water/water_platform.dart`)

`getSettings`, `saveSettings(map)`, `getLogs({from})`, `addLog({ml, ts?})` → id,
`deleteLog({id})`, `status()` → `{notifications, exactAlarms}`, `requestNotifications`
(system dialog once, then app notification settings), `openExactAlarmSettings`.
Every mutation ends in `HydraSync.refresh` (reschedule the alarm + redraw the widget).

## Reminders

- `Planner.kt`: pure rules, unit tested (`PlannerTest.kt`). Slots are wake, wake + N, ... up
  to sleep (a window may cross midnight; wake == sleep means all day). `nextTrigger` is the next
  slot after now, or tomorrow's first slot once the goal is reached, or the snooze end
  (`ReminderPlanner.SNOOZE_MS` = 30 min). `decide` skips on goal reached, quiet hours, or a log
  in the last 30 minutes.
- `Reminders.kt`: `ReminderScheduler` keeps one alarm (`setExactAndAllowWhileIdle` when
  `canScheduleExactAlarms`, else `setAndAllowWhileIdle`). `Notifier` builds the notification
  (channel `reminders`) with "+<default cup>" and "Snooze 30 min" buttons.
- `Receivers.kt`: `ReminderReceiver` (alarm → decide → notify → reschedule), `ActionReceiver`
  (the buttons and the widget button write the log natively), `BootReceiver` (boot, app update,
  time / time zone / date change, exact-alarm permission change → `HydraSync.refresh`).
- Permissions: `POST_NOTIFICATIONS` (requested when reminders are switched on),
  `SCHEDULE_EXACT_ALARM` (optional, Settings links to it), `RECEIVE_BOOT_COMPLETED`, `INTERNET`
  (update check only).

## Widget

`HydraWidget.kt` + `res/layout/widget_hydra.xml`: today's amount, a progress bar, and a
"+<default cup>" button (`ActionReceiver`). Light and dark through `res/values{,-night}/colors.xml`.
Redrawn by `HydraSync` after any change and on date change.

## Code layout

- `lib/water/`: `settings.dart` (`HydraSettings`, `GoalCalculator`: weight × ml/kg + activity +
  hot weather, rounded to 50), `stats.dart` (totals, average, streaks; pure), `units.dart`
  (ml / oz, stored as ml), `water_platform.dart` (interface + channel), `water_store.dart`.
- `lib/screens/`: `home_screen.dart` (tabs, reloads on resume), `today_page.dart`,
  `history_page.dart`, `settings_screen.dart` + `settings/` sections. Settings ends with
  `UiUpdateSection(storeId: 'hydra')` then `UiDeveloperSection()`.
- Tests: `test/` (settings, stats, store with a fake platform) and `android/app/src/test/`.

## Commands

- `make run`, `make build`, `make test` (analyze + Dart tests), `make test-native`
  (Kotlin planner tests), `make clean`.
- Icon: `assets/icon/*.svg` → `rsvg-convert -w 1024 -h 1024` to `*-1024.png`, then
  `dart run flutter_launcher_icons`. Notification icon: `res/drawable/ic_stat_water.xml` (white vector).

## Conventions

- minSdk 26. UI only from `../theme` (read `../theme/COMPONENTS.md`).
- Only network use: `UiUpdateSection` in Settings. No analytics.
- Known limit: if water is added from the notification or widget while the app is in the
  foreground, the UI shows it on the next resume.

## Release (Ash Store)

- `store.json` (id `hydra`, repo its-ash/hydra), `store.mk`, `index.html` + `CNAME`
  (`hydra.itsash.in`). See `../ash-store/store-kit/STORE.md`.
- `make deploy` = bump version → build → commit, tag `vX.Y.Z`, push → GitHub release with
  `hydra.apk` → topics, homepage, Pages. Never create releases, tags or asset names by hand.
- Do not edit `store.mk` here. Edit `../ash-store/store-kit/store.mk`, then run
  `make store-sync` at the workspace root.
