/// One drink: [ml] millilitres at [time]. [id] is the row id in the native
/// database (`logs` table, see CLAUDE.md).
class WaterLog {
  const WaterLog({required this.id, required this.time, required this.ml});

  factory WaterLog.fromMap(Map<Object?, Object?> map) => WaterLog(
    id: (map['id'] as num).toInt(),
    time: DateTime.fromMillisecondsSinceEpoch((map['ts'] as num).toInt()),
    ml: (map['ml'] as num).toInt(),
  );

  final int id;
  final DateTime time;
  final int ml;
}
