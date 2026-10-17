import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/density_provider.dart';

void main() {
  group('DisplayDensityMode.byDensity', () {
    test('picks the value for each mode', () {
      expect(DisplayDensityMode.comfortable.byDensity('c', 'k', 'u'), 'c');
      expect(DisplayDensityMode.compact.byDensity('c', 'k', 'u'), 'k');
      expect(DisplayDensityMode.ultraCompact.byDensity('c', 'k', 'u'), 'u');
    });

    test('matches the inline `isUltraCompact ? a : (isCompact ? b : c)` pattern for every mode', () {
      for (final mode in DisplayDensityMode.values) {
        final legacy = mode.isUltraCompact ? 10.0 : (mode.isCompact ? 12.0 : 16.0);
        expect(mode.byDensity<double>(16, 12, 10), legacy, reason: mode.name);
      }
    });
  });
}
