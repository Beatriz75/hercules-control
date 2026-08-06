class StoreType {
  const StoreType(this.name, this.label);

  final String name;
  final String label;

  static const pideHoy = StoreType('pideHoy', 'Pide Hoy');
  static const mexiOfertas = StoreType('mexiOfertas', 'MexiOfertas');

  static const values = [pideHoy, mexiOfertas];

  static StoreType fromCode(String value) {
    return values.firstWhere(
      (item) => item.name == value,
      orElse: () => StoreType(value, value),
    );
  }
}
