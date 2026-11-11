/// Display unit for volumes. Everything is stored in millilitres; ounces are
/// only a way of showing (and typing) amounts.
enum VolumeUnit {
  ml('ml', 'Millilitres'),
  oz('oz', 'US fluid ounces');

  const VolumeUnit(this.label, this.title);

  final String label;
  final String title;

  static const double _mlPerOz = 29.5735;

  static VolumeUnit of(String? key) => values.firstWhere((u) => u.name == key, orElse: () => VolumeUnit.ml);

  /// [ml] as a whole number in this unit.
  int fromMl(int ml) => this == oz ? (ml / _mlPerOz).round() : ml;

  /// A whole number typed in this unit, as millilitres.
  int toMl(int amount) => this == oz ? (amount * _mlPerOz).round() : amount;

  /// "250 ml" or "8 oz".
  String format(int ml) => '${fromMl(ml)} $label';

  /// Step of the stepper that edits a goal in this unit.
  int get goalStep => this == oz ? 2 : 50;
}
