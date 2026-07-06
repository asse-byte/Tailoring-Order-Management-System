/// FCFA / XOF: integer amounts, no decimals, thin-space thousands.
String formatFcfa(int amount) {
  final String sign = amount < 0 ? '-' : '';
  final String digits = amount.abs().toString();
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(' ');
    grouped.write(digits[i]);
  }
  return '$sign$grouped FCFA';
}
