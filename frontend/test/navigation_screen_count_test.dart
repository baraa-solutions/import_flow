import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/command_palette_registry.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/core/providers/workspace_tabs_provider.dart';
import 'package:frontend/features/home/widgets/home_screen_registry.dart';
import 'package:frontend/features/home/widgets/multi_tab_workspace_bar.dart';

/// Every literal screen index the app navigates to: sidebar items and selectNavigationIndex calls.
Set<int> _navigatedIndices() {
  final pattern = RegExp(
    r"_buildMenuItem\(ref,\s*Icons\.\w+,\s*'[^']*',\s*'[^']*',\s*(\d+)\)|selectNavigationIndex\(\s*ref,\s*(\d+)",
  );
  final indices = <int>{};
  for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    for (final match in pattern.allMatches(file.readAsStringSync())) {
      indices.add(int.parse(match.group(1) ?? match.group(2)!));
    }
  }
  return indices;
}

void main() {
  // selectNavigationIndex silently ignores indices >= kTotalScreens: screens 72–87 (master items
  // catalog, price trends, expense catalog, waves 1–4 …) never opened when it was left at 72.
  test('kTotalScreens covers every screen in the home registry', () {
    expect(kTotalScreens, kHomeScreenRegistry.length);
  });

  test('every navigated screen index exists in the home registry', () {
    final indices = _navigatedIndices();
    expect(indices, isNotEmpty);
    final outOfRange = indices.where((i) => i < 0 || i >= kHomeScreenRegistry.length).toList()..sort();
    expect(outOfRange, isEmpty);
  });

  test('the last registry screens open and get their own tab title', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    for (final index in [72, 76, 77, kHomeScreenRegistry.length - 1]) {
      selectNavigationIndex(container, index);
      expect(container.read(navigationIndexProvider), index);
      final tab = container.read(workspaceTabsProvider).activeTab!;
      expect(tab.routeIndex, index);
      expect(tab.title, isNot(startsWith('شاشة ')));
    }
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('screens 72–87 have a ${locale.languageCode} workspace tab title and a Ctrl+K entry',
        (tester) async {
      late List<CommandPaletteItem> items;
      late List<String> titles;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AppLocalizationsProvider(
              locale: locale,
              child: Consumer(
                builder: (context, ref, _) {
                  items = CommandPaletteRegistry.getItems(context, ref);
                  titles = [
                    for (var i = 72; i < kHomeScreenRegistry.length; i++)
                      getLocalizedTabTitle(context, i, '__fallback__'),
                  ];
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(titles, isNot(contains('__fallback__')));

      final ids = items.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'command palette ids must be unique');
      final routes = items.map((i) => i.routeIndex).whereType<int>().toSet();
      expect(routes.where((r) => r < 0 || r >= kHomeScreenRegistry.length), isEmpty);
      for (var i = 72; i < kHomeScreenRegistry.length; i++) {
        expect(routes, contains(i), reason: 'screen $i is missing from Ctrl+K');
      }
      // The GIT ledger is tab 0 of the inbound hub (57); 63 is the import requirements matrix.
      expect(items.firstWhere((i) => i.id == 'screen_git_ledger').routeIndex, 57);
    });
  }
}
