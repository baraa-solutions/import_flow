import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/inspection_appeal_model.dart';
import '../services/inspection_appeal_service.dart';
import 'appeals/appeal_card_item.dart';
import 'appeals/appeal_decision_dialog.dart';
import 'appeals/appeal_progress_tier_dialog.dart';
import 'appeals/inspection_appeals_filters.dart';
import 'appeals/inspection_appeals_header.dart';
import 'appeals/new_appeal_dialog.dart';

class InspectionAppealsDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const InspectionAppealsDialog({super.key, this.initialImportFileId});

  static Future<void> show(BuildContext context, {int? initialImportFileId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => InspectionAppealsDialog(initialImportFileId: initialImportFileId),
    );
  }

  @override
  ConsumerState<InspectionAppealsDialog> createState() => _InspectionAppealsDialogState();
}

class _InspectionAppealsDialogState extends ConsumerState<InspectionAppealsDialog> {
  List<InspectionAppealModel> _appeals = [];
  bool _isLoading = false;
  String _selectedAuthority = 'All';
  String _selectedTier = 'All';
  String _selectedResult = 'All';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(inspectionAppealServiceProvider);
      final list = await service.listAppeals(
        importFileId: widget.initialImportFileId,
        regulatoryAuthority: _selectedAuthority,
        appealTier: _selectedTier,
        appealResult: _selectedResult,
      );

      if (mounted) {
        setState(() {
          _appeals = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showNewAppealDialog() {
    NewAppealDialog.show(
      context,
      initialImportFileId: widget.initialImportFileId,
      onSaved: _loadData,
    );
  }

  void _showDecisionDialog(InspectionAppealModel item) {
    AppealDecisionDialog.show(
      context,
      item: item,
      onSaved: _loadData,
    );
  }

  void _showProgressTierDialog(InspectionAppealModel item) {
    AppealProgressTierDialog.show(
      context,
      item: item,
      onSaved: _loadData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 1100,
        height: 740,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SelectionArea(
          child: Column(
            children: [
              InspectionAppealsHeader(
                onNewAppeal: _showNewAppealDialog,
                onClose: () => Navigator.of(context).pop(),
              ),
              InspectionAppealsFilters(
                selectedAuthority: _selectedAuthority,
                onAuthorityChanged: (val) {
                  setState(() => _selectedAuthority = val);
                  _loadData();
                },
                selectedTier: _selectedTier,
                onTierChanged: (val) {
                  setState(() => _selectedTier = val);
                  _loadData();
                },
                selectedResult: _selectedResult,
                onResultChanged: (val) {
                  setState(() => _selectedResult = val);
                  _loadData();
                },
                onRefresh: _loadData,
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(child: Text('خطأ: $_errorMessage', style: const TextStyle(color: AppTheme.crimson)))
                        : _appeals.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 54, color: Colors.grey.shade400),
                                    const SizedBox(height: 10),
                                    const Text('لا توجد تظلمات معملية مسجلة حالياً', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _appeals.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = _appeals[idx];
                                  return AppealCardItem(
                                    item: item,
                                    onDecision: () => _showDecisionDialog(item),
                                    onProgressTier: () => _showProgressTierDialog(item),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
