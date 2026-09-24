import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';

/// Keys required by plan §8 (the dialog also uses a few extra update* keys,
/// which the source scan below covers).
const _planKeys = <String>[
  'updateAvailableBanner',
  'updateMandatoryBanner',
  'updateWhatsNew',
  'updateSize',
  'updateInstallNow',
  'updateRemindLater',
  'updateDownloading',
  'updateVerifying',
  'updateBackingUp',
  'updateInstalling',
  'updateCancel',
  'updateSucceeded',
  'updateFailed',
  'updateRollback',
  'updateRollbackWarning',
  'updateFromFile',
  'updateCheckOffline',
  'updateDevModeDisabled',
];

/// Every getter / method declared in the "In-app updates" section of the
/// abstract class.
List<String> _declaredUpdateKeys() {
  final src = File('lib/core/localization/app_localizations.dart').readAsLinesSync();
  final start = src.indexWhere((l) => l.contains('In-app updates (app_update)'));
  expect(start, greaterThan(0), reason: 'update section missing in app_localizations.dart');
  final decl = RegExp(r'^\s+String (?:get )?(update\w+)');
  final keys = <String>[];
  for (var i = start + 1; i < src.length; i++) {
    if (src[i].startsWith('}')) break;
    final m = decl.firstMatch(src[i]);
    if (m != null) keys.add(m.group(1)!);
  }
  return keys;
}

void main() {
  test('all plan §8 keys are declared', () {
    final declared = _declaredUpdateKeys();
    for (final k in _planKeys) {
      expect(declared, contains(k));
    }
  });

  test('every update key is implemented in ar and en', () {
    final declared = _declaredUpdateKeys();
    for (final file in ['app_localizations_ar.dart', 'app_localizations_en.dart']) {
      final src = File('lib/core/localization/$file').readAsStringSync();
      for (final k in declared) {
        expect(
          RegExp('@override String (get )?$k\\b').hasMatch(src),
          isTrue,
          reason: '$k missing in $file',
        );
      }
    }
  });

  List<String> values(AppLocalizations l) => [
        l.updateAvailableBanner('2.1.0'),
        l.updateMandatoryBanner('2.1.0'),
        l.updateWhatsNew,
        l.updateSize('202.8'),
        l.updateInstallNow,
        l.updateRemindLater,
        l.updateDownloading('1.0', '2.0'),
        l.updateVerifying,
        l.updateBackingUp,
        l.updateInstalling,
        l.updateCancel,
        l.updateSucceeded('2.1.0'),
        l.updateFailed,
        l.updateRollback,
        l.updateRollbackWarning('2026-09-24 10:00'),
        l.updateFromFile,
        l.updateCheckOffline('2026-09-24 10:00'),
        l.updateDevModeDisabled,
        l.updateNoPermission,
      ];

  test('values are non-empty and differ between ar and en', () {
    final ar = values(const AppLocalizationsAr());
    final en = values(const AppLocalizationsEn());
    for (var i = 0; i < ar.length; i++) {
      expect(ar[i].trim(), isNotEmpty);
      expect(en[i].trim(), isNotEmpty);
      expect(ar[i], isNot(en[i]), reason: 'untranslated: ${en[i]}');
    }
  });

  test('parameters are interpolated', () {
    const ar = AppLocalizationsAr();
    const en = AppLocalizationsEn();
    expect(en.updateAvailableBanner('2.1.0'), contains('2.1.0'));
    expect(ar.updateSucceeded('2.1.0'), contains('2.1.0'));
    expect(ar.updateRollbackWarning('2026-09-24 10:00'), contains('2026-09-24 10:00'));
    expect(en.updateCheckOffline('never'), contains('never'));
  });
}
