import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratchet guard: values sent to the backend must not depend on the UI language.
///
/// docs/plans/single-language-storage-plan.md (Phase C). Stored values are codes
/// or English; an Arabic session and an English session must send the same
/// payload. This test scans lib/ for *payload regions* and flags locale-dependent
/// expressions inside them.
///
/// Payload regions (found on a comment-stripped, string-masked copy of the file):
///  * `data: {..}` / `queryParameters: {..}` / `body: {..}` / `payload: {..}` /
///    `json: {..}` named arguments (also `data: jsonEncode({..})`);
///  * `toJson(...)` bodies (block or `=>` form);
///  * map literals assigned to a payload-like variable
///    (`payload`, `body`, `data`, `request`, `params`, `json`, `fields`, `updates`)
///    and `payload['key'] = ...;` index writes;
///  * any other map literal with at least one `'snake_case_key':` entry (API shape),
///    unless every entry value is a label (a code -> label display map);
///  * assignments to a `*suffix*` variable (clone suffixes).
///
/// Flagged inside a region: `isAr ?` / `isArabic ?` / `isRtl ?` conditionals,
/// `Localizations.localeOf(`, `Directionality.of(`, `context.l10n.x` / `l10n.x` /
/// file-local l10n aliases (`final l = context.l10n;`) / `AppLocalizations.of(..).x`,
/// and Arabic string literals. `storedText.x` (English, stored defaults) and
/// `DomainEnums.*` codes are fine; so are `l10n.isArabic` reads that are not
/// conditionals.
///
/// Not scanned: lib/core/localization/ (the catalogs themselves) and
/// export/pdf/print code (files, not API payloads).
///
/// Legacy counts live in test/no_locale_dependent_payload_baseline.json (per
/// file). A file may not exceed its baseline; a new file starts at 0; when you
/// remove a site, lower the baseline (the test fails until you do). Regenerate:
///   UPDATE_LOCALE_PAYLOAD_BASELINE=1 flutter test test/no_locale_dependent_payload_test.dart
/// List every flagged site:
///   DUMP_LOCALE_PAYLOAD_SITES=1 flutter test test/no_locale_dependent_payload_test.dart
const _baselinePath = 'test/no_locale_dependent_payload_baseline.json';

// ---------------------------------------------------------------------------
// Lexer: blank comments, mask string contents (keep interpolation code).
// ---------------------------------------------------------------------------

class _StrLit {
  _StrLit(this.start, this.end, this.arabic);
  final int start;
  final int end;
  final bool arabic;
}

class _Lexed {
  _Lexed(this.masked, this.strings);
  final String masked;
  final List<_StrLit> strings;
}

bool _isArabicUnit(int c) => c >= 0x0600 && c <= 0x06FF;
bool _isIdentUnit(int c) =>
    (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F || c == 0x24;

_Lexed _lex(String src) {
  final out = src.codeUnits.toList();
  final strings = <_StrLit>[];
  final n = src.length;
  const space = 0x20, nl = 0x0A, x = 0x78;

  late int Function(int, bool) code;

  int str(int i) {
    final start = i;
    var raw = false;
    if (src.codeUnitAt(i) == 0x72 /* r */) {
      raw = true;
      i++;
    }
    final q = src[i];
    final triple = src.startsWith('$q$q$q', i);
    final delim = triple ? '$q$q$q' : q;
    i += delim.length;
    var arabic = false;
    while (i < n) {
      final c = src.codeUnitAt(i);
      if (!raw && c == 0x5C /* \ */ && i + 1 < n) {
        out[i] = x;
        if (src.codeUnitAt(i + 1) != nl) out[i + 1] = x;
        i += 2;
        continue;
      }
      if (src.startsWith(delim, i)) {
        i += delim.length;
        break;
      }
      if (!raw && c == 0x24 /* $ */ && i + 1 < n && src.codeUnitAt(i + 1) == 0x7B /* { */) {
        i = code(i + 2, true); // i -> closing }
        i++;
        continue;
      }
      if (c == nl) {
        if (!triple) break; // unterminated: stop at end of line
        i++;
        continue;
      }
      if (_isArabicUnit(c)) arabic = true;
      out[i] = x;
      i++;
    }
    strings.add(_StrLit(start, i, arabic));
    return i;
  }

  code = (int i, bool untilBrace) {
    var depth = 0;
    while (i < n) {
      final c = src.codeUnitAt(i);
      final next = i + 1 < n ? src.codeUnitAt(i + 1) : 0;
      if (c == 0x2F /* / */ && next == 0x2F) {
        while (i < n && src.codeUnitAt(i) != nl) {
          out[i] = space;
          i++;
        }
        continue;
      }
      if (c == 0x2F && next == 0x2A /* * */) {
        while (i < n && !src.startsWith('*/', i)) {
          if (src.codeUnitAt(i) != nl) out[i] = space;
          i++;
        }
        if (i < n) {
          out[i] = space;
          out[i + 1] = space;
          i += 2;
        }
        continue;
      }
      final prevIdent = i > 0 && _isIdentUnit(src.codeUnitAt(i - 1));
      if (c == 0x27 || c == 0x22) {
        i = str(i);
        continue;
      }
      if (c == 0x72 && (next == 0x27 || next == 0x22) && !prevIdent) {
        i = str(i);
        continue;
      }
      if (untilBrace) {
        if (c == 0x7B) depth++;
        if (c == 0x7D) {
          if (depth == 0) return i;
          depth--;
        }
      }
      i++;
    }
    return i;
  };

  code(0, false);
  return _Lexed(String.fromCharCodes(out), strings);
}

// ---------------------------------------------------------------------------
// Regions
// ---------------------------------------------------------------------------

const _open = {0x28: 0x29, 0x5B: 0x5D, 0x7B: 0x7D}; // ( [ {

/// Index of the bracket matching the one at [i] (or text end).
int _matchBracket(String m, int i) {
  var depth = 0;
  for (var j = i; j < m.length; j++) {
    final c = m.codeUnitAt(j);
    if (_open.containsKey(c)) depth++;
    if (_open.containsValue(c)) {
      depth--;
      if (depth == 0) return j;
    }
  }
  return m.length - 1;
}

/// End of the expression/statement starting at [i]: first `;` (or unmatched
/// closer) at bracket depth 0.
int _statementEnd(String m, int i) {
  var depth = 0;
  for (var j = i; j < m.length; j++) {
    final c = m.codeUnitAt(j);
    if (_open.containsKey(c)) depth++;
    if (_open.containsValue(c)) {
      if (depth == 0) return j;
      depth--;
    }
    if (c == 0x3B /* ; */ && depth == 0) return j;
  }
  return m.length;
}

class _Region {
  _Region(this.start, this.end);
  final int start;
  final int end;
}

final _namedArgMap = RegExp(
    r'\b(data|queryParameters|body|payload|json)\s*:\s*(jsonEncode\(\s*)?(<[^<>{};]*>\s*)?\{');
final _toJson = RegExp(r'\btoJson\s*\([^)]*\)\s*(\{|=>)');
final _payloadVarMap = RegExp(
    r'\b\w*(payload|Payload|body|Body|(?<!meta)data|Data|request|Request|params|Params|json|Json|fields|Fields|updates|Updates)\s*=\s*(<[^<>{};]*>\s*)?\{');
final _payloadIndexWrite = RegExp(
    r'\b\w*(payload|Payload|body|Body|data|Data|request|Request|params|Params|json|Json|fields|Fields|updates|Updates)\s*\[[^\]]+\]\s*=(?!=)');
final _suffixAssign = RegExp(r'\b\w*[sS]uffix\w*\s*=(?![=>])');
final _quotes = RegExp('^r?[\'"]+|[\'"]+\$');
String _unquote(String literal) => literal.replaceAll(_quotes, '');
final _snakeKey = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)+$');

/// Map literals with at least one snake_case key, skipping code -> label maps.
Iterable<_Region> _snakeKeyMaps(String src, _Lexed lx, bool Function(String) isLabelValue) sync* {
  final m = lx.masked;
  final strByStart = {for (final s in lx.strings) s.start: s};
  for (var i = 0; i < m.length; i++) {
    if (m.codeUnitAt(i) != 0x7B) continue;
    if (i > 0 && m.codeUnitAt(i - 1) == 0x24) continue; // ${ interpolation
    final end = _matchBracket(m, i);
    // Walk depth-1 entries.
    var j = i + 1;
    var entries = 0;
    var labelValues = 0;
    var snake = false;
    var isMap = true;
    while (j < end) {
      while (j < end && (m.codeUnitAt(j) <= 0x20 || m.codeUnitAt(j) == 0x2C)) {
        j++;
      }
      if (j >= end) break;
      final s = strByStart[j];
      if (s == null) {
        // Not a string key (spread, if/for element, identifier key): skip entry.
        final e = _entryEnd(m, j, end);
        if (e == j) break;
        j = e;
        continue;
      }
      var k = s.end;
      while (k < end && m.codeUnitAt(k) <= 0x20) {
        k++;
      }
      if (k >= end || m.codeUnitAt(k) != 0x3A /* : */) {
        isMap = false;
        break;
      }
      final keyText = _unquote(src.substring(s.start, s.end));
      if (_snakeKey.hasMatch(keyText)) snake = true;
      final vEnd = _entryEnd(m, k + 1, end);
      entries++;
      if (isLabelValue(src.substring(k + 1, vEnd).trim())) labelValues++;
      j = vEnd;
    }
    if (!isMap || !snake || entries == 0) continue;
    if (labelValues == entries) continue; // code -> label display map
    yield _Region(i, end);
  }
}

/// End of one collection entry starting at [j]: next `,` at depth 0 or [limit].
int _entryEnd(String m, int j, int limit) {
  var depth = 0;
  for (var k = j; k < limit; k++) {
    final c = m.codeUnitAt(k);
    if (_open.containsKey(c)) depth++;
    if (_open.containsValue(c)) depth--;
    if (c == 0x2C && depth == 0) return k;
  }
  return limit;
}

// ---------------------------------------------------------------------------
// Scanner
// ---------------------------------------------------------------------------

class _Site {
  _Site(this.offset, this.kind);
  final int offset;
  final String kind;
}

final _aliasDecl = RegExp(
    r'\b(?:final|var|const)\s+(?:AppLocalizations\s+)?(\w+)\s*=\s*(?:context\.l10n|AppLocalizations\.of\([^)]*\)!?|widget\.l10n)\s*;');
final _fixedPatterns = <String, RegExp>{
  'isAr ?': RegExp(r'(?<![\w.])(?:\w+\.)?_?is(?:Ar|Arabic|Rtl)\s*\?(?![?.\[])'),
  'Localizations.localeOf': RegExp(r'\bLocalizations\.localeOf\('),
  'Directionality.of': RegExp(r'\bDirectionality\.of\('),
  'AppLocalizations.of': RegExp(r'\bAppLocalizations\.of\([^)]*\)!?\.(?!isArabic\b)[A-Za-z_]'),
};

RegExp _l10nPattern(Set<String> names) {
  final alt = names.map(RegExp.escape).join('|');
  return RegExp('(?<![\\w.])(?:context\\.|widget\\.)?(?:$alt)\\.(?!isArabic\\b|localeName\\b)[A-Za-z_]');
}

bool _skipFile(String rel) {
  final lower = rel.toLowerCase();
  if (lower.startsWith('lib/core/localization/')) return true;
  return lower.contains('export') || lower.contains('pdf') || lower.contains('print');
}

List<_Site> _scanSource(String src) {
  final lx = _lex(src);
  final m = lx.masked;
  final names = <String>{'l10n'};
  for (final a in _aliasDecl.allMatches(m)) {
    names.add(a.group(1)!);
  }
  final l10nRe = _l10nPattern(names);
  bool isLabelValue(String v) {
    final t = v.trimLeft();
    return l10nRe.matchAsPrefix(t) != null ||
        _fixedPatterns['AppLocalizations.of']!.matchAsPrefix(t) != null ||
        t.startsWith('DomainEnums.label(') ||
        ((t.startsWith("'") || t.startsWith('"')) && t.runes.any(_isArabicUnit));
  }

  final regions = <_Region>[];
  for (final r in _namedArgMap.allMatches(m)) {
    final b = r.end - 1;
    regions.add(_Region(b, _matchBracket(m, b)));
  }
  for (final r in _toJson.allMatches(m)) {
    if (r.group(1) == '{') {
      final b = r.end - 1;
      regions.add(_Region(b, _matchBracket(m, b)));
    } else {
      regions.add(_Region(r.end, _statementEnd(m, r.end)));
    }
  }
  for (final r in _payloadVarMap.allMatches(m)) {
    final b = r.end - 1;
    regions.add(_Region(b, _matchBracket(m, b)));
  }
  for (final r in [..._payloadIndexWrite.allMatches(m), ..._suffixAssign.allMatches(m)]) {
    regions.add(_Region(r.end, _statementEnd(m, r.end)));
  }
  regions.addAll(_snakeKeyMaps(src, lx, isLabelValue));

  // Bilingual fields (`'name_ar': ...`) are Arabic on purpose.
  final arValues = <_Region>[];
  for (final s in lx.strings) {
    final key = _unquote(src.substring(s.start, s.end));
    if (!_arKey.hasMatch(key)) continue;
    var k = s.end;
    while (k < m.length && m.codeUnitAt(k) <= 0x20) {
      k++;
    }
    if (k < m.length && m.codeUnitAt(k) == 0x3A) arValues.add(_Region(k, _valueEnd(m, k + 1)));
  }
  bool inArValue(int offset) => arValues.any((r) => offset >= r.start && offset < r.end);

  final sites = <int, _Site>{};
  for (final region in regions) {
    final text = m.substring(region.start, region.end);
    void add(Iterable<Match> ms, String kind) {
      for (final hit in ms) {
        sites.putIfAbsent(region.start + hit.start, () => _Site(region.start + hit.start, kind));
      }
    }

    _fixedPatterns.forEach((kind, re) => add(re.allMatches(text), kind));
    add(l10nRe.allMatches(text), 'l10n.');
    for (final s in lx.strings) {
      if (s.arabic && s.start >= region.start && s.start < region.end && !_isComparison(m, s)) {
        sites.putIfAbsent(s.start, () => _Site(s.start, 'Arabic literal'));
      }
    }
  }
  return sites.values.where((s) => !inArValue(s.offset)).toList()..sort((a, b) => a.offset.compareTo(b.offset));
}

final _arKey = RegExp(r'(_ar|Ar)$');

/// End of a map-entry value starting at [i]: `,` / `;` or unmatched closer at depth 0.
int _valueEnd(String m, int i) {
  var depth = 0;
  for (var j = i; j < m.length; j++) {
    final c = m.codeUnitAt(j);
    if (_open.containsKey(c)) depth++;
    if (_open.containsValue(c)) {
      if (depth == 0) return j;
      depth--;
    }
    if ((c == 0x2C || c == 0x3B) && depth == 0) return j;
  }
  return m.length;
}

/// Arabic literal used to match input (`x.contains('..')`, `x == '..'`), not sent.
bool _isComparison(String m, _StrLit s) {
  final before = m.substring(0, s.start).trimRight();
  final after = m.substring(s.end).trimLeft();
  return RegExp(r'(\.(contains|startsWith|endsWith)\(|[=!]=)$').hasMatch(before) ||
      after.startsWith('==') ||
      after.startsWith('!=');
}

int _lineOf(String src, int offset) => '\n'.allMatches(src.substring(0, offset)).length + 1;

Map<String, List<String>> _scanLib() {
  final result = <String, List<String>>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final rel = f.path.replaceAll(r'\', '/');
    if (_skipFile(rel)) continue;
    final src = f.readAsStringSync();
    final sites = _scanSource(src);
    if (sites.isEmpty) continue;
    final lines = src.split('\n');
    result[rel] = [
      for (final s in sites)
        () {
          final ln = _lineOf(src, s.offset);
          return '$rel:$ln [${s.kind}] ${lines[ln - 1].trim()}';
        }(),
    ];
  }
  return result;
}

void main() {
  test('locale-dependent values in API payloads do not grow beyond the per-file baseline', () {
    expect(Directory('lib').existsSync(), isTrue, reason: 'run from the frontend/ directory');
    final scanned = _scanLib();
    final current = scanned.map((k, v) => MapEntry(k, v.length));
    final file = File(_baselinePath);

    if (Platform.environment['DUMP_LOCALE_PAYLOAD_SITES'] == '1') {
      // ignore: avoid_print
      print(scanned.values.expand((v) => v).join('\n'));
    }
    if (Platform.environment['UPDATE_LOCALE_PAYLOAD_BASELINE'] == '1') {
      file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(current)}\n');
      return;
    }

    final baseline = (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));

    final grown = <String>[];
    final shrunk = <String>[];
    for (final e in current.entries) {
      final allowed = baseline[e.key] ?? 0;
      if (e.value > allowed) {
        grown.add('${e.key}: ${e.value} (baseline $allowed)\n  ${scanned[e.key]!.join('\n  ')}');
      }
      if (e.value < allowed) shrunk.add('${e.key}: ${e.value} (baseline $allowed)');
    }
    for (final e in baseline.entries) {
      if (!current.containsKey(e.key) && e.value > 0) shrunk.add('${e.key}: 0 (baseline ${e.value})');
    }

    expect(grown, isEmpty,
        reason: 'A request payload depends on the UI language. Send a code (DomainEnums) or an '
            'English default (storedText), never context.l10n / isAr ? / Arabic text:\n${grown.join('\n')}');
    expect(shrunk, isEmpty,
        reason: 'Sites were removed - lower the baseline in $_baselinePath '
            '(or run with UPDATE_LOCALE_PAYLOAD_BASELINE=1):\n${shrunk.join('\n')}');
  });

  group('scanner', () {
    List<String> kinds(String code) => _scanSource(code).map((s) => s.kind).toList();

    test('flags locale-dependent values inside payload regions', () {
      expect(kinds("dio.post('/x', data: {'title': context.l10n.defaultTitle});"), ['l10n.']);
      expect(kinds("dio.post('/x', data: {'note': isAr ? 'a' : 'b'});"), ['isAr ?']);
      expect(kinds("dio.put('/x', data: {'name': 'نسخة'});"), ['Arabic literal']);
      expect(kinds("dio.get('/x', queryParameters: {'lang': Localizations.localeOf(context)});"),
          ['Localizations.localeOf']);
      expect(kinds("dio.patch('/x', data: jsonEncode({'dir': Directionality.of(context)}));"),
          ['Directionality.of']);
      expect(kinds('Map<String, dynamic> toJson() => {\'t\': l10n.x};'), ['l10n.']);
      expect(kinds('Map<String, dynamic> toJson() {\n  return {\'t\': AppLocalizations.of(ctx)!.x};\n}'),
          ['AppLocalizations.of']);
      expect(kinds("final l = context.l10n;\nfinal payload = {'title': l.defaultTitle};"), ['l10n.']);
      expect(kinds("body['remarks'] = l10n.autoNote;"), ['l10n.']);
      expect(kinds("final copySuffix = l10n.isArabic ? ' (نسخة)' : ' (Copy)';"), ['isAr ?', 'Arabic literal']);
      expect(kinds("repo.save({'file_id': id, 'stage_name': l10n.stageTitle});"), ['l10n.']);
      expect(kinds("final p = {'stage_note': '\${l10n.prefix} \$code'};"), ['l10n.']);
    });

    test('ignores UI text, stored English defaults, codes and comments', () {
      expect(kinds("Text(context.l10n.save)"), isEmpty);
      expect(kinds("showSnackBar(isAr ? 'تم' : 'Done');"), isEmpty);
      expect(kinds("dio.post('/x', data: {'title': storedText.defaultTitle});"), isEmpty);
      expect(kinds("dio.post('/x', data: {'status': DomainEnums.codes(t).first});"), isEmpty);
      expect(kinds("dio.post('/x', data: {'a': 1}); // l10n.x 'عربي'"), isEmpty);
      expect(kinds("dio.post('/x', data: {'ar': l10n.isArabic});"), isEmpty);
      expect(kinds("final labels = {'in_progress': l10n.inProgress, 'done': l10n.done};"), isEmpty);
      expect(kinds("final m = {'label': l10n.save};"), isEmpty); // not API-shaped
      expect(kinds("dio.post('/x', data: {'q': 'text with { brace'}); Text(l10n.x);"), isEmpty);
      expect(kinds("final p = {'code': 'STEP_01', 'name_ar': 'تخطيط', 'name_en': 'Planning'};"), isEmpty);
      expect(kinds("final p = {'hs_code': c, 'kind': d.contains('آلات') ? 'MACHINERY' : 'GENERAL'};"), isEmpty);
      expect(kinds("final metadata = {isAr ? 'المورد' : 'Supplier': po.supplier_name};"), isEmpty);
    });
  });
}
