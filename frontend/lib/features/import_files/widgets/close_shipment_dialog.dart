// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/import_files_provider.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class CloseShipmentDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;
  final String currentPhaseName;

  const CloseShipmentDialog({
    super.key,
    required this.importFileId,
    required this.importFileCode,
    required this.currentPhaseName,
  });

  @override
  ConsumerState<CloseShipmentDialog> createState() => _CloseShipmentDialogState();
}

class _CloseShipmentDialogState extends ConsumerState<CloseShipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: AppTheme.crimson, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${l.closeShipmentTitle} (${widget.importFileCode})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.currentPhaseStage}: ${widget.currentPhaseName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    LtrText(
                      widget.importFileCode,
                      style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: '${l.reason} *',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l.reason;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 18),
          label: Text(
            l.closeShipmentTitle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _isLoading = true);
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(importFilesProvider.notifier).closeShipment(
                            widget.importFileId,
                            _reasonController.text.trim(),
                            widget.currentPhaseName,
                          );
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Closed'),
                          backgroundColor: AppTheme.emerald,
                        ),
                      );
                      nav.pop(true);
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.crimson),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  }
                },
        ),
      ],
    );
  }
}

