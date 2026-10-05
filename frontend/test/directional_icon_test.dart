import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/directional_icon.dart';

/// Net visual mirroring of the glyph = manual Transform flip XOR the flip
/// [Icon] itself applies for `matchTextDirection` glyphs in RTL.
/// Transforms DirectionalIcon wraps around its Icon (Icon's own internal
/// Transform for matchTextDirection glyphs sits below the Icon, not above).
Finder _manualTransformFinder() => find.descendant(
      of: find.byType(DirectionalIcon),
      matching: find.ancestor(of: find.byType(Icon), matching: find.byType(Transform)),
    );

bool _isVisuallyMirrored(WidgetTester tester, TextDirection direction) {
  final root = find.byType(DirectionalIcon);
  final manualFlip = _manualTransformFinder().evaluate().any((e) {
    final t = e.widget as Transform;
    return t.transform.storage[0] == -1.0;
  });
  final icon = tester.widget<Icon>(find.descendant(of: root, matching: find.byType(Icon)));
  final autoFlip = direction == TextDirection.rtl && icon.icon!.matchTextDirection;
  return manualFlip != autoFlip;
}

Future<bool> _pump(WidgetTester tester, Widget icon, TextDirection direction) async {
  await tester.pumpWidget(MaterialApp(
    home: Directionality(textDirection: direction, child: Center(child: icon)),
  ));
  return _isVisuallyMirrored(tester, direction);
}

int _manualTransforms(WidgetTester tester) => _manualTransformFinder().evaluate().length;

void main() {
  group('DirectionalIcon: matchTextDirection glyphs are flipped once (by Icon)', () {
    const autoMirrored = <IconData>[
      Icons.arrow_forward,
      Icons.arrow_back,
      Icons.arrow_forward_ios,
      Icons.chevron_left,
      Icons.chevron_right,
      Icons.navigate_next,
      Icons.first_page,
      Icons.last_page,
      Icons.arrow_right_alt,
    ];

    for (final icon in autoMirrored) {
      testWidgets('${icon.codePoint.toRadixString(16)} mirrored in RTL, no manual Transform',
          (tester) async {
        expect(icon.matchTextDirection, isTrue);
        expect(await _pump(tester, DirectionalIcon(icon), TextDirection.rtl), isTrue);
        expect(_manualTransforms(tester), 0, reason: 'a Transform here would double-flip');

        expect(await _pump(tester, DirectionalIcon(icon), TextDirection.ltr), isFalse);
      });
    }
  });

  group('DirectionalIcon: keyboard / double arrows are flipped manually', () {
    const manual = <IconData>[
      Icons.keyboard_arrow_left,
      Icons.keyboard_arrow_right,
      Icons.keyboard_double_arrow_left,
      Icons.keyboard_double_arrow_right,
      Icons.keyboard_double_arrow_left_rounded,
      Icons.double_arrow,
      Icons.menu_open_rounded,
    ];

    for (final icon in manual) {
      testWidgets('${icon.codePoint.toRadixString(16)} mirrored in RTL only', (tester) async {
        expect(icon.matchTextDirection, isFalse);
        expect(await _pump(tester, DirectionalIcon(icon), TextDirection.rtl), isTrue);
        expect(await _pump(tester, DirectionalIcon(icon), TextDirection.ltr), isFalse);
      });
    }
  });

  group('DirectionalIcon: other icons and forceMirror', () {
    testWidgets('non-directional icon never mirrors', (tester) async {
      expect(await _pump(tester, const DirectionalIcon(Icons.search), TextDirection.rtl), isFalse);
      expect(_manualTransforms(tester), 0);
    });

    testWidgets('forceMirror: false keeps an auto-mirrored glyph unmirrored in RTL', (tester) async {
      expect(
        await _pump(tester, const DirectionalIcon(Icons.arrow_forward, forceMirror: false), TextDirection.rtl),
        isFalse,
      );
    });

    testWidgets('forceMirror: true mirrors a plain icon in LTR and does not double-flip in RTL',
        (tester) async {
      expect(await _pump(tester, const DirectionalIcon(Icons.search, forceMirror: true), TextDirection.ltr),
          isTrue);
      expect(
        await _pump(tester, const DirectionalIcon(Icons.arrow_forward, forceMirror: true), TextDirection.rtl),
        isTrue,
      );
    });

    test('isDirectionalIcon covers both families', () {
      expect(isDirectionalIcon(Icons.chevron_right), isTrue);
      expect(isDirectionalIcon(Icons.keyboard_double_arrow_left), isTrue);
      expect(isDirectionalIcon(Icons.search), isFalse);
    });
  });

  group('DirectionalArrow', () {
    testWidgets('points left in RTL and right in LTR', (tester) async {
      Future<String> arrowFor(TextDirection d) async {
        await tester.pumpWidget(MaterialApp(
          home: Directionality(textDirection: d, child: const DirectionalArrow()),
        ));
        return tester.widget<Text>(find.byType(Text)).data!;
      }

      expect(await arrowFor(TextDirection.rtl), '←');
      expect(await arrowFor(TextDirection.ltr), '→');
    });
  });
}
