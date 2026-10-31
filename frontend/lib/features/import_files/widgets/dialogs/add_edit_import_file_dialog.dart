import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/import_file_model.dart';
import '../../providers/import_files_provider.dart';
import '../import_file_form_dialog.dart';

/// Wrapper dialog widget for Adding or Editing an Import File.
class AddEditImportFileDialog extends StatelessWidget {
  final ImportFileModel? fileToEdit;

  const AddEditImportFileDialog({
    super.key,
    this.fileToEdit,
  });

  /// Static helper to display the dialog and automatically refresh providers on completion.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    ImportFileModel? fileToEdit,
    String? searchQuery,
    String? statusFilter,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditImportFileDialog(fileToEdit: fileToEdit),
    );
    if (!context.mounted) return;
    ref.read(paginatedImportFilesProvider.notifier).fetchPage(
          ref.read(paginatedImportFilesProvider).page,
          search: searchQuery,
          status: statusFilter,
        );
    ref.read(importFilesProvider.notifier).fetchImportFiles();
  }

  @override
  Widget build(BuildContext context) {
    return ImportFileFormDialog(fileToEdit: fileToEdit);
  }
}
