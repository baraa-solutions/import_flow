import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import 'coo_sheet_helpers.dart';

class ChinaCcpitCooLayout extends StatelessWidget {
  final String certNo;
  final String exporter;
  final String consignee;
  final String transport;
  final String destination;
  final String goodsDesc;
  final List<String> hsCodesList;
  final String weight;
  final List<Map<String, dynamic>> tableRows;
  final String acidNumber;

  const ChinaCcpitCooLayout({
    super.key,
    required this.certNo,
    required this.exporter,
    required this.consignee,
    required this.transport,
    required this.destination,
    required this.goodsDesc,
    required this.hsCodesList,
    required this.weight,
    this.tableRows = const [],
    required this.acidNumber,
  });

  @override
  Widget build(BuildContext context) {
    var cleanTransport = transport.trim();
    if (cleanTransport.isEmpty ||
        cleanTransport == 'CN - China' ||
        cleanTransport.toUpperCase() == 'BY SEA' ||
        cleanTransport.toUpperCase() == 'CHINA') {
      cleanTransport = 'FROM SHANGHAI CHINA TO ALEXANDRIA EGYPT BY SEA';
    } else if (!cleanTransport.toUpperCase().contains('TO') || !cleanTransport.toUpperCase().contains('FROM')) {
      cleanTransport = 'FROM $cleanTransport TO ALEXANDRIA EGYPT BY SEA';
    }

    final validAcid = (acidNumber.isNotEmpty && acidNumber != 'CN - China') ? acidNumber : '';

    String cleanBox7;
    if (goodsDesc.contains('TOTAL PACKED IN') && goodsDesc.contains('ACID:')) {
      final parts = goodsDesc.split('\n\n');
      if (parts.isNotEmpty) {
        parts[0] = CooSheetHelpers.extractCleanMainDescription(parts[0]);
        cleanBox7 = parts.join('\n\n');
      } else {
        cleanBox7 = goodsDesc;
      }
    } else {
      var baseDesc = CooSheetHelpers.extractCleanMainDescription(goodsDesc);
      cleanBox7 = '$baseDesc\n\nTOTAL PACKED IN EIGHTY TWO (82) CARTONS ONLY\n\n*** *** *** *** ***\n\nACID:$validAcid';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          child: const Text(
            'ORIGINAL',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 3, color: AppTheme.black),
          ),
        ),
        const Divider(height: 1, thickness: 1.2, color: AppTheme.textPrimary),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildCooBoxCell('1. Exporter', exporter, hasRightBorder: true, hasBottomBorder: true, minHeight: 95),
                    buildCooBoxCell('2. Consignee', consignee, hasRightBorder: true, hasBottomBorder: true, minHeight: 80),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Serial No.', style: TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: CopyableText(
                              'Certificate No. $certNo',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'CERTIFICATE OF ORIGIN',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, letterSpacing: 0.8, color: AppTheme.black),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'OF',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.black),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "THE PEOPLE'S REPUBLIC OF CHINA",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8, color: AppTheme.black),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildCooBoxCell('3. Means of transport and route', cleanTransport, hasRightBorder: true, hasBottomBorder: true, minHeight: 60),
                    buildCooBoxCell('4. Country / region of destination', destination, hasRightBorder: true, hasBottomBorder: true, minHeight: 45),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('5. For certifying authority use only', style: TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(border: Border.all(color: AppTheme.charcoal, width: 1.2)),
                          child: const Text(
                            'CHINA COUNCIL FOR THE PROMOTION OF INTERNATIONAL TRADE IS CHINA CHAMBER OF INTERNATIONAL COMMERCE',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.charcoal, letterSpacing: 0.3, height: 1.2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: AlignmentDirectional.bottomEnd,
                        child: Text('VERIFY URL: HTTP://CHECK.ECOCCPIT.NET/', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 1.2))),
          child: Column(
            children: [
              Container(
                color: AppTheme.surfaceAlt,
                child: Row(
                  children: [
                    buildCooTableHeadCell('6. Marks and\nnumbers', flex: 2),
                    buildCooTableHeadCell('7. Number and kind of packages; description of goods', flex: 4),
                    buildCooTableHeadCell('8. H.S. Code', flex: 2),
                    buildCooTableHeadCell('9. Quantity', flex: 2),
                    buildCooTableHeadCell('10. Number\nand date of\ninvoices', flex: 2, hasRightBorder: false),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.textPrimary),
              if (tableRows.isNotEmpty)
                ...tableRows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  const rowMarks = 'N/M';
                  final rawDesc = (r['description_and_acid'] ?? cleanBox7).toString();
                  String rowDesc;
                  if (rawDesc.contains('TOTAL PACKED IN') && rawDesc.contains('ACID:')) {
                    final parts = rawDesc.split('\n\n');
                    if (parts.isNotEmpty) {
                      parts[0] = CooSheetHelpers.extractCleanMainDescription(parts[0]);
                      rowDesc = parts.join('\n\n');
                    } else {
                      rowDesc = rawDesc;
                    }
                  } else {
                    final base = CooSheetHelpers.extractCleanMainDescription((r['description'] ?? cleanBox7).toString());
                    final pCnt = r['packages_count'] ?? 144;
                    rowDesc = '$base\n\nTOTAL PACKED IN $pCnt CARTONS ONLY\n\n*** *** *** *** ***\n\nACID:$validAcid';
                  }
                  rowDesc = CooSheetHelpers.sanitizeEnglishOnly(rowDesc)
                      .replaceAll(RegExp(r'\bN\s*/\s*M\b', caseSensitive: false), '')
                      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
                      .trim();
                  final rowHs = CooSheetHelpers.formatCooHsCode((r['hs_code'] ?? hsCodesList.join(', ')).toString());
                  final rowQtyWt = CooSheetHelpers.sanitizeEnglishOnly((r['quantity_and_weight_str'] ?? weight).toString());
                  final rowInv = CooSheetHelpers.sanitizeEnglishOnly((r['invoice_str'] ?? '').toString());

                  return Column(
                    children: [
                      if (idx > 0) const Divider(height: 1, color: AppTheme.textMuted),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildCooTableBodyCell(rowMarks, flex: 2),
                          Expanded(
                            flex: 4,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                              child: Text(
                                rowDesc,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.0, color: AppTheme.textPrimary, height: 1.3),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                              child: Text(rowHs, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0)),
                            ),
                          ),
                          buildCooTableBodyCell(rowQtyWt, flex: 2),
                          buildCooTableBodyCell(rowInv, flex: 2, hasRightBorder: false),
                        ],
                      ),
                    ],
                  );
                })
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildCooTableBodyCell('N/M', flex: 2),
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                        child: Text(
                          cleanBox7,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.0, color: AppTheme.textPrimary, height: 1.3),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: hsCodesList.map((hs) => Text(hs, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0))).toList(),
                        ),
                      ),
                    ),
                    buildCooTableBodyCell(weight, flex: 2),
                    buildCooTableBodyCell(tableRows.isNotEmpty ? (tableRows[0]['invoice_str'] ?? '') : '', flex: 2, hasRightBorder: false),
                  ],
                ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('11. Declaration by the exporter', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    SizedBox(height: 4),
                    Text(
                      'The undersigned hereby declares that the above details and statements are correct, that all the goods were produced in China and that they comply with the Rules of Origin of the People\'s Republic of China.',
                      style: TextStyle(fontSize: 11.0, height: 1.25, color: AppTheme.textPrimary),
                    ),
                    SizedBox(height: 38),
                    Divider(height: 1, color: AppTheme.textSecondary),
                    Text('Place and date, signature and stamp of authorized signatory', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('12. Certification', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    SizedBox(height: 4),
                    Text(
                      'It is hereby certified that the declaration by the exporter is correct.',
                      style: TextStyle(fontSize: 11.0, height: 1.25, color: AppTheme.textPrimary),
                    ),
                    SizedBox(height: 38),
                    Divider(height: 1, color: AppTheme.textSecondary),
                    Text('Place and date, signature and stamp of certifying authority', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
