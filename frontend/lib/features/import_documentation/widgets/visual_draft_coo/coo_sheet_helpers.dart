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
    text = text.replaceAll(RegExp(r'\b(PET|PVC|PU|PE|MDF|HDF|PP|ABS)\s+', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\bN\s*/\s*M\b', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'ACID:[^\n]*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'[\*\#]'), '');
    text = text.replaceAll(RegExp(r'^[\s,./\-_:|]+'), '');
    text = text.replaceAll(RegExp(r'[\s,./\-_:|]+$'), '');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    if (text.contains(' / ') || text.contains(',')) {
      final parts = text
          .split(RegExp(r'\s*[/,]\s*'))
          .map((p) => p.replaceAll(RegExp(r'^[\s,./\-_:|]+'), '').replaceAll(RegExp(r'[\s,./\-_:|]+$'), '').trim())
          .where((p) => p.isNotEmpty && p.length > 1)
          .toSet()
          .toList();
      text = parts.join(' / ');
    }

    text = text.replaceAll(RegExp(r'^[\s,./\-_:|]+'), '');
    text = text.replaceAll(RegExp(r'[\s,./\-_:|]+$'), '').trim();

    if (text.isEmpty || text.toUpperCase() == 'COMMERCIAL CARGO' || text.contains('CN - China')) {
      text = 'Acoustic Panels';
    }
    return text;
  }

  static String formatCooHsCode(String input, {bool isChina = true}) {
    if (input.trim().isEmpty) return '';
    if (!isChina) return input;

    if (input.contains(',') || input.contains('\n') || input.contains(' / ')) {
      final delimiter = input.contains('\n') ? '\n' : (input.contains(' / ') ? ' / ' : ', ');
      final items = input
          .split(RegExp(r'[,/\n]+'))
          .map((s) => formatCooHsCode(s.trim(), isChina: true))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      return items.join(delimiter);
    }

    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return '${digits.substring(0, 2)}.${digits.substring(2, 4)}';
    } else if (digits.length >= 2) {
      return digits;
    }
    return input;
  }

  static String getPackageTypePlural(dynamic count, String? packageType) {
    final int pkgCnt = (count is num) ? count.toInt() : (int.tryParse(count.toString()) ?? 1);
    final rawType = (packageType ?? 'CARTON').trim().toUpperCase();
    if (rawType.contains('PALLET')) {
      return pkgCnt > 1 ? 'PALLETS' : 'PALLET';
    } else if (rawType.contains('CONTAINER')) {
      return pkgCnt > 1 ? 'CONTAINERS' : 'CONTAINER';
    } else if (rawType.contains('BOX')) {
      return pkgCnt > 1 ? 'BOXES' : 'BOX';
    } else if (rawType.contains('PACKAGE') || rawType.contains('PKG')) {
      return pkgCnt > 1 ? 'PACKAGES' : 'PACKAGE';
    } else if (rawType.contains('DRUM')) {
      return pkgCnt > 1 ? 'DRUMS' : 'DRUM';
    } else if (rawType.contains('BAG')) {
      return pkgCnt > 1 ? 'BAGS' : 'BAG';
    } else if (rawType.contains('ROLL')) {
      return pkgCnt > 1 ? 'ROLLS' : 'ROLL';
    } else if (rawType.contains('CRATE')) {
      return pkgCnt > 1 ? 'CRATES' : 'CRATE';
    } else if (rawType.contains('CTN')) {
      return pkgCnt > 1 ? 'CTNS' : 'CTN';
    } else {
      return pkgCnt > 1 ? 'CARTONS' : 'CARTON';
    }
  }

  static String formatCooQuantityBox({
    required dynamic quantity,
    String? unit,
    required dynamic packagesCount,
    String? packageType,
    required dynamic grossWeightKg,
    bool isChina = true,
  }) {
    final double qVal = (quantity is num) ? quantity.toDouble() : (double.tryParse(quantity.toString()) ?? 0.0);
    String qtyStr;
    if (qVal % 1 == 0) {
      qtyStr = qVal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    } else {
      qtyStr = qVal.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    }

    var cleanUnit = (unit ?? 'PCS').trim().toUpperCase();
    if (cleanUnit == 'PIECE' || cleanUnit == 'PIECES' || cleanUnit == 'PC' || cleanUnit == 'PCS.') {
      cleanUnit = 'PCS';
    } else if (cleanUnit == 'SET' || cleanUnit == 'SETS') {
      cleanUnit = qVal != 1 ? 'SETS' : 'SET';
    } else if (cleanUnit == 'ROLL' || cleanUnit == 'ROLLS') {
      cleanUnit = qVal != 1 ? 'ROLLS' : 'ROLL';
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
