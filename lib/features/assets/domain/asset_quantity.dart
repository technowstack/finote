class AssetQuantity {
  factory AssetQuantity.fromScaled(int scaled) {
    if (scaled.abs() > _maxMagnitude) {
      throw RangeError('Asset quantity is out of range: $scaled');
    }
    return AssetQuantity._(scaled);
  }

  const AssetQuantity._(this.scaled);

  factory AssetQuantity.parse(String value) {
    final input = value.trim();
    final match = RegExp(r'^([+-]?)(0|[1-9]\d*)(?:\.(\d{1,8}))?$')
        .firstMatch(input);
    if (match == null) {
      throw FormatException('Invalid asset quantity: $value');
    }

    final negative = match.group(1) == '-';
    final whole = int.parse(match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(_scaleDigits, '0');
    final fractionValue = fraction.isEmpty ? 0 : int.parse(fraction);
    final magnitude = whole * scale + fractionValue;
    if (magnitude > _maxMagnitude) {
      throw FormatException('Asset quantity is out of range: $value');
    }
    final scaled = negative ? -magnitude : magnitude;
    return AssetQuantity.fromScaled(scaled);
  }

  static const scale = 100000000;
  static const _scaleDigits = 8;
  static const _maxMagnitude = 9223372036854775807;

  final int scaled;

  bool get isNegative => scaled < 0;
  bool get isZero => scaled == 0;

  AssetQuantity operator +(AssetQuantity other) =>
      AssetQuantity.fromScaled(scaled + other.scaled);

  AssetQuantity operator -(AssetQuantity other) =>
      AssetQuantity.fromScaled(scaled - other.scaled);

  @override
  String toString() {
    final magnitude = scaled.abs();
    final whole = magnitude ~/ scale;
    final fraction = (magnitude % scale).toString().padLeft(_scaleDigits, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    final value = trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
    return scaled < 0 ? '-$value' : value;
  }

  @override
  bool operator ==(Object other) =>
      other is AssetQuantity && other.scaled == scaled;

  @override
  int get hashCode => scaled.hashCode;
}
