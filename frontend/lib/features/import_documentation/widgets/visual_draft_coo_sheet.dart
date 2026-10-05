import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../services/coo_export_service.dart';

/// Localized message for a blocked COO export (`acid`, `hs_code`, `origin`).
String cooExportBlockedMessage(AppLocalizations l10n, String field) {
  switch (field) {
    case 'acid':
      return l10n.idocBExportBlockedAcid;
    case 'hs_code':
      return l10n.idocBExportBlockedHsCode;
    default:
      return l10n.idocBExportBlockedOrigin;
  }
}

/// Shows the blocked-export SnackBar and returns true when [field] is non-null.
bool showCooExportBlockedIfAny(BuildContext context, String? field) {
  if (field == null) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(cooExportBlockedMessage(context.l10n, field)), backgroundColor: AppTheme.crimson),
  );
  return true;
}

class VisualDraftCOOSheet extends StatefulWidget {
  final Map<String, dynamic> templateData;
  final String certificateType;
  final String acidNumber;
  final String? exemptionNotes;
  final VoidCallback? onRefresh;

  const VisualDraftCOOSheet({
    super.key,
    required this.templateData,
    required this.certificateType,
    required this.acidNumber,
    this.exemptionNotes,
    this.onRefresh,
  });

  static String? missingExportField(Map<String, dynamic> t, String? acid) => CooExportService.missingExportField(t, acid);
  static String sanitizeEnglishOnly(String input) => _VisualDraftCOOSheetState.sanitizeEnglishOnly(input);
  static String extractCleanMainDescription(String input) => _VisualDraftCOOSheetState.extractCleanMainDescription(input);
  static String formatCooHsCode(String input, {bool isChina = true}) => _VisualDraftCOOSheetState.formatCooHsCode(input, isChina: isChina);
  static String getPackageTypePlural(dynamic count, String? packageType) => _VisualDraftCOOSheetState.getPackageTypePlural(count, packageType);
  static String formatCooQuantityBox({
    required dynamic quantity,
    String? unit,
    required dynamic packagesCount,
    String? packageType,
    required dynamic grossWeightKg,
    bool isChina = true,
  }) =>
      _VisualDraftCOOSheetState.formatCooQuantityBox(
        quantity: quantity,
        unit: unit,
        packagesCount: packagesCount,
        packageType: packageType,
        grossWeightKg: grossWeightKg,
        isChina: isChina,
      );

  @override
  State<VisualDraftCOOSheet> createState() => _VisualDraftCOOSheetState();
}

class _VisualDraftCOOSheetState extends State<VisualDraftCOOSheet> {
  bool _isExporting = false;

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

  @override
  Widget build(BuildContext context) {
    // Printed-document replica: always left-to-right, whatever the UI language.
    return Directionality(textDirection: TextDirection.ltr, child: _buildSheet(context));
  }

  Widget _buildSheet(BuildContext context) {
    final t = widget.templateData;
    final isChina = widget.certificateType.toUpperCase().contains('CHINA') || widget.certificateType.toUpperCase().contains('CCPIT');
    final isEur1 = widget.certificateType.toUpperCase().contains('EUR.1') || widget.certificateType.toUpperCase().contains('EUR1');

    final cleanAcidNo = sanitizeEnglishOnly(widget.acidNumber).replaceAll(RegExp(r'[^0-9]'), '');
    final rawCert = t['certificate_number']?.toString() ?? '';
    final certNo = (rawCert.isNotEmpty && !rawCert.startsWith('26C') && !rawCert.startsWith('No A'))
        ? sanitizeEnglishOnly(rawCert)
        : (cleanAcidNo.isNotEmpty ? 'DRAFT-$cleanAcidNo' : 'DRAFT');

    final tableRows = (t['table_rows'] as List<dynamic>?)
            ?.map((r) => Map<String, dynamic>.from(r as Map))
            .toList() ??
        [];

    final exporter = sanitizeEnglishOnly((t['box_1_exporter'] ?? 'EXPORTER / PRODUCER').toString());
    final consignee = sanitizeEnglishOnly((t['box_2_consignee'] ?? t['box_3_consignee'] ?? 'IMPORTER / CONSIGNEE').toString());
    final transport = sanitizeEnglishOnly((t['box_3_means_of_transport'] ?? t['box_6_transport_details'] ?? 'BY SEA').toString());
    final destination = sanitizeEnglishOnly((t['box_4_country_of_destination'] ?? t['box_5_country_destination'] ?? 'EGYPT').toString());
    final origin = sanitizeEnglishOnly((t['country_of_origin'] ?? t['box_4_country_origin'] ?? '').toString());
    final originsList = (t['countries_of_origin_list'] as List<dynamic>?)
            ?.map((e) => sanitizeEnglishOnly(e.toString()))
            .where((e) => e.isNotEmpty)
            .toList() ??
        [origin];
    final hsCodes = isChina
        ? formatCooHsCode((t['box_8_hs_code'] ?? t['hs_code'] ?? t['hs_codes'] ?? '').toString())
        : (t['box_8_hs_code'] ?? t['hs_code'] ?? t['hs_codes'] ?? '').toString();
    final hsCodesList = (t['hs_codes_list'] as List<dynamic>?)
            ?.map((e) => isChina ? formatCooHsCode(e.toString()) : e.toString())
            .toList() ??
        [hsCodes];
    final goodsDesc = sanitizeEnglishOnly((t['box_7_description_and_acid'] ?? t['box_8_description_packages'] ?? t['description'] ?? 'COMMERCIAL CARGO').toString());
    
    final rawWeight = (t['box_9_quantity_and_weight'] ?? t['box_9_gross_mass'] ?? '').toString().trim();
    final weight = rawWeight.isNotEmpty
        ? sanitizeEnglishOnly(rawWeight)
        : formatCooQuantityBox(
            quantity: t['quantity'] ?? 1152,
            unit: t['unit']?.toString() ?? 'PCS',
            packagesCount: t['packages_count'] ?? 144,
            packageType: t['package_type']?.toString(),
            grossWeightKg: t['gross_weight_kg'] ?? 10510.0,
            isChina: isChina,
          );

    final invoiceData = sanitizeEnglishOnly((t['box_10_invoice_number_and_date'] ?? t['box_10_invoices_and_acid'] ?? 'INVOICE INFO').toString());
    final remarks = sanitizeEnglishOnly((t['box_7_remarks'] ?? (isEur1 ? 'REVISED RULES' : 'N/A')).toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(isEur1 ? Icons.flag_circle : Icons.verified, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.l10n.cooVisualPreviewTitle(widget.certificateType),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                ),
                const SizedBox(width: 16),
                if (widget.onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: AppTheme.cobalt),
                    tooltip: context.l10n.cooVisualRefreshTooltip,
                    onPressed: widget.onRefresh,
                  ),
                AppButton(label: context.l10n.cooVisualCopyButton, onPressed: () {
                    if (showCooExportBlockedIfAny(context, CooExportService.missingExportField(t, widget.acidNumber))) return;
                    final text = CooExportService.exportCOOCsv(
                      templateData: t,
                      certificateType: widget.certificateType,
                      acidNumber: widget.acidNumber,
                    );
                    CopyHelper.copy(context, text, customMessage: context.l10n.cooVisualCopiedSnackbar);
                  }, variant: AppButtonVariant.secondary, icon: Icons.copy),
                const SizedBox(width: 8),
                AppButton(label: context.l10n.cooVisualExcelButton, onPressed: () async {
                    if (showCooExportBlockedIfAny(context, CooExportService.missingExportField(t, widget.acidNumber))) return;
                    final path = await CooExportService.saveCOOCsvToFile(
                      templateData: t,
                      certificateType: widget.certificateType,
                      acidNumber: widget.acidNumber,
                    );
                    if (path != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.cooExcelSavedSuccess(path)),
                          backgroundColor: AppTheme.emerald,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } else {
                      // Fallback copy to clipboard if cancelled or web
                      final csv = CooExportService.exportCOOCsv(
                        templateData: t,
                        certificateType: widget.certificateType,
                        acidNumber: widget.acidNumber,
                      );
                      if (context.mounted) {
                        CopyHelper.copy(context, csv, customMessage: context.l10n.cooVisualExcelReadySnackbar);
                      }
                    }
                  }, variant: AppButtonVariant.secondary, icon: Icons.table_chart_outlined),
                const SizedBox(width: 8),
                AppButton(label: context.l10n.cooVisualPrintPdfButton, onPressed: _isExporting
                      ? null
                      : () async {
                          if (showCooExportBlockedIfAny(context, CooExportService.missingExportField(t, widget.acidNumber))) return;
                          setState(() => _isExporting = true);
                          try {
                            await CooExportService.printOrSavePdf(
                              templateData: t,
                              certificateType: widget.certificateType,
                              acidNumber: widget.acidNumber,
                              exemptionNotes: widget.exemptionNotes,
                            );
                          } finally {
                            if (mounted) setState(() => _isExporting = false);
                          }
                        }, icon: Icons.picture_as_pdf, isLoading: _isExporting),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ─── Egyptian Customs Compliance Alert Banner ───
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.orange, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, color: AppTheme.orange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: CopyableText(
                  context.l10n.cooCustomsClearanceNote,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningForeground,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Official Visual Document Container (Like real paper)
        Container(
          decoration: BoxDecoration(
            color: isChina ? AppTheme.surfaceAlt : AppTheme.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isChina ? AppTheme.infoForeground : AppTheme.textPrimary, width: 1.5),
            boxShadow: const [BoxShadow(color: AppTheme.border, blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: isChina
              ? _buildChinaCcpitLayout(
                  certNo: certNo,
                  exporter: exporter,
                  consignee: consignee,
                  transport: transport,
                  destination: destination,
                  goodsDesc: goodsDesc,
                  hsCodesList: hsCodesList,
                  weight: weight,
                  tableRows: tableRows,
                  acidNumber: cleanAcidNo,
                )
              : _buildEur1Layout(
                  certNo: certNo,
                  exporter: exporter,
                  consignee: consignee,
                  transport: transport,
                  destination: destination,
                  goodsDesc: goodsDesc,
                  hsCodesList: hsCodesList,
                  weight: weight,
                  invoiceData: invoiceData,
                  originsList: originsList,
                  remarks: remarks,
                  isEur1: isEur1,
                  tableRows: tableRows,
                  acidNumber: cleanAcidNo,
                ),
        ),
      ],
    );
  }

  // ─── Authentic China CCPIT Certificate of Origin Layout ───────────────────────
  Widget _buildChinaCcpitLayout({
    required String certNo,
    required String exporter,
    required String consignee,
    required String transport,
    required String destination,
    required String goodsDesc,
    required List<String> hsCodesList,
    required String weight,
    List<Map<String, dynamic>> tableRows = const [],
    required String acidNumber,
  }) {
    // Ensure Transport route has Port of departure + Country TO Port of destination + Country
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

    // Format clean Box 7 description with main description, total packed line, stars line, and ACID line
    String cleanBox7;
    if (goodsDesc.contains('TOTAL PACKED IN') && goodsDesc.contains('ACID:')) {
      final parts = goodsDesc.split('\n\n');
      if (parts.isNotEmpty) {
        parts[0] = extractCleanMainDescription(parts[0]);
        cleanBox7 = parts.join('\n\n');
      } else {
        cleanBox7 = goodsDesc;
      }
    } else {
      var baseDesc = extractCleanMainDescription(goodsDesc);
      cleanBox7 = '$baseDesc\n\nTOTAL PACKED IN EIGHTY TWO (82) CARTONS ONLY\n\n*** *** *** *** ***\n\nACID:$validAcid';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Center ORIGINAL
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          child: const Text(
            'ORIGINAL',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 3, color: AppTheme.black),
          ),
        ),
        const Divider(height: 1, thickness: 1.2, color: AppTheme.textPrimary),

        // ─── Top Block: Box 1 & Box 2 (Left 50%) vs Official Title (Right 50%) ───
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Box 1 (Exporter) & Box 2 (Consignee)
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBoxCell(
                      '1. Exporter',
                      exporter,
                      hasRightBorder: true,
                      hasBottomBorder: true,
                      minHeight: 95,
                    ),
                    _buildBoxCell(
                      '2. Consignee',
                      consignee,
                      hasRightBorder: true,
                      hasBottomBorder: true,
                      minHeight: 80,
                    ),
                  ],
                ),
              ),

              // Right: Authentic CCPIT Title & Certificate Header
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

        // ─── Middle Block: Box 3 & Box 4 (Left 50%) vs Box 5 (Right 50%) ───
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Box 3 (Transport) & Box 4 (Destination) - FLUSH TO LEFT
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBoxCell(
                      '3. Means of transport and route',
                      cleanTransport,
                      hasRightBorder: true,
                      hasBottomBorder: true,
                      minHeight: 60,
                    ),
                    _buildBoxCell(
                      '4. Country / region of destination',
                      destination,
                      hasRightBorder: true,
                      hasBottomBorder: true,
                      minHeight: 45,
                    ),
                  ],
                ),
              ),

              // Right: Box 5 (For certifying authority use only)
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('5. For certifying authority use only', style: TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.charcoal, width: 1.2),
                          ),
                          child: const Text(
                            'CHINA COUNCIL FOR THE PROMOTION OF INTERNATIONAL TRADE IS CHINA CHAMBER OF INTERNATIONAL COMMERCE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.0,
                              color: AppTheme.charcoal,
                              letterSpacing: 0.3,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: AlignmentDirectional.bottomEnd,
                        child: Text(
                          'VERIFY URL: HTTP://CHECK.ECOCCPIT.NET/',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── Table Section (Boxes 6, 7, 8, 9, 10) ───
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 1.2)),
          ),
          child: Column(
            children: [
              // Table Column Headers
              Container(
                color: AppTheme.surfaceAlt,
                child: Row(
                  children: [
                    _buildTableHeadCell('6. Marks and\nnumbers', flex: 2),
                    _buildTableHeadCell('7. Number and kind of packages; description of goods', flex: 4),
                    _buildTableHeadCell('8. H.S. Code', flex: 2),
                    _buildTableHeadCell('9. Quantity', flex: 2),
                    _buildTableHeadCell('10. Number\nand date of\ninvoices', flex: 2, hasRightBorder: false),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.textPrimary),

              // Table Body Content
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
                      parts[0] = extractCleanMainDescription(parts[0]);
                      rowDesc = parts.join('\n\n');
                    } else {
                      rowDesc = rawDesc;
                    }
                  } else {
                    final base = extractCleanMainDescription((r['description'] ?? cleanBox7).toString());
                    final pCnt = r['packages_count'] ?? 144;
                    rowDesc = '$base\n\nTOTAL PACKED IN $pCnt CARTONS ONLY\n\n*** *** *** *** ***\n\nACID:$validAcid';
                  }
                  rowDesc = sanitizeEnglishOnly(rowDesc)
                      .replaceAll(RegExp(r'\bN\s*/\s*M\b', caseSensitive: false), '')
                      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
                      .trim();
                  final rowHs = formatCooHsCode((r['hs_code'] ?? hsCodesList.join(', ')).toString());
                  final rowQtyWt = sanitizeEnglishOnly((r['quantity_and_weight_str'] ?? weight).toString());
                  final rowInv = sanitizeEnglishOnly((r['invoice_str'] ?? '').toString());

                  return Column(
                    children: [
                      if (idx > 0) const Divider(height: 1, color: AppTheme.textMuted),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Box 6: Marks
                          _buildTableBodyCell(rowMarks, flex: 2),
                          // Box 7: Description + ACID
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
                          // Box 8: HS Code
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                              child: Text(rowHs, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0)),
                            ),
                          ),
                          // Box 9: Quantity & Gross Weight
                          _buildTableBodyCell(rowQtyWt, flex: 2),
                          // Box 10: Invoices
                          _buildTableBodyCell(rowInv, flex: 2, hasRightBorder: false),
                        ],
                      ),
                    ],
                  );
                })
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Box 6: Marks
                    _buildTableBodyCell('N/M', flex: 2),
                    // Box 7: Description + ACID
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
                    // Box 8: HS Code
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
                    // Box 9: Quantity & Gross Weight
                    _buildTableBodyCell(weight, flex: 2),
                    // Box 10: Invoices
                    _buildTableBodyCell(tableRows.isNotEmpty ? (tableRows[0]['invoice_str'] ?? '') : '', flex: 2, hasRightBorder: false),
                  ],
                ),
            ],
          ),
        ),

        // ─── Bottom Row: Box 11 (Declaration) vs Box 12 (Certification) ───
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Box 11: Declaration
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

            // Box 12: Certification
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

  // ─── Authentic EUR.1 Movement Certificate Layout ──────────────────────────────
  Widget _buildEur1Layout({
    required String certNo,
    required String exporter,
    required String consignee,
    required String transport,
    required String destination,
    required String goodsDesc,
    required List<String> hsCodesList,
    required String weight,
    required String invoiceData,
    required List<String> originsList,
    required String remarks,
    required bool isEur1,
    List<Map<String, dynamic>> tableRows = const [],
    required String acidNumber,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Center Title
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

        // Row 1: Box 1 (Exporter) vs EUR.1 Header Box & Box 2 (Preferential Trade)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Box 1: Exporter
            Expanded(
              flex: 5,
              child: _buildBoxCell(
                '1. Exporter (Name, full address, country)',
                exporter,
                hasRightBorder: true,
                hasBottomBorder: true,
                minHeight: 125,
              ),
            ),

            // Right 50%: EUR.1 Header + Box 2
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  // EUR.1 Title & Cert No Box
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                    ),
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
                        const Text(
                          'See notes overleaf before completing this form.',
                          style: TextStyle(fontSize: 11.0, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Box 2: Preferential Trade
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            '2. Certificate used in preferential trade between',
                            style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'EU',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.textPrimary),
                        ),
                        const Text('and', style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                        Text(
                          destination.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '(Insert appropriate countries, groups of countries or territories)',
                          style: TextStyle(fontSize: 11.0, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Row 2: Box 3 (Consignee) vs Box 4 (Origin) & Box 5 (Destination)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Box 3: Consignee
            Expanded(
              flex: 5,
              child: _buildBoxCell(
                '3. Consignee (Name, full address, country) (Optional)',
                consignee,
                hasRightBorder: true,
                hasBottomBorder: true,
                minHeight: 90,
              ),
            ),

            // Box 4 & Box 5 Column
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
                        border: Border(
                          right: BorderSide(color: AppTheme.textPrimary, width: 0.8),
                          bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '4. Country, group of countries or territory in which the products are considered as originating',
                            style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.infoBackground,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: AppTheme.cobaltBorder),
                            ),
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
                    child: _buildBoxCell(
                      '5. Country, group of countries or territory of destination (Optional)',
                      destination,
                      hasBottomBorder: true,
                      minHeight: 90,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Row 3: Box 6 (Transport details) vs Box 7 (Remarks)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _buildBoxCell(
                '6. Transport details (Optional)',
                transport.isNotEmpty ? transport : 'BY SEA / CONTAINERIZED CARGO',
                hasRightBorder: true,
                hasBottomBorder: true,
                minHeight: 50,
              ),
            ),
            Expanded(
              flex: 5,
              child: _buildBoxCell(
                '7. Remarks',
                remarks.isNotEmpty ? remarks : 'REVISED RULES',
                hasBottomBorder: true,
                minHeight: 50,
              ),
            ),
          ],
        ),

        // Middle Table (Boxes 8, 9, 10)
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 1.2)),
          ),
          child: Column(
            children: [
              // Table Column Headers
              Container(
                color: AppTheme.surfaceAlt,
                child: Row(
                  children: [
                    _buildTableHeadCell('8. Item number; Marks and numbers; Number and kind of packages (1); Description of goods', flex: 5),
                    _buildTableHeadCell('9. Gross mass (kg)\nor other measure\n(litres, m³, etc.)', flex: 2),
                    _buildTableHeadCell('10. Invoices\n(Optional)', flex: 2, hasRightBorder: false),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.textPrimary),

              // Table Body Content
              if (tableRows.isNotEmpty)
                ...tableRows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  final rowDesc = sanitizeEnglishOnly((r['description'] ?? goodsDesc).toString());
                  final rowHs = (r['hs_code'] ?? hsCodesList.join(', ')).toString();
                  final rowPkgs = r['packages_count']?.toString() ?? '144';
                  final rowGw = r['gross_weight_kg'] != null ? '${(r['gross_weight_kg'] as num).toStringAsFixed(3)} KG' : (weight.isNotEmpty ? weight : '10,510.600 KG');
                  final rowInv = sanitizeEnglishOnly((r['invoice_str'] ?? invoiceData).toString());

                  return Column(
                    children: [
                      if (idx > 0) const Divider(height: 1, color: AppTheme.textMuted),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Box 8: Description + Packages + HS Code Badge
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
                                    decoration: BoxDecoration(
                                      color: AppTheme.infoBackground,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: AppTheme.cobaltBorder),
                                    ),
                                    child: Text('🔖 $rowHs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.cobalt)),
                                  ),
                                  const SizedBox(height: 10),
                                  CustomPaint(
                                    size: const Size(double.infinity, 20),
                                    painter: DiagonalLinePainter(),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Box 9: Gross Mass
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    rowGw,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  CustomPaint(
                                    size: const Size(double.infinity, 20),
                                    painter: DiagonalLinePainter(),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Box 10: Invoices & ACID
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
                                  CustomPaint(
                                    size: const Size(double.infinity, 20),
                                    painter: DiagonalLinePainter(),
                                  ),
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
                    // Box 8: Description + Packages + HS Code Badges
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

                            // Multi-HS code tags
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: hsCodesList.map((hs) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.infoBackground,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: AppTheme.cobaltBorder),
                                  ),
                                  child: Text('🔖 $hs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.cobalt)),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            // Diagonal line watermark simulation to prevent additions
                            CustomPaint(
                              size: const Size(double.infinity, 30),
                              painter: DiagonalLinePainter(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Box 9: Gross Mass
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              weight.isNotEmpty ? weight : '10,510.6 KG',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            CustomPaint(
                              size: const Size(double.infinity, 30),
                              painter: DiagonalLinePainter(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Box 10: Invoices & ACID
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
                            CustomPaint(
                              size: const Size(double.infinity, 30),
                              painter: DiagonalLinePainter(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Bottom Section: Box 11 (Customs Endorsement) vs Box 12 (Declaration by Exporter)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Box 11: Customs Endorsement
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                ),
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
                        // Customs Stamp Simulation
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.infoForeground, width: 1.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'A-004 • LT VM • 2026-08-11',
                            style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.infoForeground),
                          ),
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

            // Box 12: Declaration by Exporter
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('12. DECLARATION BY THE EXPORTER', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    const Text(
                      'I, the undersigned, declare that the goods described above meet the conditions required for the issue of this certificate.',
                      style: TextStyle(fontSize: 11.0, height: 1.25),
                    ),
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
                        // Exporter Stamp Simulation
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.infoForeground, width: 1.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NARBUTAS DOKUMENTAI',
                            style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.infoForeground),
                          ),
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

        // Footnotes
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: AppTheme.surfaceAlt,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '(1) If goods are not packed, indicate number of articles or state \'in bulk\', as appropriate.',
                style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary),
              ),
              Text(
                '(2) Complete only where the regulations of the exporting country or territory require.',
                style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoxCell(
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

  Widget _buildTableHeadCell(String title, {required int flex, bool hasRightBorder = true}) {
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

  Widget _buildTableBodyCell(String content, {required int flex, bool hasRightBorder = true}) {
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
}

/// Painter to draw the official anti-fraud diagonal lines in EUR.1 unused box space
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
