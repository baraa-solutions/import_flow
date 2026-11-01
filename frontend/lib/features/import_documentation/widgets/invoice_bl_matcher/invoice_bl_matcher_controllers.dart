import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import 'invoice_bl_matcher_sample_data.dart';
import 'invoice_bl_matcher_service.dart';

/// Encapsulates controllers and document ingestion buffers for Screen 22: Invoice vs B/L Matcher.
class InvoiceBlMatcherControllers {
  final TextEditingController invoiceTextCtrl = TextEditingController();
  final TextEditingController blTextCtrl = TextEditingController();
  final TextEditingController packingTextCtrl = TextEditingController();

  String? invoiceFileName;
  String? blFileName;
  String? packingFileName;

  Uint8List? invoiceFileBytes;
  Uint8List? blFileBytes;
  Uint8List? packingFileBytes;

  List<PlatformFile> invoiceFiles = [];
  List<PlatformFile> blFiles = [];
  List<PlatformFile> packingFiles = [];

  bool showPackingList = true;

  void addListener(VoidCallback listener) {
    invoiceTextCtrl.addListener(listener);
    blTextCtrl.addListener(listener);
    packingTextCtrl.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    invoiceTextCtrl.removeListener(listener);
    blTextCtrl.removeListener(listener);
    packingTextCtrl.removeListener(listener);
  }

  void dispose() {
    invoiceTextCtrl.dispose();
    blTextCtrl.dispose();
    packingTextCtrl.dispose();
  }

  bool get hasContent {
    final hasInv = invoiceFiles.isNotEmpty || invoiceFileBytes != null || (invoiceTextCtrl.text.trim().isNotEmpty && !invoiceTextCtrl.text.startsWith('['));
    final hasBl = blFiles.isNotEmpty || blFileBytes != null || (blTextCtrl.text.trim().isNotEmpty && !blTextCtrl.text.startsWith('['));
    final hasPl = packingFiles.isNotEmpty || packingFileBytes != null || (packingTextCtrl.text.trim().isNotEmpty && !packingTextCtrl.text.startsWith('['));
    return hasInv || hasBl || hasPl;
  }

  Future<bool> pickFile(BuildContext context, String docType) async {
    final picked = await InvoiceBlMatcherService.pickDocFiles(context, docType);
    if (picked == null || !context.mounted) return false;

    final l = context.l10n;
    final fileNames = picked.resolvedFiles.map((f) => f.name).join(", ");

    if (docType == 'invoice') {
      invoiceFiles = picked.resolvedFiles;
      invoiceFileName = picked.displayName;
      invoiceFileBytes = picked.fileBytes;
      invoiceTextCtrl.text = picked.decodedText ?? l.invoiceBlMatcherInvoiceFilesLoaded(picked.resolvedFiles.length, fileNames);
    } else if (docType == 'packing') {
      showPackingList = true;
      packingFiles = picked.resolvedFiles;
      packingFileName = picked.displayName;
      packingFileBytes = picked.fileBytes;
      packingTextCtrl.text = picked.decodedText ?? l.invoiceBlMatcherPackingFilesLoaded(picked.resolvedFiles.length, fileNames);
    } else {
      blFiles = picked.resolvedFiles;
      blFileName = picked.displayName;
      blFileBytes = picked.fileBytes;
      blTextCtrl.text = picked.decodedText ?? l.invoiceBlMatcherBlFilesLoaded(picked.resolvedFiles.length, fileNames);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        l.invoiceBlMatcherFilesSelectedSuccess(picked.resolvedFiles.length, fileNames),
        severity: AppSeverity.success,
      ),
    );
    return true;
  }

  void loadSampleData(BuildContext context) {
    invoiceTextCtrl.text = InvoiceBlMatcherSampleData.shawInvoice.trim();
    invoiceFileName = 'ShawContract_Commercial_Invoice.txt';
    blTextCtrl.text = InvoiceBlMatcherSampleData.mscBL.trim();
    blFileName = 'MSC_Draft_BL_MEDURE910647.txt';
    invoiceFileBytes = null;
    blFileBytes = null;
    invoiceFiles = [];
    blFiles = [];
    packingFiles = [];

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.invoiceBlMatcherSampleLoadedSuccess),
    );
  }

  void reset() {
    invoiceTextCtrl.clear();
    blTextCtrl.clear();
    packingTextCtrl.clear();
    invoiceFileName = null;
    blFileName = null;
    packingFileName = null;
    invoiceFileBytes = null;
    blFileBytes = null;
    packingFileBytes = null;
    invoiceFiles = [];
    blFiles = [];
    packingFiles = [];
    showPackingList = false;
  }
}
