import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/helpers/file_picker_helper.dart';

void main() {
  group('FilePickerHelper.isPlainTextFile', () {
    test('recognises txt/csv/json/xml/log case-insensitively', () {
      for (final name in ['a.txt', 'B.CSV', 'data.Json', 'x.xml', 'server.LOG', 'archive.v2.txt']) {
        expect(FilePickerHelper.isPlainTextFile(name), isTrue, reason: name);
      }
    });

    test('rejects binary / office formats', () {
      for (final name in ['a.pdf', 'b.xlsx', 'c.docx', 'd.png', 'e.txt.pdf', 'README']) {
        expect(FilePickerHelper.isPlainTextFile(name), isFalse, reason: name);
      }
    });

    test('a bare extension name is treated as that extension (split on last dot)', () {
      // 'txt' has no dot: split('.').last == 'txt' — matches previous inline behaviour.
      expect(FilePickerHelper.isPlainTextFile('txt'), isTrue);
    });
  });

  group('FilePickerHelper.tryDecodeText', () {
    test('returns null for null bytes', () {
      expect(FilePickerHelper.tryDecodeText(null), isNull);
    });

    test('decodes UTF-8 including Arabic', () {
      final bytes = Uint8List.fromList(utf8.encode('Invoice رقم 35220'));
      expect(FilePickerHelper.tryDecodeText(bytes), 'Invoice رقم 35220');
    });

    test('tolerates malformed bytes (allowMalformed)', () {
      final bytes = Uint8List.fromList([0x41, 0xFF, 0x42]);
      expect(FilePickerHelper.tryDecodeText(bytes), 'A�B');
    });

    test('empty bytes decode to empty string', () {
      expect(FilePickerHelper.tryDecodeText(Uint8List(0)), '');
    });
  });
}
