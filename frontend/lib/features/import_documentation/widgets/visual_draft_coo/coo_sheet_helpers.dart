import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class CooSheetHelpers {
  static String sanitizeEnglishOnly(String input) {
    if (input.isEmpty) return input;
    var text = input.replaceAll(RegExp(r'\s*\([\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\s\.\-]+\)'), '');
    text = text.replaceAll(RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]'), '');
    text = text.replaceAll(RegExp(r'\(\s*\)'), '');
    text = text.replaceAll(RegExp(r'-\s*-+'), '-');
    text = text.replaceAll(RegExp(r'\s*-\s*$'), '');
    text = text.replaceAll(RegExp(r'^\s*-\s*'), '');

    final lines = text.split('\n').map((l) {
      var cleanLine = l.replaceAll(RegExp(r'[^\S\r\n]+'), ' ').trim();
      final upper = cleanLine.toUpperCase().trim();
      if (upper == 'CN' || upper == 'CN -' || upper == 'CN - CHINA' || upper == 'CN-CHINA' || upper == 'CHINA') {
        cleanLine = 'China';
      } else if (upper == 'EG' || upper == 'EG -' || upper == 'EG - EGYPT' || upper == 'EGYPT') {
        cleanLine = 'Egypt';
      }
      return cleanLine;
    }).where((l) => l.isNotEmpty).toList();

    return lines.join('\n');
  }

  static String extractCleanMainDescription(String input) {
    if (input.isEmpty) return 'Acoustic Panels';
    var text = input.replaceAll(RegExp(r'\s*\([^\)]*\)'), '');
    text = text.replaceAll(RegExp(r'\b[A-Za-z]{1,4}-\d{2,6}\b'), '');
    text = text.replaceAll(RegExp(r'\b\d{1,4}[xX*]\d{1,4}([xX*]\d{1,4})?\s*(mm|cm|m)?\b', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\b\d{1,3}\s*(mm|cm|m)\b', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'-\s*-+'), '-');
    text = text.replaceAll(RegExp(r'\s*-\s*$'), '');
    text = text.replaceAll(RegExp(r'^\s*-\s*'), '');
    text = text.replaceAll(RegExp(r'[^\S\r\n]+'), ' ').trim();

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return 'Acoustic Panels';
    final first = lines.first;
    if (first.length > 50) {
      final commaIdx = first.indexOf(',');
      if (commaIdx > 5 && commaIdx < 50) {
        return first.substring(0, commaIdx).trim();
      }
      return first.substring(0, 50).trim();
    }
    return first;
  }

  static String formatCooHsCode(String input, {bool isChina = true}) {
    if (input.isEmpty) return input;
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 6) {
      final main6 = digits.substring(0, 6);
      return '${main6.substring(0, 4)}.${main6.substring(4, 6)}';
    }
    return input;
  }

  static String getPackageTypePlural(dynamic count, String? packageType) {
    final int cnt = (count is num) ? count.toInt() : (int.tryParse(count.toString()) ?? 1);
    final rawType = (packageType ?? 'Carton').trim();
    final lower = rawType.toLowerCase();
    String base;
    if (lower.contains('carton') || lower.contains('ctn')) {
      base = 'CARTON';
    } else if (lower.contains('pallet') || lower.contains('plt')) {
      base = 'PALLET';
    } else if (lower.contains('box') || lower.contains('crate')) {
      base = 'BOX';
    } else if (lower.contains('bag')) {
      base = 'BAG';
    } else if (lower.contains('roll')) {
      base = 'ROLL';
    } else if (lower.contains('drum')) {
      base = 'DRUM';
    } else {
      base = rawType.toUpperCase();
    }
    if (cnt > 1) {
      if (base == 'BOX') return 'BOXES';
      if (!base.endsWith('S')) return '${base}S';
    }
    return base;
  }

  static String formatCooQuantityBox({
    required dynamic quantity,
    String? unit,
    required dynamic packagesCount,
    String? packageType,
    required dynamic grossWeightKg,
    bool isChina = true,
  }) {
    final double qtyVal = (quantity is num) ? quantity.toDouble() : (double.tryParse(quantity.toString()) ?? 0.0);
    String qtyStr;
    if (qtyVal % 1 == 0) {
      qtyStr = qtyVal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    } else {
      qtyStr = qtyVal.toStringAsFixed(2);
    }

    var cleanUnit = (unit ?? 'PCS').toUpperCase().trim();
    if (cleanUnit == 'PC' || cleanUnit == 'PIECE' || cleanUnit == 'PIECES' || cleanUnit == 'PCS') {
      cleanUnit = 'PCS';
    } else if (cleanUnit == 'M2' || cleanUnit == 'SQM' || cleanUnit == 'SQ.M') {
      cleanUnit = 'SQM';
    } else if (cleanUnit == 'KG' || cleanUnit == 'KGS' || cleanUnit == 'KILOGRAM') {
      cleanUnit = 'KGS';
    }

    final int pkgCnt = (packagesCount is num) ? packagesCount.toInt() : (int.tryParse(packagesCount.toString()) ?? 1);
    final String pkgWord = getPackageTypePlural(pkgCnt, packageType);
    final line1 = '$qtyStr $cleanUnit / $pkgCnt $pkgWord';

    final double gwVal = (grossWeightKg is num) ? grossWeightKg.toDouble() : (double.tryParse(grossWeightKg.toString()) ?? 0.0);
    String gwLine;
    if (isChina) {
      if (gwVal % 1 == 0) {
        final formattedGw = gwVal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
        gwLine = '${formattedGw}KGS G.W.';
      } else {
        final formattedGw = gwVal.toStringAsFixed(2);
        gwLine = '${formattedGw}KGS G.W.';
      }
    } else {
      if (gwVal % 1 == 0) {
        final formattedGw = gwVal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
        gwLine = '$formattedGw KG G.W.';
      } else {
        final formattedGw = gwVal.toStringAsFixed(3);
        gwLine = '$formattedGw KG G.W.';
      }
    }

    return '$line1\n$gwLine';
  }
}

Widget buildCooBoxCell(
  String label,
  String value, {
  bool hasRightBorder = false,
  bool hasBottomBorder = false,
  double? minHeight,
}) {
  final lines = value.split('\n');
  final firstLine = lines.isNotEmpty ? lines[0] : '';
  final otherLines = lines.length > 1 ? lines.sublist(1).join('\n') : '';

  return Container(
    width: double.infinity,
    constraints: minHeight != null ? BoxConstraints(minHeight: minHeight) : null,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      border: Border(
        bottom: hasBottomBorder ? const BorderSide(color: AppTheme.textPrimary, width: 0.8) : BorderSide.none,
        right: hasRightBorder ? const BorderSide(color: AppTheme.textPrimary, width: 0.8) : BorderSide.none,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        CopyableText(firstLine, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.textPrimary)),
        if (otherLines.isNotEmpty) ...[
          const SizedBox(height: 2),
          CopyableText(
            otherLines,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.0, color: AppTheme.textPrimary, height: 1.25),
          ),
        ],
      ],
    ),
  );
}

Widget buildCooTableHeadCell(String title, {required int flex, bool hasRightBorder = true}) {
  return Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        border: BorderDirectional(end: hasRightBorder ? const BorderSide(color: AppTheme.textPrimary, width: 0.8) : BorderSide.none),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

Widget buildCooTableBodyCell(String content, {required int flex, bool hasRightBorder = true}) {
  return Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: BorderDirectional(end: hasRightBorder ? const BorderSide(color: AppTheme.textPrimary, width: 0.8) : BorderSide.none),
      ),
      child: CopyableText(
        content,
        style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      ),
    ),
  );
}

class DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
