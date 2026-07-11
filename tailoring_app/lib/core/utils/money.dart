// FCFA / XOF: integer amounts, no decimals, comma thousands separators.
//
// The comma grouping is a DISPLAY concern only — never store or send a
// grouped string. Use [parseThousands] to turn user input back into a clean
// int before sending it to the API.

/// Groups an integer with commas: 1000000 -> "1,000,000".
String formatThousands(int value) {
  final String sign = value < 0 ? '-' : '';
  final String digits = value.abs().toString();
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '$sign$grouped';
}

/// Grouped amount with the currency suffix: 1000000 -> "1,000,000 FCFA".
String formatFcfa(int amount) => '${formatThousands(amount)} FCFA';

/// Strips grouping (and any non-digit) and parses to an int, or null if there
/// are no digits. Use on the value of a [FormattedNumberField] before sending.
int? parseThousands(String? text) {
  if (text == null) return null;
  final String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}
