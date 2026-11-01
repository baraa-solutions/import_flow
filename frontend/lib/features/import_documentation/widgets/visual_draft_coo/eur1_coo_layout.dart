import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import 'coo_sheet_helpers.dart';

class Eur1CooLayout extends StatelessWidget {
  final String certNo;
  final String exporter;
  final String consignee;
  final String transport;
  final String destination;
  final String goodsDesc;
  final List<String> hsCodesList;
  final String weight;
  final String invoiceData;
  final List<String> originsList;
  final String remarks;
  final bool isEur1;
  final List<Map<String, dynamic>> tableRows;
  final String acidNumber;

  const Eur1CooLayout({
    super.key,
    required this.certNo,
    required this.exporter,
    required this.consignee,
    required this.transport,
    required this.destination,
    required this.goodsDesc,
    required this.hsCodesList,
    required this.weight,
    required this.invoiceData,
    required this.originsList,
    required this.remarks,
    required this.isEur1,
    this.tableRows = const [],
    required this.acidNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppTheme.white,
            border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 1.2)),
          ),
          child: const Text(
            'MOVEMENT CERTIFICATE',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2, color: AppTheme.textPrimary),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: buildCooBoxCell('1. Exporter (Name, full address, country)', exporter, hasRightBorder: true, hasBottomBorder: true, minHeight: 125),
            ),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('EUR.1', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.black)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: CopyableText(
                                certNo.startsWith('DRAFT') ? certNo : 'No A $certNo',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.black),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('See notes overleaf before completing this form.', style: TextStyle(fontSize: 11.0, fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text('2. Certificate used in preferential trade between', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                        ),
                        const SizedBox(height: 3),
                        const Text('EU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.textPrimary)),
                        const Text('and', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                        Text(destination.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        const Text('(Insert appropriate countries, groups of countries or territories)', style: TextStyle(fontSize: 11.0, fontStyle: FontStyle.italic, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: buildCooBoxCell('3. Consignee (Name, full address, country) (Optional)', consignee, hasRightBorder: true, hasBottomBorder: true, minHeight: 90),
            ),
            Expanded(
              flex: 5,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 90),
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: AppTheme.textPrimary, width: 0.8), bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('4. Country, group of countries or territory in which the products are considered as originating', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppTheme.infoBackground, borderRadius: BorderRadius.circular(3), border: Border.all(color: AppTheme.cobaltBorder)),
                            child: const Text('🇪🇺 EU', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.cobalt)),
                          ),
                          if (originsList.isNotEmpty && !originsList.contains('EU'))
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text('(${originsList.join(', ')})', style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: buildCooBoxCell('5. Country, group of countries or territory of destination (Optional)', destination, hasBottomBorder: true, minHeight: 90),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: buildCooBoxCell('6. Transport details (Optional)', transport.isNotEmpty ? transport : 'BY SEA / CONTAINERIZED CARGO', hasRightBorder: true, hasBottomBorder: true, minHeight: 50),
            ),
            Expanded(
              flex: 5,
              child: buildCooBoxCell('7. Remarks', remarks.isNotEmpty ? remarks : 'REVISED RULES', hasBottomBorder: true, minHeight: 50),
            ),
          ],
        ),
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 1.2))),
          child: Column(
            children: [
              Container(
                color: AppTheme.surfaceAlt,
                child: Row(
                  children: [
                    buildCooTableHeadCell('8. Item number; Marks and numbers; Number and kind of packages (1); Description of goods', flex: 5),
                    buildCooTableHeadCell('9. Gross mass (kg)\nor other measure\n(litres, m³, etc.)', flex: 2),
                    buildCooTableHeadCell('10. Invoices\n(Optional)', flex: 2, hasRightBorder: false),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.textPrimary),
              if (tableRows.isNotEmpty)
                ...tableRows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  final rowDesc = CooSheetHelpers.sanitizeEnglishOnly((r['description'] ?? goodsDesc).toString());
                  final rowHs = (r['hs_code'] ?? hsCodesList.join(', ')).toString();
                  final rowPkgs = r['packages_count']?.toString() ?? '144';
                  final rowGw = r['gross_weight_kg'] != null ? '${(r['gross_weight_kg'] as num).toStringAsFixed(3)} KG' : (weight.isNotEmpty ? weight : '10,510.600 KG');
                  final rowInv = CooSheetHelpers.sanitizeEnglishOnly((r['invoice_str'] ?? invoiceData).toString());

                  return Column(
                    children: [
                      if (idx > 0) const Divider(height: 1, color: AppTheme.textMuted),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$rowDesc ($rowPkgs PACKAGES)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppTheme.infoBackground, borderRadius: BorderRadius.circular(3), border: Border.all(color: AppTheme.cobaltBorder)),
                                    child: Text('🔖 $rowHs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.cobalt)),
                                  ),
                                  const SizedBox(height: 10),
                                  CustomPaint(size: const Size(double.infinity, 20), painter: DiagonalLinePainter()),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(rowGw, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                                  const SizedBox(height: 14),
                                  CustomPaint(size: const Size(double.infinity, 20), painter: DiagonalLinePainter()),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ACID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.emerald)),
                                  Text(acidNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.emerald)),
                                  if (rowInv.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(rowInv, style: const TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                                  ],
                                  const SizedBox(height: 10),
                                  CustomPaint(size: const Size(double.infinity, 20), painter: DiagonalLinePainter()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                })
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(goodsDesc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: hsCodesList.map((hs) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.infoBackground, borderRadius: BorderRadius.circular(3), border: Border.all(color: AppTheme.cobaltBorder)),
                                  child: Text('🔖 $hs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.cobalt)),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                            CustomPaint(size: const Size(double.infinity, 30), painter: DiagonalLinePainter()),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(weight.isNotEmpty ? weight : '10,510.6 KG', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            CustomPaint(size: const Size(double.infinity, 30), painter: DiagonalLinePainter()),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ACID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.emerald)),
                            Text(acidNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.emerald)),
                            if (invoiceData.isNotEmpty && invoiceData != 'INVOICE INFO') ...[
                              const SizedBox(height: 4),
                              Text(invoiceData, style: const TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                            ],
                            const SizedBox(height: 14),
                            CustomPaint(size: const Size(double.infinity, 30), painter: DiagonalLinePainter()),
                          ],
                        ),
                      ),
                    ),
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
                decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('11. CUSTOMS ENDORSEMENT', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    const Text('Declaration certified', style: TextStyle(fontSize: 11.0)),
                    const Text('Export document (2)', style: TextStyle(fontSize: 11.0)),
                    const Text('Form .............................. No ..............................', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                    const Text('Of .....................................................................', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    const Text('Customs office: Vilnius regional customs office', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w500)),
                    const Text('Issuing country or territory: Lithuania', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Place and date:', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                            Text('2026-08-11', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: AppTheme.infoForeground, width: 1.5), borderRadius: BorderRadius.circular(20)),
                          child: const Text('A-004 • LT VM • 2026-08-11', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.infoForeground)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Divider(height: 1, color: AppTheme.textSecondary),
                    const Center(child: Text('(Signature)', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary))),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('12. DECLARATION BY THE EXPORTER', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    const Text('I, the undersigned, declare that the goods described above meet the conditions required for the issue of this certificate.', style: TextStyle(fontSize: 11.0, height: 1.25)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Place and date:', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                            Text('VILNIUS 2026-08-11', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(border: Border.all(color: AppTheme.infoForeground, width: 1.2), borderRadius: BorderRadius.circular(4)),
                          child: const Text('NARBUTAS DOKUMENTAI', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.infoForeground)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppTheme.textSecondary),
                    const Center(child: Text('(Signature)', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary))),
                  ],
                ),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: AppTheme.surfaceAlt,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('(1) If goods are not packed, indicate number of articles or state \'in bulk\', as appropriate.', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
              Text('(2) Complete only where the regulations of the exporting country or territory require.', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
