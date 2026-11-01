import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../models/import_file_model.dart';
import 'rfq/freight_rfq_email_tab.dart';
import 'rfq/freight_rfq_footer.dart';
import 'rfq/freight_rfq_header.dart';
import 'rfq/freight_rfq_specs_tab.dart';
import 'rfq/freight_rfq_whatsapp_tab.dart';

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
    final titleCode = widget.customFileNumber ?? widget.importFileCode;

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
              FreightRfqHeader(
                titleCode: titleCode,
                onClose: () => Navigator.of(context).pop(),
              ),
              FreightRfqRecipientBar(
                partners: partnersList,
                recipientController: _recipientController,
                onSelectPartner: (val) {
                  if (val != null) {
                    _recipientController.text = val;
                    _fetchRfqData(val);
                  }
                },
                onSubmitRecipient: (val) => _fetchRfqData(val),
              ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: AppTheme.cobalt),
                              const SizedBox(height: 16),
                              Text(
                                l.generatingRfqTemplatesLoading,
                                style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
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
                                    child: Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold),
                                    ),
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
              FreightRfqFooter(
                rfq: _rfqData,
                recipientController: _recipientController,
                onClose: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final l = context.l10n;
    final rfq = _rfqData!;

    return Column(
      children: [
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
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              FreightRfqEmailTab(rfq: rfq),
              FreightRfqWhatsAppTab(rfq: rfq),
              FreightRfqSpecsTab(rfq: rfq),
            ],
          ),
        ),
      ],
    );
  }
}
