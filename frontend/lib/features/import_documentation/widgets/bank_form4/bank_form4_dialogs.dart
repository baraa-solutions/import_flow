import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../formal_letter_generator_dialog.dart';
import '../nafeza_bank_link_dialog.dart';
import '../pull_tax_coding_sheet_dialog.dart';
import '../update_coding_progress_dialog.dart';
import '../upload_tax_coding_dialog.dart';

/// Centralized modal and dialog launcher for Bank Form 4 operations.
class BankForm4Dialogs {
  BankForm4Dialogs._();

  static void showPullTaxCoding(
    BuildContext context, {
    required BankingDocumentModel doc,
    required VoidCallback onSubmitted,
  }) {
    PullTaxCodingSheetDialog.show(
      context,
      doc: doc,
      onSubmitted: onSubmitted,
    );
  }

  static void showUploadTaxCoding(
    BuildContext context, {
    required BankingDocumentModel doc,
    required VoidCallback onSubmitted,
  }) {
    UploadTaxCodingDialog.show(
      context,
      doc: doc,
      onSubmitted: onSubmitted,
    );
  }

  static void showUpdateCodingProgress(
    BuildContext context, {
    required BankingDocumentModel doc,
    required VoidCallback onSubmitted,
  }) {
    UpdateCodingProgressDialog.show(
      context,
      doc: doc,
      onSubmitted: onSubmitted,
    );
  }

  static void showNafezaBankLink(
    BuildContext context, {
    required BankingDocumentModel doc,
    required VoidCallback onSubmitted,
  }) {
    NafezaBankLinkDialog.show(
      context,
      doc: doc,
      onSubmitted: onSubmitted,
    );
  }

  static void showFormalLetterGenerator(
    BuildContext context, {
    required int? importFileId,
  }) {
    FormalLetterGeneratorDialog.show(
      context,
      importFileId: importFileId,
    );
  }

  static void showError(
    BuildContext context, {
    required String title,
    required dynamic error,
  }) {
    showErrorDetailsDialog(context, title: title, error: error);
  }
}
