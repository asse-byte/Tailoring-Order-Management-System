import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/money.dart';

/// Adds comma thousands separators live, as the user types: "1000000"
/// becomes "1,000,000". Non-digits are stripped, so the visible value is
/// always a clean grouped integer. The caller reads the real number with
/// [parseThousands] on the controller text — the commas are display only.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    // Drop leading zeros (but keep a single "0").
    final String normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final String formatted = formatThousands(int.parse(normalized));
    // Keeping the caret at the end is the robust choice for money entry.
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// A money/large-number text field shared across every screen. Displays the
/// value grouped with commas as it is typed; read the clean int with
/// [FormattedNumberField.valueOf] (or [parseThousands] directly).
class FormattedNumberField extends StatelessWidget {
  const FormattedNumberField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.suffixText = 'FCFA',
    this.prefixIcon,
    this.validator,
    this.enabled = true,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;

  /// Trailing unit shown inside the field (default FCFA). Pass null to hide.
  final String? suffixText;
  final IconData? prefixIcon;

  /// Validates the PARSED integer (null = empty field).
  final String? Function(int? value)? validator;
  final bool enabled;
  final ValueChanged<int?>? onChanged;
  final TextInputAction? textInputAction;

  /// Convenience: the clean integer currently in [controller].
  static int? valueOf(TextEditingController c) => parseThousands(c.text);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      inputFormatters: const <TextInputFormatter>[
        ThousandsSeparatorInputFormatter(),
      ],
      validator: validator == null
          ? null
          : (raw) => validator!(parseThousands(raw)),
      onChanged: onChanged == null
          ? null
          : (raw) => onChanged!(parseThousands(raw)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixText: suffixText,
      ),
    );
  }
}

/// Formats an initial int value for seeding a [FormattedNumberField]
/// controller (empty string for null / zero-as-blank cases handled by caller).
String initialGrouped(int? value) =>
    value == null ? '' : formatThousands(value);
