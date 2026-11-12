// WCAG AA contrast guard for the core design-system tokens (Trello Ae1dLVE8).
//
// Every text/background pair the theme and AppButton produce must reach
// 4.5:1 (normal text) in both the light and the dark theme.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';

const double _aa = 4.5;

double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double lighter = la > lb ? la : lb;
  final double darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Composites a translucent [fg] over an opaque [bg].
Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

void expectAA(Color fg, Color bg, String label) {
  final double ratio = contrastRatio(fg, bg);
  expect(ratio, greaterThanOrEqualTo(_aa),
      reason: '$label: ${_hex(fg)} on ${_hex(bg)} = '
          '${ratio.toStringAsFixed(2)}:1 (< 4.5:1)');
}

const Map<String, Color> _lightSurfaces = {
  'white': AppTheme.surface,
  'cloudWhite': AppTheme.cloudWhite,
  'surfaceAlt': AppTheme.surfaceAlt,
};

const Map<String, Color> _darkSurfaces = {
  'scaffold': AppTheme.darkScaffoldBackground,
  'surface': AppTheme.darkSurface,
  'card': AppTheme.darkCardBackground,
  'elevated(dialog)': AppTheme.darkElevatedSurface,
  'input': AppTheme.darkInputBackground,
};

void main() {
  group('contrastRatio helper', () {
    test('black on white is 21:1 and is symmetric', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrastRatio(Colors.white, Colors.black), closeTo(21, 0.01));
    });

    test('flags the legacy failing pairs from the audit', () {
      // Evidence from the card: these must stay < 4.5 so the helper is honest.
      expect(contrastRatio(Colors.white, AppTheme.cobalt), lessThan(_aa));
      expect(contrastRatio(Colors.white, AppTheme.emerald), lessThan(_aa));
      expect(contrastRatio(const Color(0xFF9E9E9E), Colors.white), lessThan(_aa));
    });
  });

  group('Light text tokens', () {
    for (final entry in _lightSurfaces.entries) {
      test('text tokens on ${entry.key}', () {
        expectAA(AppTheme.textPrimary, entry.value, 'textPrimary');
        expectAA(AppTheme.textSecondary, entry.value, 'textSecondary');
        expectAA(AppTheme.textStrong, entry.value, 'textStrong');
        expectAA(AppTheme.textCaption, entry.value, 'textCaption');
        expectAA(AppTheme.textMuted, entry.value, 'textMuted');
        expectAA(AppTheme.wcagCobalt, entry.value, 'wcagCobalt text');
        expectAA(AppTheme.wcagEmerald, entry.value, 'wcagEmerald text');
        expectAA(AppTheme.wcagOrange, entry.value, 'wcagOrange text');
        expectAA(AppTheme.wcagCrimson, entry.value, 'wcagCrimson text');
      });
    }

    test('hintColor is a separate, placeholder-only token', () {
      expect(AppTheme.hintColor, isNot(equals(AppTheme.textMuted)));
    });
  });

  group('Dark text tokens', () {
    for (final entry in _darkSurfaces.entries) {
      test('text tokens on dark ${entry.key}', () {
        expectAA(AppTheme.darkTextPrimary, entry.value, 'darkTextPrimary');
        expectAA(AppTheme.darkTextSecondary, entry.value, 'darkTextSecondary');
        expectAA(AppTheme.darkTextMuted, entry.value, 'darkTextMuted');
        expectAA(AppTheme.darkHyperlink, entry.value, 'darkHyperlink');
        expectAA(AppTheme.darkEmeraldText, entry.value, 'darkEmeraldText');
        expectAA(AppTheme.darkOrangeText, entry.value, 'darkOrangeText');
        expectAA(AppTheme.darkCrimsonText, entry.value, 'darkCrimsonText');
      });
    }
  });

  group('Severity foreground on its own tint', () {
    for (final dark in [false, true]) {
      for (final severity in AppSeverity.values) {
        test('${severity.name} (${dark ? 'dark' : 'light'})', () {
          expectAA(
            AppTheme.severityColor(severity, dark: dark),
            AppTheme.severityBackground(severity, dark: dark),
            'severity ${severity.name}',
          );
        });
      }
    }
  });

  group('Theme button / input styles', () {
    for (final dark in [false, true]) {
      final String mode = dark ? 'dark' : 'light';
      final ThemeData theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
      final Map<String, Color> surfaces = dark ? _darkSurfaces : _lightSurfaces;

      test('ElevatedButton + FilledButton text on fill ($mode)', () {
        final ButtonStyle elevated = theme.elevatedButtonTheme.style!;
        final ButtonStyle filled = theme.filledButtonTheme.style!;
        expectAA(elevated.foregroundColor!.resolve({})!,
            elevated.backgroundColor!.resolve({})!, 'ElevatedButton');
        expectAA(filled.foregroundColor!.resolve({})!,
            filled.backgroundColor!.resolve({})!, 'FilledButton');
      });

      test('TextButton / OutlinedButton / tabs on surfaces ($mode)', () {
        final Color textFg =
            theme.textButtonTheme.style!.foregroundColor!.resolve({})!;
        final Color outlinedFg =
            theme.outlinedButtonTheme.style!.foregroundColor!.resolve({})!;
        for (final s in surfaces.entries) {
          expectAA(textFg, s.value, 'TextButton on ${s.key}');
          expectAA(outlinedFg, s.value, 'OutlinedButton on ${s.key}');
          expectAA(theme.tabBarTheme.labelColor!, s.value, 'Tab label on ${s.key}');
          expectAA(theme.tabBarTheme.unselectedLabelColor!, s.value,
              'Tab unselected on ${s.key}');
        }
      });

      test('Input labels on input fill ($mode)', () {
        final InputDecorationThemeData input = theme.inputDecorationTheme;
        final Color fill = input.fillColor!;
        expectAA(input.labelStyle!.color!, fill, 'labelStyle');
        expectAA(input.floatingLabelStyle!.color!, fill, 'floatingLabelStyle');
        expectAA(input.helperStyle!.color!, fill, 'helperStyle');
      });
    }
  });

  group('AppButton variants', () {
    Future<({Color bg, Color fg})> resolveButton(
      WidgetTester tester,
      AppButtonVariant variant, {
      required bool dark,
    }) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          body: Center(
            child: AppButton(label: 'Save', variant: variant, onPressed: () {}),
          ),
        ),
      ));
      final ElevatedButton button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final Text label = tester.widget<Text>(find.text('Save'));
      return (
        bg: button.style!.backgroundColor!.resolve(<WidgetState>{})!,
        fg: label.style!.color!,
      );
    }

    for (final dark in [false, true]) {
      for (final variant in AppButtonVariant.values) {
        testWidgets('${variant.name} (${dark ? 'dark' : 'light'})',
            (tester) async {
          final r = await resolveButton(tester, variant, dark: dark);
          final Map<String, Color> surfaces =
              dark ? _darkSurfaces : _lightSurfaces;
          if (r.bg.a == 1.0) {
            expectAA(r.fg, r.bg, 'AppButton.${variant.name}');
          } else {
            // Transparent / tinted fills: check against every parent surface.
            for (final s in surfaces.entries) {
              expectAA(r.fg, over(r.bg, s.value),
                  'AppButton.${variant.name} over ${s.key}');
            }
          }
        });
      }
    }

    testWidgets('filled variants use the WCAG fills, not the flat brand tones',
        (tester) async {
      final primary = await resolveButton(tester, AppButtonVariant.primary, dark: false);
      final success = await resolveButton(tester, AppButtonVariant.success, dark: false);
      final warning = await resolveButton(tester, AppButtonVariant.warning, dark: false);
      expect(primary.bg, AppTheme.wcagCobalt);
      expect(success.bg, AppTheme.wcagEmerald);
      expect(warning.bg, AppTheme.wcagOrange);
    });
  });

  group('Adaptive accent text helpers', () {
    for (final dark in [false, true]) {
      testWidgets('cobalt/emerald/orange/crimson TextOf (${dark ? 'dark' : 'light'})',
          (tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ));
        final Map<String, Color> surfaces = dark ? _darkSurfaces : _lightSurfaces;
        for (final s in surfaces.entries) {
          expectAA(AppTheme.cobaltTextOf(ctx), s.value, 'cobaltTextOf ${s.key}');
          expectAA(AppTheme.emeraldTextOf(ctx), s.value, 'emeraldTextOf ${s.key}');
          expectAA(AppTheme.orangeTextOf(ctx), s.value, 'orangeTextOf ${s.key}');
          expectAA(AppTheme.crimsonTextOf(ctx), s.value, 'crimsonTextOf ${s.key}');
          expectAA(AppTheme.textSecondaryOf(ctx), s.value, 'textSecondaryOf ${s.key}');
          expectAA(AppTheme.textMutedOf(ctx), s.value, 'textMutedOf ${s.key}');
        }
      });
    }
  });
}
