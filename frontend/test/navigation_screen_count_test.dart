import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/core/providers/workspace_tabs_provider.dart';
import 'package:frontend/features/home/widgets/home_screen_registry.dart';

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
}
