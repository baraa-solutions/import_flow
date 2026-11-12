/// Client-side preview of the air chargeable-weight engine (backend: modules/air_freight/service.py).
///
/// The server recomputes and stores the authoritative figures on save; this mirror only gives the user an
/// instant preview while typing. volumetric kg = L x W x H (cm) / divisor x qty; chargeable = max(gross, volumetric).
library;

import 'dart:math' as math;

const double kgPerLb = 0.45359237;

class AirPackageInput {
  final double length;
  final double width;
  final double height;
  final String dimensionUnit; // mm | cm | m
  final int quantity;
  final double grossWeight; // per package
  final String weightUnit; // kg | lb

  const AirPackageInput({
    required this.length,
    required this.width,
    required this.height,
    this.dimensionUnit = 'cm',
    this.quantity = 1,
    this.grossWeight = 0,
    this.weightUnit = 'kg',
  });

  Map<String, dynamic> toJson() => {
        'length': length,
        'width': width,
        'height': height,
        'dimension_unit': dimensionUnit,
        'quantity': quantity,
        'gross_weight': grossWeight,
        'weight_unit': weightUnit,
      };

  factory AirPackageInput.fromJson(Map<String, dynamic> json) => AirPackageInput(
        length: (json['length'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 0,
        height: (json['height'] as num?)?.toDouble() ?? 0,
        dimensionUnit: json['dimension_unit'] as String? ?? 'cm',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        grossWeight: (json['gross_weight'] as num?)?.toDouble() ?? 0,
        weightUnit: json['weight_unit'] as String? ?? 'kg',
      );
}

class ChargeableWeightPreview {
  final int pieces;
  final double grossKg;
  final double volumeCbm;
  final double volumetricKg;
  final double chargeableKg;

  const ChargeableWeightPreview({
    required this.pieces,
    required this.grossKg,
    required this.volumeCbm,
    required this.volumetricKg,
    required this.chargeableKg,
  });

  bool get isVolumetricBasis => volumetricKg > grossKg;
}

class AirWeightCalculator {
  AirWeightCalculator._();

  static double toCm(double value, String unit) {
    switch (unit.trim().toLowerCase()) {
      case 'mm':
        return value / 10.0;
      case 'm':
        return value * 100.0;
      case 'cm':
      case '':
        return value;
      default:
        throw ArgumentError('Unknown length unit: $unit');
    }
  }

  static double toKg(double value, String unit) {
    switch (unit.trim().toLowerCase()) {
      case 'lb':
      case 'lbs':
        return value * kgPerLb;
      case 'kg':
      case 'kgs':
      case '':
        return value;
      default:
        throw ArgumentError('Unknown weight unit: $unit');
    }
  }

  static double _round(double value, int decimals) {
    final f = math.pow(10, decimals).toDouble();
    return (value * f).roundToDouble() / f;
  }

  /// Volumetric weight of one line; 0 when any dimension, the quantity or the divisor is not positive.
  static double volumetricKg(AirPackageInput p, double divisor) {
    if (divisor <= 0 || p.quantity <= 0) return 0;
    final l = toCm(p.length, p.dimensionUnit);
    final w = toCm(p.width, p.dimensionUnit);
    final h = toCm(p.height, p.dimensionUnit);
    if (l <= 0 || w <= 0 || h <= 0) return 0;
    return l * w * h / divisor * p.quantity;
  }

  static ChargeableWeightPreview calculate(
    List<AirPackageInput> packages, {
    double divisor = 6000,
    double? totalGrossKg,
  }) {
    var pieces = 0;
    var gross = 0.0;
    var volume = 0.0;
    var volumetric = 0.0;
    for (final p in packages) {
      final l = toCm(p.length, p.dimensionUnit);
      final w = toCm(p.width, p.dimensionUnit);
      final h = toCm(p.height, p.dimensionUnit);
      pieces += p.quantity;
      gross += toKg(p.grossWeight, p.weightUnit) * p.quantity;
      volume += l * w * h / 1000000.0 * p.quantity;
      volumetric += volumetricKg(p, divisor);
    }
    if (gross <= 0 && totalGrossKg != null) gross = totalGrossKg;
    final grossR = _round(gross, 2);
    final volR = _round(volumetric, 2);
    return ChargeableWeightPreview(
      pieces: pieces,
      grossKg: grossR,
      volumeCbm: _round(volume, 4),
      volumetricKg: volR,
      chargeableKg: math.max(grossR, volR),
    );
  }
}

/// IATA AWB number check: 3-digit airline prefix + 7-digit serial + check digit (serial mod 7).
class AwbNumber {
  AwbNumber._();

  static String digitsOf(String raw) => raw.replaceAll(RegExp(r'[\s\-./]'), '');

  /// null when valid (or blank); otherwise the backend reason code.
  static String? validationCode(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    final digits = digitsOf(text);
    if (digits.length != 11 || !RegExp(r'^\d{11}$').hasMatch(digits)) return 'AIR_AWB_FORMAT_INVALID';
    final serial = int.parse(digits.substring(3, 10));
    final check = int.parse(digits.substring(10));
    if (serial % 7 != check) return 'AIR_AWB_CHECK_DIGIT_INVALID';
    return null;
  }

  static bool isValid(String? raw) => (raw ?? '').trim().isNotEmpty && validationCode(raw) == null;

  /// `176-12345675` display form of a valid number; the input unchanged otherwise.
  static String format(String raw) {
    final digits = digitsOf(raw);
    return digits.length == 11 ? '${digits.substring(0, 3)}-${digits.substring(3)}' : raw;
  }
}
