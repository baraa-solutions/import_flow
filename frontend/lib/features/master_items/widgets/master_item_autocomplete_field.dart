import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/master_item_model.dart';
import '../repositories/master_items_repository.dart';

/// Reusable Master Item Autocomplete Field (MD-ITEM-001 / Task 14).
///
/// Complies with:
/// 1. Zero-Weight Rule: No data is loaded on initialization; queries are only
///    dispatched when the user types, throttled by a 300ms debounce.
/// 2. Backward Compatibility: Fully supports free-text / manual input for legacy
///    records not yet linked to the master catalog.
/// 3. Central Styling & Theme: Uses AppTheme tokens exclusively.
class MasterItemAutocompleteField extends ConsumerStatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final bool isRequired;
  final bool enabled;
  final ValueChanged<MasterItemModel>? onItemSelected;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final MasterItemModel? selectedItem;
  final VoidCallback? onCleared;

  const MasterItemAutocompleteField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.isRequired = false,
    this.enabled = true,
    this.onItemSelected,
    this.onChanged,
    this.validator,
    this.selectedItem,
    this.onCleared,
  });

  @override
  ConsumerState<MasterItemAutocompleteField> createState() =>
      _MasterItemAutocompleteFieldState();
}

class _MasterItemAutocompleteFieldState
    extends ConsumerState<MasterItemAutocompleteField> {
  late final TextEditingController _controller;
  bool _ownsController = false;

  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  Timer? _debounceTimer;
  CancelToken? _cancelToken;

  List<MasterItemModel> _suggestions = const [];
  bool _isLoading = false;
  bool _hasSearched = false;
  MasterItemModel? _currentSelectedItem;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _ownsController = true;
      _controller = TextEditingController(text: widget.initialValue ?? '');
    }

    _currentSelectedItem = widget.selectedItem;

    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant MasterItemAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItem != oldWidget.selectedItem) {
      _currentSelectedItem = widget.selectedItem;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cancelToken?.cancel('field_disposed');
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _removeOverlay();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onTextChanged(String query) {
    widget.onChanged?.call(query);

    // If query no longer matches selected item's code or description, clear link
    if (_currentSelectedItem != null &&
        query.trim() != _currentSelectedItem!.itemCode &&
        query.trim() != _currentSelectedItem!.descriptionAr) {
      setState(() {
        _currentSelectedItem = null;
      });
    }

    _debounceTimer?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _removeOverlay();
      setState(() {
        _suggestions = const [];
        _isLoading = false;
        _hasSearched = false;
      });
      return;
    }

    // Zero-weight: 300ms debounce before any network activity
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(trimmed);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    _showOverlay();

    _cancelToken?.cancel('new_search_query');
    _cancelToken = CancelToken();

    try {
      final repo = ref.read(masterItemsRepositoryProvider);
      final result = await repo.fetchMasterItems(
        search: query,
        limit: 8,
        cancelToken: _cancelToken,
      );

      if (!mounted) return;

      setState(() {
        _suggestions = result.items;
        _isLoading = false;
      });

      _overlayEntry?.markNeedsBuild();
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _isLoading = false;
      });
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _selectItem(MasterItemModel item) {
    setState(() {
      _currentSelectedItem = item;
      _controller.text = item.itemCode;
    });
    _removeOverlay();
    _focusNode.unfocus();

    widget.onItemSelected?.call(item);
    widget.onChanged?.call(item.itemCode);
  }

  void _clearField() {
    setState(() {
      _controller.clear();
      _currentSelectedItem = null;
      _suggestions = const [];
      _isLoading = false;
      _hasSearched = false;
    });
    _removeOverlay();
    widget.onCleared?.call();
    widget.onChanged?.call('');
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Click outside overlay dismisser
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
              ),
            ),
            Positioned(
              width: _getRenderBoxWidth(),
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0.0, 48.0),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).cardColor,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.cobalt.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildSuggestionsContent(context),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    _overlayEntry = entry;
    overlay.insert(entry);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _getRenderBoxWidth() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 320.0;
  }

  Widget _buildSuggestionsContent(BuildContext context) {
    final l = context.l10n;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.cobalt,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'جاري البحث في الكاتالوج...',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    if (_hasSearched && _suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 28,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 6),
            Text(
              l.masterItemNoResults,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l.masterItemCustomManual,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 0.5,
        color: AppTheme.cloudWhite,
      ),
      itemBuilder: (context, index) {
        final item = _suggestions[index];
        final isSelected = _currentSelectedItem?.itemId == item.itemId;

        return InkWell(
          onTap: () => _selectItem(item),
          hoverColor: AppTheme.cobaltLight.withValues(alpha: 0.3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isSelected
                ? AppTheme.cobaltLight.withValues(alpha: 0.4)
                : Colors.transparent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppTheme.cobalt.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    item.itemCode,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cobalt,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.descriptionAr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.charcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.descriptionEn != null &&
                          item.descriptionEn!.isNotEmpty)
                        Text(
                          item.descriptionEn!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          if (item.hsCode != null && item.hsCode!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.cloudWhite,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'HS: ${item.hsCode}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.cloudWhite,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'UOM: ${item.defaultUom}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                          if (item.grossWeightKg > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.cloudWhite,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${item.grossWeightKg} KG',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          if (item.cbmPerUnit > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.cloudWhite,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${item.cbmPerUnit} CBM',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_currentSelectedItem?.itemId == item.itemId)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 6, top: 4),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppTheme.emerald,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isLinked = _currentSelectedItem != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onChanged: _onTextChanged,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.labelText ??
              (l.isArabic
                  ? 'كود أو اسم الصنف (إكمال تلقائي)'
                  : 'Item Code or Name (Autocomplete)'),
          hintText: widget.hintText ?? l.masterItemSearchHint,
          isDense: true,
          prefixIcon: Icon(
            isLinked ? Icons.inventory_2_rounded : Icons.search_rounded,
            size: 20,
            color: isLinked ? AppTheme.emerald : AppTheme.cobalt,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppTheme.cobalt,
                    ),
                  ),
                ),
              if (_controller.text.isNotEmpty && widget.enabled)
                IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                  tooltip: l.isArabic ? 'مسح الحقل' : 'Clear',
                  onPressed: _clearField,
                ),
              if (isLinked)
                Tooltip(
                  message: l.masterItemLinked,
                  child: const Padding(
                    padding: EdgeInsetsDirectional.only(end: 8.0),
                    child: Icon(
                      Icons.link_rounded,
                      size: 18,
                      color: AppTheme.emerald,
                    ),
                  ),
                ),
            ],
          ),
          helperText: isLinked
              ? '${l.masterItemLinked}: ${_currentSelectedItem!.descriptionAr}'
              : null,
          helperStyle: const TextStyle(
            color: AppTheme.emerald,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
              color: isLinked ? AppTheme.emeraldBorder : AppTheme.cloudWhite,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
              color: isLinked ? AppTheme.emerald : AppTheme.cobalt,
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
