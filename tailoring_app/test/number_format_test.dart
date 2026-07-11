import 'package:flutter_test/flutter_test.dart';
import 'package:tailoring_app/core/utils/money.dart';
import 'package:tailoring_app/core/widgets/formatted_number_field.dart';

void main() {
  group('formatThousands', () {
    test('groups with commas', () {
      expect(formatThousands(0), '0');
      expect(formatThousands(1000), '1,000');
      expect(formatThousands(1000000), '1,000,000');
      expect(formatThousands(999), '999');
      expect(formatThousands(-1500), '-1,500');
    });
  });

  group('formatFcfa', () {
    test('adds currency suffix', () {
      expect(formatFcfa(2500000), '2,500,000 FCFA');
    });
  });

  group('parseThousands', () {
    test('strips commas back to a clean int', () {
      expect(parseThousands('1,000,000'), 1000000);
      expect(parseThousands('2 500'), 2500);
      expect(parseThousands(''), isNull);
      expect(parseThousands(null), isNull);
      expect(parseThousands('abc'), isNull);
    });
  });

  group('ThousandsSeparatorInputFormatter', () {
    const fmt = ThousandsSeparatorInputFormatter();
    TextEditingValue apply(String text) => fmt.formatEditUpdate(
          const TextEditingValue(text: ''),
          TextEditingValue(text: text),
        );

    test('formats digits live', () {
      expect(apply('1000000').text, '1,000,000');
      expect(apply('50').text, '50');
      expect(apply('').text, '');
    });

    test('ignores non-digits already present', () {
      expect(apply('1,000,0').text, '10,000');
    });

    test('drops leading zeros but keeps a single zero', () {
      expect(apply('007').text, '7');
      expect(apply('0').text, '0');
    });

    test('caret stays at the end', () {
      final v = apply('1000');
      expect(v.selection.baseOffset, v.text.length);
    });
  });
}
