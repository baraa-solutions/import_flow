import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/system_messages/system_message_catalog_ar.dart';
import 'package:frontend/core/localization/system_messages/system_message_catalog_en.dart';
import 'package:frontend/core/localization/system_messages/system_message_renderer.dart';

/// Contract parity with the backend catalog (docs/system_message_codes.json,
/// generated from modules/common/system_messages.py). When this fails after a
/// backend change, add the new code/part to both Dart catalogs.
void main() {
  final raw = (jsonDecode(File('../docs/system_message_codes.json').readAsStringSync()) as Map)
      .cast<String, dynamic>();
  // Top-level keys starting with '_' are metadata (`_phases`, `_param_rules`), not codes.
  final contract = {
    for (final e in raw.entries)
      if (!e.key.startsWith('_')) e.key: e.value,
  };
  final placeholder = RegExp(r'\{([a-z_][a-z0-9_]*)\}');
  Set<String> paramsOf(String t) => placeholder.allMatches(t).map((m) => m.group(1)!).toSet();

  test('contract is not empty', () => expect(contract.length, greaterThan(200)));

  test('phase titles match `_phases`', () {
    final phases = (raw['_phases'] as Map).cast<String, dynamic>();
    expect(SystemMessageRenderer.phaseTitles.keys.map((k) => '$k').toSet(), phases.keys.toSet());
    phases.forEach((id, title) {
      expect(SystemMessageRenderer.phaseTitle(int.parse(id), isArabic: false), title);
      expect(SystemMessageRenderer.phaseTitle(int.parse(id), isArabic: true), isNotEmpty);
    });
  });

  test('number rules match `_param_rules`', () {
    final rules = (raw['_param_rules'] as Map).cast<String, dynamic>();
    expect(SystemMessageRenderer.numberNames.toSet(), (rules['number_names'] as List).cast<String>().toSet());
    expect(SystemMessageRenderer.numberSuffixes.toSet(), (rules['number_suffixes'] as List).cast<String>().toSet());
    expect(rules['enum_infix'], '_enum_');
    expect(rules['enum_list_separator'], ',');
  });

  for (final entry in {'en': systemMessageCatalogEn, 'ar': systemMessageCatalogAr}.entries) {
    final lang = entry.key;
    final catalog = entry.value;

    test('$lang: same codes as the contract', () {
      expect(catalog.keys.toSet(), contract.keys.toSet());
    });

    test('$lang: every declared part has a template and every declared param is consumed', () {
      final problems = <String>[];
      contract.forEach((code, spec) {
        final parts = ((spec as Map)['parts'] as List).cast<String>().toSet();
        final params = (spec['params'] as List).cast<String>().toSet();
        final templates = catalog[code] ?? const {};
        if (templates.keys.toSet().difference(parts).isNotEmpty || parts.difference(templates.keys.toSet()).isNotEmpty) {
          problems.add('$code parts ${templates.keys} != $parts');
        }
        final used = <String>{};
        for (final part in parts) {
          final t = templates[part];
          if (t == null || t.trim().isEmpty) {
            problems.add('$code.$part missing');
          } else {
            used.addAll(paramsOf(t));
          }
        }
        if (used.difference(params).isNotEmpty) problems.add('$code uses undeclared ${used.difference(params)}');
        if (params.difference(used).isNotEmpty) problems.add('$code does not consume ${params.difference(used)}');
      });
      expect(problems, isEmpty);
    });
  }

  test('ar and en templates of each part use the same placeholders', () {
    final problems = <String>[];
    systemMessageCatalogEn.forEach((code, parts) {
      parts.forEach((part, en) {
        final ar = systemMessageCatalogAr[code]?[part];
        if (ar == null || !_sameSet(paramsOf(en), paramsOf(ar))) problems.add('$code.$part');
      });
    });
    expect(problems, isEmpty);
  });

  test('Arabic templates are Arabic', () {
    final arabic = RegExp('[؀-ۿ]');
    final latinOnly = <String>[];
    systemMessageCatalogAr.forEach((code, parts) {
      parts.forEach((part, t) {
        final withoutParams = t.replaceAll(placeholder, '').replaceAll(RegExp(r'[\s\[\]\-—:()]'), '');
        if (withoutParams.isNotEmpty && !arabic.hasMatch(t)) latinOnly.add('$code.$part');
      });
    });
    expect(latinOnly, isEmpty);
  });
}

bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
