import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Numeric input of the PO dialog (qty, price, dimensions, weights).
///
/// Owns ONE controller and focus node for its lifetime, so the parent may `setState` on every
/// keystroke without the field losing focus or its text. The typed text is never reformatted
/// while the field has focus (no rounding of what the user typed); a value changed by the
/// parent (extraction, auto-fill) is shown when the field is not being edited.
class PoDecimalField extends StatefulWidget {
  const PoDecimalField({
    super.key,
    required this.value,
    required this.labelText,
    required this.onChanged,
    this.maxDecimals = 16,
    this.emptyValue = 0.0,
  });

  final double value;
  final String labelText;

  /// Called with the parsed value; an empty / incomplete text ("", ".") reports [emptyValue].
  final ValueChanged<double> onChanged;

  /// Digits allowed after the decimal point (0 = whole numbers only).
  final int maxDecimals;
  final double emptyValue;

  /// Full-precision text of [value] for editing: no trailing ".0", no exponent, no rounding
  /// beyond [maxDecimals].
  static String formatForEditing(double value, {int maxDecimals = 16}) {
    if (value.isNaN || value.isInfinite) return '0';
    if (value == value.truncateToDouble() && value.abs() < 1e15) return value.toInt().toString();
    var s = value.toString();
    final dot = s.indexOf('.');
    if (s.contains('e') || s.contains('E') || (dot >= 0 && s.length - dot - 1 > maxDecimals)) {
      s = value.toStringAsFixed(maxDecimals);
      if (s.contains('.')) s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// Accepts digits with at most one decimal point and [maxDecimals] decimals; any other edit
  /// is rejected (the previous text stays).
  static TextInputFormatter decimalFormatter(int maxDecimals) {
    final pattern = maxDecimals > 0 ? RegExp('^\\d*\\.?\\d{0,$maxDecimals}\$') : RegExp(r'^\d*$');
    return TextInputFormatter.withFunction(
      (oldValue, newValue) => pattern.hasMatch(newValue.text) ? newValue : oldValue,
    );
  }

  @override
  State<PoDecimalField> createState() => _PoDecimalFieldState();
}

class _PoDecimalFieldState extends State<PoDecimalField> {
  late final TextEditingController _controller =
      TextEditingController(text: PoDecimalField.formatForEditing(widget.value, maxDecimals: widget.maxDecimals));
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant PoDecimalField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focusNode.hasFocus && double.tryParse(_controller.text) != widget.value) {
      _controller.text = PoDecimalField.formatForEditing(widget.value, maxDecimals: widget.maxDecimals);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.maxDecimals > 0),
      inputFormatters: [PoDecimalField.decimalFormatter(widget.maxDecimals)],
      decoration: InputDecoration(labelText: widget.labelText, isDense: true),
      onChanged: (text) => widget.onChanged(double.tryParse(text) ?? widget.emptyValue),
    );
  }
}
