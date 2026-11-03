import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Dropzone and input area with dual tabs (Text Paste and OCR Document Upload).
class QuotationsExtractorDropzone extends StatelessWidget {
  final TabController tabController;
  final TextEditingController textController;
  final PlatformFile? pickedFile;
  final bool isExtracting;
  final VoidCallback onLoadSampleText;
  final VoidCallback onClearText;
  final VoidCallback onPickFile;
  final VoidCallback onExtractFromText;
  final VoidCallback onExtractFromFileOcr;
  final ValueChanged<String>? onTextChanged;

  const QuotationsExtractorDropzone({
    super.key,
    required this.tabController,
    required this.textController,
    required this.pickedFile,
    required this.isExtracting,
    required this.onLoadSampleText,
    required this.onClearText,
    required this.onPickFile,
    required this.onExtractFromText,
    required this.onExtractFromFileOcr,
    this.onTextChanged,
  });

  static const String sampleQuoteText = '''
vertexexpress
POL ：NINGBO
POD：DEKHEILA
OF：USD6760/20GP
FREE TIME EXTEND : USD200/ctnr
OF：USD7735/40HQ
FREE TIME EXTEND : USD200/ctnr)
ETD：30-Aug
CARRIER：WHL
TT : 35 DAYS direct
FREE TIME：14 days
Other (21days+USD200/ctnr)
''';

  static IconData getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
      return Icons.image;
    }
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: tabController,
          labelColor: AppTheme.cobalt,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.cobalt,
          tabs: [
            Tab(
              icon: const Icon(Icons.text_snippet_outlined, size: 18),
              text: isArabic ? '📝 لصق نص أو بريد إلكتروني' : '📝 Paste Text / Email',
            ),
            Tab(
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              text: isArabic ? '📁 رفع ملف أو مستند أو صورة' : '📁 Upload File / Document (OCR)',
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: TabBarView(
            controller: tabController,
            children: [
              _buildTextInputTab(context, isArabic),
              _buildFileOcrTab(context, isArabic),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextInputTab(BuildContext context, bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isArabic
                    ? 'الصق نص الإيميل أو عرض السعر الوارد من شركة الشحن:'
                    : 'Paste email text or quotation received from shipping line:',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onLoadSampleText,
              icon: const Icon(Icons.content_paste_go, size: 14, color: AppTheme.cobalt),
              label: Text(
                isArabic ? '📋 تحميل نص تجريبي' : '📋 Load Sample Text',
                style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
              ),
            ),
            if (textController.text.isNotEmpty)
              TextButton.icon(
                onPressed: onClearText,
                icon: const Icon(Icons.clear_all, size: 14, color: Colors.grey),
                label: Text(
                  isArabic ? 'مسح' : 'Clear',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: textController,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: isArabic
                  ? 'الصق نص عرض السعر أو البريد هنا...\nمثال:\nمسار الرحلة: شنغهاي إلى الدخيلة\nالنولون البحري: 6700 دولار لكل حاوية 40 قدم\nمدة الإبحار: 29 يوماً | فترة السماح: 21 يوماً\nالمصاريف المحلية: 880 دولار لكل حاوية'
                  : 'Paste quotation text or email here...\nExample:\nRoute: Shanghai - El Dekheila\nOcean Freight: USD 6700 per 40HQ container\nTransit: 29 days direct | Free time: 21 days\nLocal charges: USD 880 per container',
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: onTextChanged,
          ),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: isArabic ? '🔍 استخراج عروض الأسعار من النص' : '🔍 Extract Quotations from Text',
          variant: AppButtonVariant.primary,
          isLoading: isExtracting,
          icon: isExtracting ? null : Icons.search,
          onPressed: isExtracting ? null : onExtractFromText,
        ),
      ],
    );
  }

  Widget _buildFileOcrTab(BuildContext context, bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InkWell(
            onTap: onPickFile,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: pickedFile != null ? AppTheme.cobalt : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: pickedFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 42, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            isArabic
                                ? 'اضغط هنا لاختيار ملف عرض السعر أو اسحب وأفلت الملف'
                                : 'Click to select quotation file or drag & drop',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isArabic
                                ? 'يدعم ملفات المستندات والصور والجداول الإلكترونية'
                                : 'Supports PDF, images, Word documents, and Excel',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(getFileIcon(pickedFile!.name), size: 36, color: AppTheme.cobalt),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                pickedFile!.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(pickedFile!.size / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          OutlinedButton.icon(
                            onPressed: onPickFile,
                            icon: const Icon(Icons.refresh, size: 14),
                            label: Text(
                              isArabic ? 'تغيير الملف' : 'Change File',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: isArabic ? '🚀 قراءة واستخراج بالماسح الضوئي' : '🚀 Scan & Extract Document (OCR)',
          variant: AppButtonVariant.primary,
          isLoading: isExtracting,
          icon: isExtracting ? null : Icons.document_scanner,
          onPressed: (isExtracting || pickedFile == null) ? null : onExtractFromFileOcr,
        ),
      ],
    );
  }
}
