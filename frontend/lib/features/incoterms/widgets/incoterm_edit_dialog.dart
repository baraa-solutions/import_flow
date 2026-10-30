import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/widgets/widgets.dart';
import '../models/incoterm_model.dart';
import '../providers/incoterms_provider.dart';

/// Edit/Create dialog for an Incoterm rule.
class IncotermEditDialog extends ConsumerStatefulWidget {
  final IncotermModel? incoterm;

  const IncotermEditDialog({
    super.key,
    this.incoterm,
  });

  /// Static helper to display the dialog.
  static Future<void> show(
    BuildContext context, {
    IncotermModel? incoterm,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => IncotermEditDialog(incoterm: incoterm),
    );
  }

  @override
  ConsumerState<IncotermEditDialog> createState() => _IncotermEditDialogState();
}

class _IncotermEditDialogState extends ConsumerState<IncotermEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _versionCtrl;
  late final TextEditingController _descCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.incoterm?.incotermCode ?? '');
    _nameCtrl = TextEditingController(text: widget.incoterm?.incotermName ?? '');
    _versionCtrl = TextEditingController(text: widget.incoterm?.version ?? 'Incoterms 2020');
    _descCtrl = TextEditingController(text: widget.incoterm?.description ?? '');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _versionCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'incoterm_code': _codeCtrl.text.trim().toUpperCase(),
      'incoterm_name': _nameCtrl.text.trim(),
      'version': _versionCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    };

    String? error;
    if (widget.incoterm == null) {
      error = await ref.read(incotermsProvider.notifier).createIncoterm(data);
    } else {
      error = await ref
          .read(incotermsProvider.notifier)
          .updateIncoterm(widget.incoterm!.incotermId, data);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, error, severity: AppSeverity.danger),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = widget.incoterm != null;

    return SelectionArea(
      child: AlertDialog(
        title: Text(isEditing ? l10n.editIncotermDialogTitle : l10n.addIncotermDialogTitle),
      content: SelectionArea(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.incotermCodeLabel,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                      tooltip: l10n.incotermsCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _codeCtrl.text),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.incotermFullNameLabel,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                      tooltip: l10n.incotermsCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _nameCtrl.text),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _versionCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.incotermVersionLabel,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                      tooltip: l10n.incotermsCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _versionCtrl.text),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.incotermDescriptionLabel,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                      tooltip: l10n.incotermsCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _descCtrl.text),
                    ),
                  ),
                  maxLines: 2,
                ),
                if (isEditing) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      AppButton(
                        label: l10n.exportIncotermsPdfBtn,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        icon: Icons.picture_as_pdf,
                        onPressed: () {
                          final matrix =
                              ref.read(responsibilityMatrixProvider).value ?? [];
                          MasterDataExportService.printOrSaveIncotermPdf(
                              widget.incoterm!, matrix);
                        },
                      ),
                      AppButton(
                        label: l10n.exportIncotermsExcelBtn,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        icon: Icons.description,
                        onPressed: () {
                          final matrix =
                              ref.read(responsibilityMatrixProvider).value ?? [];
                          MasterDataExportService.exportIncotermToExcel(
                              context, widget.incoterm!, matrix);
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l10n.cancel,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        AppButton(
          label: isEditing ? l10n.save : l10n.addIncotermBtn,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          isLoading: _isLoading,
          onPressed: _handleSubmit,
        ),
      ],
    ),
    );
  }
}
