import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/services/freight_rfq_generator_service.dart';
import '../../external_service_providers/models/partner_model.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../models/import_file_model.dart';

class FreightRfqDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;
  final String? customFileNumber;

  const FreightRfqDialog({
    super.key,
    required this.importFileId,
    required this.importFileCode,
    this.customFileNumber,
  });

  static Future<void> show(
    BuildContext context, {
    required int importFileId,
    required String importFileCode,
    String? customFileNumber,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => FreightRfqDialog(
        importFileId: importFileId,
        importFileCode: importFileCode,
        customFileNumber: customFileNumber,
      ),
    );
  }

  @override
  ConsumerState<FreightRfqDialog> createState() => _FreightRfqDialogState();
}

class _FreightRfqDialogState extends ConsumerState<FreightRfqDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _recipientController = TextEditingController();
  CancelToken? _cancelToken;
  
  bool _isLoading = true;
  String? _errorMessage;
  FreightRfqDataModel? _rfqData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchRfqData();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('FreightRfqDialog disposed');
    _tabController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _fetchRfqData([String? recipient]) async {
    if (!mounted) return;
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final fileParam = widget.customFileNumber?.isNotEmpty == true 
          ? widget.customFileNumber! 
          : widget.importFileId.toString();
      final url = '${ApiConstants.baseUrl}/import-files/$fileParam/freight-rfq';
      final response = await dio.get(
        url,
        queryParameters: {
          if (recipient != null && recipient.trim().isNotEmpty) 'recipient_name': recipient.trim(),
        },
        cancelToken: _cancelToken,
      );

      if (!mounted) return;
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _rfqData = FreightRfqDataModel.fromJson(response.data);
          _isLoading = false;
        });
      } else {
        final l = mounted ? context.l10n : null;
        setState(() {
          _errorMessage = l?.failedToFetchRfqData ?? 'Failed to fetch RFQ data.';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      if (!mounted) return;
      final l = context.l10n;
      setState(() {
        _errorMessage = e.message ?? l.failedToFetchRfqData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final partnersAsync = ref.watch(allPartnersProvider);
    final partnersList = (partnersAsync.asData?.value ?? [])
        .where((p) => p.partnerType.contains('Shipping Line') || p.partnerType.contains('Freight Forwarder'))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SelectionArea(
        child: Container(
          width: 1000,
          height: 750,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header Bar
              _buildDialogHeader(),

              // Recipient & Options Filter Bar
              _buildRecipientBar(partnersList),

            // Content Area / Loading
            Expanded(
              child: _isLoading
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: AppTheme.cobalt),
                            const SizedBox(height: 16),
                            Text(l.generatingRfqTemplatesLoading, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                          ],
                        ),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.crimson, size: 48),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة المحاولة'),
                                  onPressed: () => _fetchRfqData(_recipientController.text),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildMainContent(),
            ),

            // Footer Actions Bar
            _buildDialogFooter(),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDialogHeader() {
    final l = context.l10n;
    final titleCode = widget.customFileNumber ?? widget.importFileCode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadiusDirectional.only(topStart: Radius.circular(12), topEnd: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined, color: AppTheme.cobalt, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.freightRfqTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${l.importFileIdLabel}: $titleCode',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientBar(List<PartnerModel> partners) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cloudWhite,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_outlined, color: AppTheme.cobalt, size: 20),
          const SizedBox(width: 8),
          Text(l.freightRfqRecipient, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                // Quick dropdown for registered shipping lines
                if (partners.isNotEmpty) ...[
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField<String?>(
                      value: _recipientController.text.isNotEmpty ? _recipientController.text : null,
                      labelText: l.freightRfqSelectLineHint,
                      searchHintText: l.search,
                      items: partners
                          .map((p) => SearchableDropdownItem<String?>(
                                value: p.partnerName,
                                label: p.partnerName,
                                subtitle: p.partnerType,
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _recipientController.text = val;
                          _fetchRfqData(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Free text recipient name
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _recipientController,
                    decoration: InputDecoration(
                      hintText: l.freightRfqTypePersonHint,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, size: 18, color: AppTheme.cobalt),
                        tooltip: l.freightRfqUpdateTextTooltip,
                        onPressed: () => _fetchRfqData(_recipientController.text),
                      ),
                    ),
                    onSubmitted: (val) => _fetchRfqData(val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(l.freightRfqUpdateBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.cobalt,
              side: const BorderSide(color: AppTheme.cobalt),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: () => _fetchRfqData(_recipientController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final l = context.l10n;
    final rfq = _rfqData!;
    return Column(
      children: [
        // Tab Header
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.cobalt,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppTheme.cobalt,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: const Icon(Icons.email_outlined), text: l.emailDraftTab),
              Tab(icon: const Icon(Icons.chat_bubble_outline), text: l.whatsappTemplateTab),
              Tab(icon: const Icon(Icons.inventory_2_outlined), text: l.shipmentSpecsTab),
            ],
          ),
        ),

        const Divider(height: 1),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEmailTab(rfq),
              _buildWhatsAppTab(rfq),
              _buildSpecsTab(rfq),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailTab(FreightRfqDataModel rfq) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF9FAFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject Line Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Text('Subject: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                Expanded(
                  child: SelectableText(
                    rfq.emailSubject,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.cobalt),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: AppTheme.cobalt),
                  tooltip: l.freightRfqCopySubjectTooltip,
                  onPressed: () => FreightRfqGeneratorService.copyToClipboard(context, rfq.emailSubject, 'Subject'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Email Body Box
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  rfq.emailBodyTemplate,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 13, height: 1.5, color: Color(0xFF1E293B)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppTab(FreightRfqDataModel rfq) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF0FDF4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WhatsApp Bubble Preview
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  rfq.whatsappTextTemplate,
                  style: const TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xFF0F172A)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info & Quick Action Panel
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 20),
                          const SizedBox(width: 8),
                          Text(l.freightRfqWhatsappFeatures, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('• ${l.freightRfqWhatsappFeature1}', style: const TextStyle(fontSize: 12)),
                      Text('• ${l.freightRfqWhatsappFeature2}', style: const TextStyle(fontSize: 12)),
                      Text('• ${l.freightRfqWhatsappFeature3}', style: const TextStyle(fontSize: 12)),
                      Text('• ${l.freightRfqWhatsappFeature4}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(l.freightRfqCopyWhatsappBtn),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cobalt,
                            side: const BorderSide(color: AppTheme.cobalt),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => FreightRfqGeneratorService.copyToClipboard(context, rfq.whatsappTextTemplate, 'WhatsApp'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsTab(FreightRfqDataModel rfq) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grid of Metrics
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSpecCard('📦 ${l.commodityTitle}', rfq.commodity, AppTheme.cobalt),
                _buildSpecCard('🌐 ${l.incotermsRules}', rfq.incotermCode, AppTheme.orange),
                _buildSpecCard('🚢 ${l.containerSpecType}', rfq.recommendedContainers, AppTheme.charcoal),
                _buildSpecCard('📐 ${l.cbmVolumeMetric}', '${rfq.totalCbm.toStringAsFixed(2)} m³', AppTheme.emerald),
                _buildSpecCard('⚖️ ${l.grossWeightMetric}', '${rfq.grossWeightKg.toStringAsFixed(1)} kg', AppTheme.cobalt),
                _buildSpecCard('⚖️ ${l.netWeightMetric}', '${rfq.netWeightKg.toStringAsFixed(1)} kg', Colors.purple),
                _buildSpecCard('📍 ${l.portOfLoadingLabel}', rfq.portOfLoading, AppTheme.charcoal),
                _buildSpecCard('🏁 ${l.portOfDischargeLabel}', rfq.portOfDischarge, AppTheme.crimson),
                _buildSpecCard('📅 ${l.cargoReadyDateLabel}', rfq.cargoReadyDate, AppTheme.cobalt),
                _buildSpecCard('⏳ ${l.targetFreeDaysLabel}', '${rfq.targetFreeDays} d', AppTheme.emerald),
              ],
            ),
            const SizedBox(height: 16),

            // Pickup Address Card
            if (rfq.incotermCode.toUpperCase() == 'EXW') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 8),
                        Text(l.freightRfqPickupLocation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${l.freightRfqSupplierLabel} ${rfq.supplierName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(rfq.pickupAddress, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Packaging Breakdown Card
            if (rfq.packagesBreakdown.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.format_list_bulleted, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 8),
                        Text(l.freightRfqPackagesBreakdownTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(rfq.packagesBreakdown, style: const TextStyle(fontSize: 12, height: 1.5)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpecCard(String label, String value, Color color) {
    return InkWell(
      onTap: () => CopyHelper.copy(context, value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.copy, size: 12, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogFooter() {
    final l = context.l10n;
    final rfq = _rfqData;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        borderRadius: const BorderRadiusDirectional.only(bottomStart: Radius.circular(12), bottomEnd: Radius.circular(12)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          if (rfq != null) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: Text(l.freightRfqPrintPdfBtn),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.crimson,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                final pdfBytes = await FreightRfqGeneratorService.generateFreightRfqPdf(
                  rfq: rfq,
                  recipientName: _recipientController.text,
                );
                if (mounted) {
                  await FreightRfqGeneratorService.printOrSavePdf(
                    context,
                    pdfBytes,
                    rfq.customFileNumber ?? rfq.importFileCode,
                  );
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l.freightRfqCopyEmailBtn),
              onPressed: () => FreightRfqGeneratorService.copyToClipboard(context, rfq.emailBodyTemplate, 'Email'),
            ),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.crimson,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 16, color: AppTheme.crimson),
            label: Text(l.freightRfqCloseDismissBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
